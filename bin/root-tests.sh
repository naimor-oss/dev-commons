#!/usr/bin/env bash
# bin/root-tests.sh — every sibling's root integration suites, locally.
#
# tests/root/*.sh drive real system paths (/etc/samba, /var/lib/...) as
# root, so each runs in its own disposable Debian 13 container and refuses
# to start without DISPOSABLE_ROOT_TEST=1. preflight.sh never runs them,
# and neither does GitHub's preflight: anonymous image pulls from shared
# runners hit each registry's rate or data limit in turn, so the suites run
# on a machine with Docker, where the image is pulled once and cached.
#
#   bin/root-tests.sh [--pull] [repo ...]
#
# With no repo named, every sibling's suites run. --pull refreshes the
# image; otherwise it is pulled only when absent. ROOT_TEST_IMAGE overrides
# the image (default debian:trixie). Every suite runs even after a failure;
# the exit status is non-zero if any failed. A pull request whose change a
# root suite exercises states the summary line, with no failures, in its
# description; preflight fails it otherwise (bin/root-suite-gate.sh,
# decisions/0003).
#
# Run from any directory; the script resolves the sibling layout relative
# to its own location, and mounts it read-only at /ws so a suite can use
# its siblings (e.g. ../appliance-core/lib/kvstate.sh).

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
IMAGE="${ROOT_TEST_IMAGE:-debian:trixie}"

pull=0
repos=()
while (($#)); do
    case $1 in
        --pull) pull=1 ;;
        -h|--help) sed -n '2,/^set -euo/{/^set -euo/d;s/^# \{0,1\}//;p}' "$0"; exit 0 ;;
        -*) echo "unknown option: $1 (--help)" >&2; exit 2 ;;
        *) repos+=("$1") ;;
    esac
    shift
done
((${#repos[@]})) || repos=(
    dev-commons appliance-core lab-kit lab-router
    samba-addc-appliance smb-proxy-appliance smbproxy-session-vfs
)

command -v docker >/dev/null 2>&1 || {
    echo "Docker was not found; the root suites need it" >&2
    exit 2
}

suites=()
for repo in "${repos[@]}"; do
    [[ -d "$PARENT_DIR/$repo" ]] || { echo "skip $repo (not cloned beside dev-commons)"; continue; }
    suites+=("$PARENT_DIR/$repo"/tests/root/*.sh)
done
if ((${#suites[@]} == 0)); then
    echo "root integration suites run: 0"
    exit 0
fi

if ((pull)) || ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    docker pull --quiet "$IMAGE"
fi
echo "image: $IMAGE ($(docker image inspect --format '{{.Id}}' "$IMAGE" | cut -c1-19))"

ran=0
failed=()
for t in "${suites[@]}"; do
    rel=${t#"$PARENT_DIR"/}
    echo "== $rel"
    if docker run --rm --pull never -v "$PARENT_DIR:/ws:ro" -e DISPOSABLE_ROOT_TEST=1 \
            "$IMAGE" bash "/ws/$rel"; then
        echo "PASS $rel"
    else
        echo "FAIL $rel"
        failed+=("$rel")
    fi
    ran=$((ran + 1))
done
echo "root integration suites run: $ran, failed: ${#failed[@]}${failed:+ (${failed[*]})}"
((${#failed[@]} == 0))
