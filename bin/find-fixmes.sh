#!/usr/bin/env bash
#===============================================================================
# find-fixmes.sh — trawl all sibling repos for FIXME blocks, with focus
# on the FIXME(remove-when-fixed) variant prescribed by STYLE.md §10
# for defensive workarounds that should not outlive their cause.
#
# Without this trawler, FIXME blocks rot. The ixgbevf blacklist in
# smb-proxy-appliance is the canonical example: easy to add a defensive
# workaround, easy to forget six months later that the kernel fixed it.
# Run this periodically (or in a scheduled agent) to surface what's
# still in effect.
#
# What it reports per match:
#   - file:line
#   - the FIXME line itself
#   - last-modified date of the file (proxy for FIXME age — git blame
#     would be more precise but slower; this is a sweep, not a forensic)
#
# Categories:
#   - "remove-when-fixed" — the formal STYLE.md §10 form; highest priority
#   - "TODO" / "XXX" / "HACK" — caught for completeness but lower signal
#
# Usage:
#   bin/find-fixmes.sh                 # all categories, all siblings
#   bin/find-fixmes.sh --strict        # only FIXME(remove-when-fixed)
#   bin/find-fixmes.sh -d /some/dir    # parent dir override
#===============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
STRICT=0

usage() {
    sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--parent-dir)  PARENT_DIR="$2"; shift 2 ;;
        --strict)         STRICT=1; shift ;;
        -h|--help)        usage; exit 0 ;;
        *) echo "unknown arg: $1" >&2; usage >&2; exit 2 ;;
    esac
done

shopt -s nullglob
repos=()
for d in "$PARENT_DIR"/*/; do
    [[ -d "$d/.git" ]] && repos+=("$(basename "$d")")
done
shopt -u nullglob

[[ ${#repos[@]} -gt 0 ]] || { echo "No git repos under $PARENT_DIR" >&2; exit 0; }

if [[ -t 1 ]]; then
    BOLD=$'\033[1m'; RST=$'\033[0m'; DIM=$'\033[2m'
    RED=$'\033[31m'; YELLOW=$'\033[33m'; CYAN=$'\033[36m'
else
    BOLD=''; RST=''; DIM=''; RED=''; YELLOW=''; CYAN=''
fi

# Strict regex matches the formal §10 form. Loose adds the common
# informal forms; the categorization in the report distinguishes them.
strict_re='FIXME\(remove-when-fixed\)'
loose_re='FIXME|TODO|XXX|HACK'

if [[ $STRICT -eq 1 ]]; then
    re="$strict_re"
    printf '%sfind-fixmes%s — strict mode (FIXME(remove-when-fixed) only)\n\n' "$BOLD" "$RST"
else
    re="($strict_re|$loose_re)"
    printf '%sfind-fixmes%s — all categories\n\n' "$BOLD" "$RST"
fi

total=0

for r in "${repos[@]}"; do
    cd "$PARENT_DIR/$r" || continue

    # Use git ls-files so we only scan tracked content. Untracked scratch
    # files and ignored dirs don't pollute the report.
    # Exclude meta-files that *talk about* the FIXME convention rather
    # than carrying real FIXMEs: STYLE.md (defines the form),
    # PUBLISH-CHECKLIST.md (reasons about it), the decisions/ ADRs and
    # audits/ reports (may cite past FIXMEs), the template-* skeletons
    # (which describe the form to template users), and this script
    # itself (regex literals would self-match). Pattern matches both
    # bare-filename (when run from inside the repo) and path-prefixed
    # forms.
    matches=$(git ls-files -z 2>/dev/null \
        | xargs -0 grep -EnH "$re" 2>/dev/null \
        | grep -vE '(^|/)(PUBLISH-CHECKLIST|STYLE)\.md:|(^|/)find-fixmes\.sh:|(^|/)(decisions|audits)/.*\.md:|(^|/)template-[^/]+/' \
        || true)

    [[ -z "$matches" ]] && continue

    printf '%s%s%s\n' "$BOLD" "$r" "$RST"

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        total=$((total + 1))

        # line format: <path>:<lineno>:<content>
        path=${line%%:*}
        rest=${line#*:}
        lineno=${rest%%:*}
        content=${rest#*:}

        # Categorize: strict form first, then loose forms.
        if grep -qE "$strict_re" <<< "$content"; then
            tag="${RED}REMOVE-WHEN-FIXED${RST}"
        elif grep -qE 'FIXME' <<< "$content"; then
            tag="${YELLOW}FIXME${RST}            "
        elif grep -qE 'TODO' <<< "$content"; then
            tag="${CYAN}TODO${RST}             "
        else
            tag="${DIM}XXX/HACK${RST}         "
        fi

        # File age — last commit touching this file. Skip if not in git.
        age=$(git log -1 --format='%cs' -- "$path" 2>/dev/null || echo '?')

        # Trim long content lines so output stays scannable.
        content_trim=$(echo "$content" | sed 's/^[[:space:]]*//' | cut -c -90)
        printf '  %s  %s%s:%s%s  %s(touched %s)%s\n' \
            "$tag" "$DIM" "$path" "$lineno" "$RST" "$DIM" "$age" "$RST"
        printf '              %s\n' "$content_trim"
    done <<< "$matches"
    echo
done

if [[ "$total" -eq 0 ]]; then
    printf '%sno matches%s — clean across all siblings\n' "${BOLD}" "${RST}"
else
    printf '%ssummary%s: %d matches across siblings\n' "$BOLD" "$RST" "$total"
    if [[ $STRICT -eq 0 ]]; then
        printf '%s(re-run with --strict to focus on FIXME(remove-when-fixed) only)%s\n' "$DIM" "$RST"
    fi
fi
