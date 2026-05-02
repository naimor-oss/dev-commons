#!/usr/bin/env bash
#===============================================================================
# sibling-status.sh — one-shot view of every sibling repo's git state
#
# Run from anywhere. Walks the standard sibling layout (one parent dir
# above this script's grandparent) and prints, per repo:
#
#   - branch name
#   - dirty file count (working tree + index)
#   - ahead / behind vs origin/<branch> if a remote exists
#   - one-line head commit
#   - one-line warning if the repo has no remote yet (most often: held
#     pending NaimorOSS org creation per dev-commons/decisions/0001-*)
#
# Output is ANSI-colored when stdout is a terminal; pipe-friendly
# otherwise. Exit 0 always (this is informational, not a gate).
#
# Usage:
#   bin/sibling-status.sh                # walk all known siblings
#   bin/sibling-status.sh -d /some/dir   # parent dir override
#   bin/sibling-status.sh --no-color     # force plain output
#===============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
NO_COLOR=0

usage() {
    sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--parent-dir)  PARENT_DIR="$2"; shift 2 ;;
        --no-color)       NO_COLOR=1; shift ;;
        -h|--help)        usage; exit 0 ;;
        *) echo "unknown arg: $1" >&2; usage >&2; exit 2 ;;
    esac
done

# Color setup. Only when stdout is a tty AND not explicitly disabled.
if [[ $NO_COLOR -eq 0 && -t 1 ]]; then
    BOLD=$'\033[1m'; DIM=$'\033[2m'; RST=$'\033[0m'
    GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; CYAN=$'\033[36m'
else
    BOLD=''; DIM=''; RST=''; GREEN=''; YELLOW=''; RED=''; CYAN=''
fi

# Walk every direct subdir of PARENT_DIR that contains a .git directory.
# This auto-discovers siblings without needing a hardcoded list — when a
# new sibling is added, it shows up here on the next run.
shopt -s nullglob
repos=()
for d in "$PARENT_DIR"/*/; do
    [[ -d "$d/.git" ]] && repos+=("$(basename "$d")")
done
shopt -u nullglob

if [[ ${#repos[@]} -eq 0 ]]; then
    echo "No git repos found under $PARENT_DIR" >&2
    exit 0
fi

printf '%ssibling-status%s — %s\n\n' "$BOLD" "$RST" "$PARENT_DIR"

for r in "${repos[@]}"; do
    cd "$PARENT_DIR/$r" || continue

    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')
    dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

    # Ahead/behind reporting — only meaningful if a tracking remote exists.
    remote_status=''
    upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
    if [[ -n "$upstream" ]]; then
        # `git rev-list --left-right --count <upstream>...HEAD` returns
        # "<behind>\t<ahead>". Robust across detached / rebased states.
        counts=$(git rev-list --left-right --count "$upstream"...HEAD 2>/dev/null || echo "0	0")
        behind=$(echo "$counts" | cut -f1)
        ahead=$(echo "$counts"  | cut -f2)
        if   [[ "$ahead" -gt 0 && "$behind" -gt 0 ]]; then
            remote_status="${YELLOW}ahead $ahead, behind $behind${RST}"
        elif [[ "$ahead" -gt 0 ]];  then remote_status="${YELLOW}ahead $ahead${RST}"
        elif [[ "$behind" -gt 0 ]]; then remote_status="${YELLOW}behind $behind${RST}"
        else                             remote_status="${GREEN}up to date${RST}"
        fi
    else
        remote_status="${RED}no remote${RST}"
    fi

    dirty_label=''
    if [[ "$dirty" -gt 0 ]]; then
        dirty_label="${YELLOW}${dirty} dirty${RST}"
    else
        dirty_label="${GREEN}clean${RST}"
    fi

    head_line=$(git log -1 --format='%h %s' 2>/dev/null | cut -c -78)

    printf '  %s%-26s%s  %s on %s%s%s  %s\n' \
        "$BOLD" "$r" "$RST" "$dirty_label" "$CYAN" "$branch" "$RST" "$remote_status"
    printf '  %s%26s  %s%s\n' "" "" "$DIM$head_line" "$RST"
done

echo
