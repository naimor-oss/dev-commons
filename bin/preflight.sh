#!/usr/bin/env bash
# bin/preflight.sh — composed no-VM gate.
#
# Run this BEFORE any VM scenario. It chains the cheap checks
# that catch the regressions a fresh VM run would otherwise burn 10+
# minutes per scenario re-discovering:
#
#   1. dev-commons/bin/sanity-check.sh — bash -n across every tracked
#      shell script in every sibling repo.
#   2. bash -n on each appliance's prepare-image.sh + *sconfig*.sh.
#      sanity-check covers most of the surface, but the per-repo
#      pass also picks up files outside the dirs sanity-check walks
#      (and isolating these failures by appliance gives clearer
#      output than the combined sweep).
#   3. Every test suite in every sibling: tests/*.sh and tests/**/*.bats,
#      discovered automatically (per-repo opt-outs in
#      tests/.preflight-skip, each with a reason).
#   4. Design-contract source guards, appliance-core compliance, and
#      strict shellcheck (steps 4-6 below).
#
# Exits non-zero on the FIRST failure with the failing repo + step
# named, so you fix the closest problem instead of staring at a
# scrolling wall of compounded output.
#
# Run from any directory; the script resolves the sibling layout
# relative to its own location.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"          # dev-commons
PARENT_DIR="$(cd "$REPO_DIR/.." && pwd)"          # Debian-SAMBA/

if [[ -t 1 ]]; then
    BOLD=$'\033[1m'; RST=$'\033[0m'
    GREEN=$'\033[32m'; RED=$'\033[31m'
else
    BOLD=''; RST=''; GREEN=''; RED=''
fi

step() { printf '\n%s== %s ==%s\n' "$BOLD" "$1" "$RST"; }
fail() { printf '%sFAIL%s %s\n' "$RED" "$RST" "$1" >&2; exit 1; }
pass() { printf '%sPASS%s %s\n' "$GREEN" "$RST" "$1"; }

# 1. Cross-repo sanity-check.
step "1. cross-repo sanity-check"
"$SCRIPT_DIR/sanity-check.sh" || fail "sanity-check.sh failed (see above)"
pass "sanity-check.sh"

# 2. Per-appliance bash -n. Limited to the most-edited entry-point
# scripts, where a typo would burn a full image rebuild before
# surfacing.
step "2. per-appliance bash -n on entry-point scripts"
declare -a entry_points=(
    "samba-addc-appliance/prepare-image.sh"
    "samba-addc-appliance/samba-sconfig.sh"
    "smb-proxy-appliance/prepare-image.sh"
    "smb-proxy-appliance/smbproxy-sconfig.sh"
    "smb-proxy-appliance/smbproxy-probe-backend"
    "smbproxy-session-vfs/scripts/build-debian-package.sh"
    "smbproxy-session-vfs/scripts/build-apt-repository.sh"
    "appliance-core/prepare-image.sh"
    "appliance-core/core-sconfig.sh"
)
for f in "${entry_points[@]}"; do
    full="$PARENT_DIR/$f"
    if [[ -f "$full" ]]; then
        bash -n "$full" || fail "bash -n failed on $f"
        pass "bash -n $f"
    else
        # Missing files are not a preflight error per se — the
        # appliance might not be checked out — but report so the
        # operator knows the gate's coverage.
        printf '  skip %s (file not present)\n' "$f"
    fi
done

# 3. Every sibling's test suites, discovered rather than listed, so a new
# test file is gated the day it lands. Each repo may list files to leave
# out in tests/.preflight-skip ("<file>  # reason"); heavy harnesses that
# need Docker or a PTY run in CI instead. Set PREFLIGHT_REQUIRE_TOOLS=1
# (CI does) to fail, rather than skip, when bats or shellcheck is absent.
step "3. sibling test suites (tests/*.sh, tests/**/*.bats)"
require_tools="${PREFLIGHT_REQUIRE_TOOLS:-0}"
if [[ "$require_tools" == "1" ]]; then
    for tool in bats shellcheck; do
        command -v "$tool" >/dev/null 2>&1 || fail "$tool is required (PREFLIGHT_REQUIRE_TOOLS=1)"
    done
fi
declare -a test_repos=(
    dev-commons appliance-core lab-kit lab-router
    samba-addc-appliance smb-proxy-appliance smbproxy-session-vfs
)
suites_run=0
suite_log=$(mktemp "${TMPDIR:-/tmp}/preflight-suite.XXXXXX")
trap 'rm -f "$suite_log"' EXIT
for repo in "${test_repos[@]}"; do
    tdir="$PARENT_DIR/$repo/tests"
    [[ -d "$tdir" ]] || { printf '  skip %s (no tests/ directory)\n' "$repo"; continue; }
    skip_list=""
    [[ -f "$tdir/.preflight-skip" ]] && skip_list=$(sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$tdir/.preflight-skip")
    while IFS= read -r t; do
        rel="${t#"$tdir"/}"
        if grep -qxF -- "$rel" <<< "$skip_list"; then
            printf '  skip %s/tests/%s (tests/.preflight-skip)\n' "$repo" "$rel"
            continue
        fi
        case "$t" in
            *.bats)
                if ! command -v bats >/dev/null 2>&1; then
                    printf '  skip %s/tests/%s (bats not installed)\n' "$repo" "$rel"
                    continue
                fi
                runner=(bats "$t") ;;
            *)  runner=(bash "$t") ;;
        esac
        if ! ( cd "$PARENT_DIR/$repo" && "${runner[@]}" ) > "$suite_log" 2>&1; then
            tail -30 "$suite_log" >&2
            fail "$repo/tests/$rel"
        fi
        pass "$repo/tests/$rel"
        suites_run=$((suites_run + 1))
    done < <(find "$tdir" -type f \( -name '*.bats' -o -name '*.sh' \) | LC_ALL=C sort)
done
(( suites_run > 0 )) || fail "no test suites found — is the sibling layout present?"

# 4. Source-level contract guards. These pin design decisions
# documented in samba-addc-appliance/docs/DFS-N.md and
# smb-proxy-appliance/docs/LAB-TESTING.md so a refactor that
# silently violates the protocol fails preflight before any VM
# run. Each guard is a single grep over the runtime source — the
# protocol claim is encoded as the search pattern.
step "4. design-contract source guards"

addc_sconfig="$PARENT_DIR/samba-addc-appliance/samba-sconfig.sh"
proxy_sconfig="$PARENT_DIR/smb-proxy-appliance/smbproxy-sconfig.sh"

guard_grep() {
    # guard_grep <label> <file> <pattern>
    # Asserts <pattern> matches at least once in <file> (extended regex).
    local label="$1" file="$2" pat="$3"
    if [[ ! -f "$file" ]]; then
        printf '  skip %s (file not present)\n' "$label"
        return
    fi
    if grep -qE -- "$pat" "$file"; then
        pass "$label"
    else
        fail "$label — pattern '$pat' not found in $(basename "$file")"
    fi
}

guard_grep_absent() {
    # guard_grep_absent <label> <file> <pattern>
    # Asserts <pattern> matches ZERO times in <file>.
    local label="$1" file="$2" pat="$3"
    if [[ ! -f "$file" ]]; then
        printf '  skip %s (file not present)\n' "$label"
        return
    fi
    if grep -qE -- "$pat" "$file"; then
        fail "$label — forbidden pattern '$pat' found in $(basename "$file")"
    else
        pass "$label"
    fi
}

# DFS-N.md §6.1 — lock at /run, never /tmp.
guard_grep "DFS-N: lock path under /run" \
    "$addc_sconfig" \
    'DFS_LOCK=.*/run/samba-dfs-update\.lock'
guard_grep_absent "DFS-N: no /tmp lock" \
    "$addc_sconfig" \
    '/tmp/samba-dfs(-update)?\.lock'

# DFS-N.md §3 — AD container is "Dfs-Configuration", not the
# textbook-but-wrong "Dfsn-Configuration". Verified against a live
# WS2025 forest; the wrong name passes lint and silently returns
# zero LDAP results.
guard_grep "DFS-N: AD container Dfs-Configuration" \
    "$addc_sconfig" \
    'CN=Dfs-Configuration,CN=System'
guard_grep_absent "DFS-N: no Dfsn-Configuration typo" \
    "$addc_sconfig" \
    'Dfsn-Configuration'

# DFS-N.md §6.10 — reload is via smbcontrol (not systemctl reload
# samba-ad-dc inside dfs-update; that's reserved for [global] edits).
guard_grep "DFS-N: smbcontrol reload-config in dfs-update path" \
    "$addc_sconfig" \
    'smbcontrol [a-z]+ reload-config'

# DFS-N.md §8 — service hardening directives and timer settings.
guard_grep "DFS-N: ProtectSystem=strict in unit"          "$addc_sconfig" '^ProtectSystem=strict'
guard_grep "DFS-N: NoNewPrivileges=yes in unit"            "$addc_sconfig" '^NoNewPrivileges=yes'
guard_grep "DFS-N: MemoryDenyWriteExecute=yes in unit"     "$addc_sconfig" '^MemoryDenyWriteExecute=yes'
guard_grep "DFS-N: RestrictAddressFamilies=… in unit"      "$addc_sconfig" '^RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6'
guard_grep "DFS-N: timer Persistent=true"                  "$addc_sconfig" '^Persistent=true'
guard_grep "DFS-N: timer RandomizedDelaySec set"           "$addc_sconfig" '^RandomizedDelaySec='

# DFS-N awareness in firewall ruleset rendering. The hardening pass
# detects DFS-N state and writes either "ENABLED" or "NOT HOSTED" into
# the rendered nftables header. Both strings MUST be present in
# samba-sconfig — they're the two branches of the renderer. Drift
# (one removed in a refactor) would leave the operator unable to
# distinguish state. is_dfs_enabled is the helper both branches use.
guard_grep "DFS-N: is_dfs_enabled helper present"          "$addc_sconfig" '^is_dfs_enabled\(\) \{'
guard_grep "DFS-N: firewall renderer emits ENABLED state"  "$addc_sconfig" 'DFS-N namespace server: ENABLED'
guard_grep "DFS-N: firewall renderer emits NOT-HOSTED state" "$addc_sconfig" 'DFS-N namespace server: NOT HOSTED'

# Hostname/realm alignment is invoked from post_provision_setup so
# /etc/hosts is rewritten under the joined realm (field-reported
# "lab.test stuck" bug). If a refactor drops the call, the bug
# returns; pin the call site.
guard_grep "hostname: post_provision aligns to realm" \
    "$addc_sconfig" \
    'appcore_hostname_align_to_realm'

# DOMAIN\\Group input goes through appcore_id_domgroup_* (Phase 1).
# Pin the wire-in so a future refactor can't accidentally bypass
# the validator and re-introduce the "Domain Admins" / escape-leak
# bug at the sudo-grant site.
guard_grep "domgroup: sudo path validates via appcore" \
    "$addc_sconfig" \
    'appcore_id_domgroup_validate'
guard_grep "domgroup: sudo path formats via appcore" \
    "$addc_sconfig" \
    'appcore_id_domgroup_format_sudoers'

# TUI: info/yesno/die delegate to appcore_tui_msgbox/yesno when
# the lib is loaded (Phase 2). Hand-fixed 12x64 / 10x60 dimensions
# clipped on wide content; the appcore variants auto-size.
guard_grep "TUI: samba-addc info() delegates to appcore_tui_msgbox" \
    "$addc_sconfig" \
    'appcore_tui_msgbox "\$\*"'
guard_grep "TUI: samba-addc yesno() delegates to appcore_tui_yesno" \
    "$addc_sconfig" \
    'appcore_tui_yesno "\$\*"'
guard_grep "TUI: smb-proxy info() delegates to appcore_tui_msgbox" \
    "$proxy_sconfig" \
    'appcore_tui_msgbox "\$\*"'
guard_grep "TUI: smb-proxy yesno() delegates to appcore_tui_yesno" \
    "$proxy_sconfig" \
    'appcore_tui_yesno "\$\*"'

# smb-proxy LAB-TESTING.md — force-user contract corners.
guard_grep "proxy: force user written as username (not numeric UID)" \
    "$proxy_sconfig" \
    'force user = \$\{?FRONT_FORCE_USER\}?'
guard_grep "proxy: AD-collision check via wbinfo --name-to-sid" \
    "$proxy_sconfig" \
    'wbinfo --name-to-sid "?\$\{?FRONT_FORCE_USER\}?"?'
guard_grep "proxy: cifs preexec quotes %S" \
    "$proxy_sconfig" \
    'smbproxy-probe-backend "%S"'

# proxy: nosharesock invariant (multi-share creds-isolation
# defense per AGENTS.md). This is the single most important cifs
# option after the locking-correct legacy bundle; pin it here
# even though backend_mount_opts unit tests already cover it.
guard_grep "proxy: nosharesock in cifs option string" \
    "$proxy_sconfig" \
    'nosharesock'

# 5. Appliance-core compliance: runs the generalized 10-check
# contract suite against every appliance found in the sibling layout.
# The checks are documented inline in
# appliance-core/bin/compliance-check.sh; --list prints the surface.
# Each check guards against a specific bug class we've actually
# seen (see the "Guards against" column).
step "5. appliance-core compliance check"
compliance_checker="$PARENT_DIR/appliance-core/bin/compliance-check.sh"
if [[ -x "$compliance_checker" ]]; then
    for app in samba-addc-appliance smb-proxy-appliance; do
        appdir="$PARENT_DIR/$app"
        if [[ -d "$appdir" ]]; then
            if "$compliance_checker" "$appdir" >/dev/null 2>&1; then
                pass "$app: compliance clean"
            else
                # Re-run with --report so the operator sees which check(s) failed.
                "$compliance_checker" --report "$appdir" || true
                fail "$app failed compliance — fix and re-run preflight"
            fi
        fi
    done
else
    printf '  skip — appliance-core/bin/compliance-check.sh not present at %s\n' "$compliance_checker"
fi

# 6. Static analysis. The current tree is clean at severity=warning
# with the documented exclusion list (SC1090, SC1091, SC2034 — rationale
# inline in bin/shellcheck-all.sh). Any new finding fails preflight
# before it reaches a VM run. The wrapper skips with a one-line note
# (and exits 0) when shellcheck is not installed, so preflight stays
# green on hosts without it.
step "6. shellcheck-all (strict)"
"$SCRIPT_DIR/shellcheck-all.sh" --strict || fail "shellcheck-all reported findings (run bin/shellcheck-all.sh standalone for the full list)"

printf '\n%spreflight: ALL CLEAN%s — safe to start a VM run.\n' "$BOLD" "$RST"
