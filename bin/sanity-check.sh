#!/usr/bin/env bash
#===============================================================================
# sanity-check.sh — bash -n syntax sweep across every sibling repo's
# shell scripts. Run before committing cross-cutting changes; run before
# pushing.
#
# What it covers (per sibling repo):
#   - Top-level *.sh
#   - lab/*.sh, lab/scenarios/*.sh (where present)
#   - bin/*.sh, scripts/*.sh, hypervisors/**/*.sh (where present)
#
# What it does NOT cover (deliberately):
#   - PowerShell .ps1 files. pwsh syntax-check needs pwsh on the host
#     and a separate runner; out of scope for this sweep.
#   - Linting beyond `bash -n` (no shellcheck dependency).
#
# Exits non-zero if any script fails the parse. Prints a per-file pass/
# fail line so the failure is locatable.
#
# Usage:
#   bin/sanity-check.sh                # walk all known siblings
#   bin/sanity-check.sh -d /some/dir   # parent dir override
#===============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

usage() {
    sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--parent-dir)  PARENT_DIR="$2"; shift 2 ;;
        -h|--help)        usage; exit 0 ;;
        *) echo "unknown arg: $1" >&2; usage >&2; exit 2 ;;
    esac
done

# Auto-discover siblings (any direct subdir of PARENT_DIR with a .git dir).
shopt -s nullglob
repos=()
for d in "$PARENT_DIR"/*/; do
    [[ -d "$d/.git" ]] && repos+=("$(basename "$d")")
done
shopt -u nullglob

[[ ${#repos[@]} -gt 0 ]] || { echo "No git repos under $PARENT_DIR" >&2; exit 0; }

if [[ -t 1 ]]; then
    BOLD=$'\033[1m'; RST=$'\033[0m'
    GREEN=$'\033[32m'; RED=$'\033[31m'; DIM=$'\033[2m'
else
    BOLD=''; RST=''; GREEN=''; RED=''; DIM=''
fi

total_files=0
total_failures=0

for r in "${repos[@]}"; do
    cd "$PARENT_DIR/$r" || continue
    printf '%s%s%s\n' "$BOLD" "$r" "$RST"

    # Find shell scripts in conventional locations. -maxdepth limits keep
    # the sweep predictable — accidental .sh files in test-results/ or
    # vendored dirs don't get pulled in.
    files=()
    while IFS= read -r f; do
        files+=("$f")
    done < <(
        {
            find . -maxdepth 1 -type f -name '*.sh' 2>/dev/null
            find ./lab -maxdepth 1 -type f -name '*.sh' 2>/dev/null
            find ./lab/scenarios -maxdepth 1 -type f -name '*.sh' 2>/dev/null
            find ./bin -maxdepth 1 -type f -name '*.sh' 2>/dev/null
            find ./scripts -maxdepth 1 -type f -name '*.sh' 2>/dev/null
            find ./hypervisors -type f -name '*.sh' 2>/dev/null
        } | sort -u
    )

    if [[ ${#files[@]} -eq 0 ]]; then
        printf '  %s(no shell scripts found)%s\n' "$DIM" "$RST"
        continue
    fi

    for f in "${files[@]}"; do
        total_files=$((total_files + 1))
        if bash -n "$f" 2>/tmp/sanity.$$; then
            printf '  %sOK%s   %s\n' "$GREEN" "$RST" "$f"
        else
            total_failures=$((total_failures + 1))
            printf '  %sFAIL%s %s\n' "$RED" "$RST" "$f"
            sed 's/^/       /' < /tmp/sanity.$$
        fi
    done
    rm -f /tmp/sanity.$$
done

echo
printf '%ssummary%s: %d files checked, ' "$BOLD" "$RST" "$total_files"
if [[ "$total_failures" -eq 0 ]]; then
    printf '%sall passed%s\n' "$GREEN" "$RST"
    exit 0
else
    printf '%s%d failed%s\n' "$RED" "$total_failures" "$RST"
    exit 1
fi
