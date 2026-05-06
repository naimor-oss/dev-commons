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

# Strict regex matches the formal §10 form. Loose adds the common
# informal forms; the categorization in the report distinguishes them.
# Module-scope constants so the helpers below and the main loop share
# one definition.
readonly STRICT_RE='FIXME\(remove-when-fixed\)'
readonly LOOSE_RE='FIXME|TODO|XXX|HACK'

# Categorize one match content. Echoes one of:
#   remove-when-fixed | fixme | todo | xxx-hack
# Pure function — no globals read or written, no I/O. Tested by
# tests/unit-helpers.sh.
fixme_category() {
    local content="$1"
    if grep -qE "$STRICT_RE" <<< "$content"; then
        echo "remove-when-fixed"
    elif grep -qE 'FIXME' <<< "$content"; then
        echo "fixme"
    elif grep -qE 'TODO' <<< "$content"; then
        echo "todo"
    else
        echo "xxx-hack"
    fi
}

# True (rc=0) if the given path looks like a meta-file that *talks
# about* FIXMEs rather than carrying them — STYLE.md (defines the
# form), PUBLISH-CHECKLIST.md (reasons about it), the decisions/ ADRs
# and audits/ reports (may cite past FIXMEs), the template-* skeletons
# (which describe the form to template users), and find-fixmes.sh
# itself (regex literals would self-match). Pattern matches both
# bare-filename (when run from inside the repo) and path-prefixed
# forms.
#
# Return codes (per shell convention):
#   0 = is a meta path (should be EXCLUDED from FIXME report)
#   1 = is a real path (should be INCLUDED)
is_meta_path() {
    local path="$1"
    [[ "$path" =~ (^|/)(PUBLISH-CHECKLIST|STYLE)\.md$ ]]    && return 0
    [[ "$path" =~ (^|/)find-fixmes\.sh$ ]]                  && return 0
    [[ "$path" =~ (^|/)(decisions|audits)/.*\.md$ ]]        && return 0
    [[ "$path" =~ (^|/)template-[^/]+/ ]]                   && return 0
    return 1
}

# Library mode: when sourced (not executed), define helpers and stop
# here so tests can call them without running the trawl. The standard
# bash sourced-vs-executed check.
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    return 0
fi

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

if [[ $STRICT -eq 1 ]]; then
    re="$STRICT_RE"
    printf '%sfind-fixmes%s — strict mode (FIXME(remove-when-fixed) only)\n\n' "$BOLD" "$RST"
else
    re="($STRICT_RE|$LOOSE_RE)"
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
    # Trawl every tracked file, then filter via is_meta_path so the
    # exclusion logic lives in one tested place (not a long grep -vE
    # whose intent rots).
    matches=$(git ls-files -z 2>/dev/null \
        | xargs -0 grep -EnH "$re" 2>/dev/null \
        || true)

    [[ -z "$matches" ]] && continue

    printf '%s%s%s\n' "$BOLD" "$r" "$RST"

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        # line format: <path>:<lineno>:<content>
        path=${line%%:*}
        rest=${line#*:}
        lineno=${rest%%:*}
        content=${rest#*:}

        # Skip meta-paths (STYLE.md, decisions/, this script, etc.)
        is_meta_path "$path" && continue

        total=$((total + 1))

        case "$(fixme_category "$content")" in
            remove-when-fixed) tag="${RED}REMOVE-WHEN-FIXED${RST}" ;;
            fixme)             tag="${YELLOW}FIXME${RST}            " ;;
            todo)              tag="${CYAN}TODO${RST}             " ;;
            xxx-hack|*)        tag="${DIM}XXX/HACK${RST}         " ;;
        esac

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
