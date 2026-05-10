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

printf '\n%spreflight: ALL CLEAN%s — safe to start a VM run.\n' "$BOLD" "$RST"
