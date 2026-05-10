#!/usr/bin/env bash
# bin/preflight.sh — composed no-VM gate.
#
# Run this BEFORE any VM scenario. It chains the four cheap checks
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
#   3. appliance-core: bats tests/unit/ — currently 94 cases over
#      detect-net, identity, tui, hostname, apt-helpers, netconfig.
#   4. smb-proxy: bash tests/unit-helpers.sh — pure-function
#      assertions on share_safe_name, share_name_validate,
#      backend_mount_opts, etc.
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

# 3. appliance-core bats unit tests.
step "3. appliance-core bats tests/unit/"
ac_dir="$PARENT_DIR/appliance-core"
if [[ -d "$ac_dir/tests/unit" ]]; then
    if ! command -v bats >/dev/null 2>&1; then
        printf '  skip — bats not installed (brew install bats-core / apt install bats)\n'
    else
        ( cd "$ac_dir" && bats tests/unit/ ) \
            || fail "appliance-core bats tests failed"
        pass "appliance-core bats"
    fi
else
    printf '  skip — appliance-core/tests/unit not present\n'
fi

# 4. smb-proxy unit-helpers.
step "4. smb-proxy tests/unit-helpers.sh"
sp_test="$PARENT_DIR/smb-proxy-appliance/tests/unit-helpers.sh"
if [[ -f "$sp_test" ]]; then
    bash "$sp_test" || fail "smb-proxy unit-helpers failed"
    pass "smb-proxy unit-helpers"
else
    printf '  skip — smb-proxy unit-helpers.sh not present\n'
fi

# 5. Source-level contract guards. These pin design decisions
# documented in samba-addc-appliance/docs/DFS-N.md and
# smb-proxy-appliance/docs/LAB-TESTING.md so a refactor that
# silently violates the protocol fails preflight before any VM
# run. Each guard is a single grep over the runtime source — the
# protocol claim is encoded as the search pattern.
step "5. design-contract source guards"

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

# 6. Static analysis. The current tree is clean at severity=warning
# with the documented exclusion list (SC1090, SC1091, SC2034 — rationale
# inline in bin/shellcheck-all.sh). Any new finding fails preflight
# before it reaches a VM run. The wrapper skips with a one-line note
# (and exits 0) when shellcheck is not installed, so preflight stays
# green on hosts without it.
step "6. shellcheck-all (strict)"
"$SCRIPT_DIR/shellcheck-all.sh" --strict || fail "shellcheck-all reported findings (run bin/shellcheck-all.sh standalone for the full list)"

printf '\n%spreflight: ALL CLEAN%s — safe to start a VM run.\n' "$BOLD" "$RST"
