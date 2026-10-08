#!/usr/bin/env bash
# tests/unit-helpers.sh — pure-bash unit tests for the helpers
# extracted from bin/find-fixmes.sh.
#
# What's tested and why:
#   - fixme_category() — getting the category wrong means the report
#     mis-tags lines (e.g. "REMOVE-WHEN-FIXED" lines reported as
#     plain TODO). Easy to break with a typo in the regex; hard to
#     notice in a 100-line report.
#   - is_meta_path() — getting the exclusion regex wrong means either
#     (a) STYLE.md / decisions/*.md / template-*/ self-matches start
#     polluting the report, or (b) real source files start being
#     silently excluded. Both are silent corruption of the only
#     signal these tools produce.
#
# The script is sourceable (library mode at the entry point); these
# tests source it and call the helpers directly.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/../bin/find-fixmes.sh"
[[ -f "$SCRIPT" ]] || { echo "FAIL: $SCRIPT not found" >&2; exit 2; }
# shellcheck disable=SC1090
source "$SCRIPT"

PASS=0
FAIL=0
FIRST_FAIL=""

check_eq() {
    local name="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        PASS=$((PASS + 1))
        [[ "${VERBOSE:-0}" == "1" ]] && printf '  ok   %s\n' "$name"
    else
        FAIL=$((FAIL + 1))
        printf 'FAIL  %s\n' "$name"
        printf '  expected: %s\n' "$expected"
        printf '  actual:   %s\n' "$actual"
        [[ -z "$FIRST_FAIL" ]] && FIRST_FAIL="$name"
    fi
}

# Assert is_meta_path's rc for a given path. Expected: "meta" or "real".
check_meta() {
    local name="$1" expected="$2" path="$3"
    local got
    if is_meta_path "$path"; then got="meta"; else got="real"; fi
    check_eq "$name" "$expected" "$got"
}

#-------------------------------------------------------------------------------
# fixme_category — correct tag wins when content has multiple matches.
#-------------------------------------------------------------------------------
echo "== fixme_category =="
check_eq "plain FIXME -> fixme" \
    "fixme" "$(fixme_category '// FIXME: clean this up')"
check_eq "FIXME(remove-when-fixed) -> remove-when-fixed (strict beats loose)" \
    "remove-when-fixed" "$(fixme_category '// FIXME(remove-when-fixed) ixgbevf panic')"
check_eq "TODO -> todo" \
    "todo" "$(fixme_category '// TODO: write the docs')"
check_eq "XXX -> xxx-hack" \
    "xxx-hack" "$(fixme_category '// XXX why does this work')"
check_eq "HACK -> xxx-hack" \
    "xxx-hack" "$(fixme_category '// HACK: cargo-culted from samba')"

# Critical tie-breaker: "FIXME(remove-when-fixed)" must beat plain
# "FIXME" because the content also contains the substring FIXME.
# Same for FIXME-then-TODO order: FIXME wins.
check_eq "FIXME(remove-when-fixed) wins over later TODO in same line" \
    "remove-when-fixed" "$(fixme_category '# FIXME(remove-when-fixed) until kernel fix; TODO recheck Q3')"
check_eq "FIXME wins over TODO in same line" \
    "fixme" "$(fixme_category '# FIXME: investigate. TODO: ticket')"
check_eq "TODO wins over XXX in same line" \
    "todo" "$(fixme_category '# TODO before XXX')"

#-------------------------------------------------------------------------------
# is_meta_path — pin the exclusion regex.
#
# Meta paths (excluded from the FIXME report) are the ones that *talk
# about* the FIXME convention: STYLE.md defines the form,
# PUBLISH-CHECKLIST.md reasons about it, decisions/*.md ADRs may
# cite past FIXMEs, audits/*.md summarize prior FIXMEs, the
# template-*/ skeletons describe the form for template users, and
# find-fixmes.sh itself contains the regex literals that would
# self-match. Everything else is a real source path and must be
# REPORTED.
#-------------------------------------------------------------------------------
echo "== is_meta_path =="

# Excluded — meta files at any depth.
check_meta "bare STYLE.md is meta"           "meta" "STYLE.md"
check_meta "STYLE.md under repo is meta"     "meta" "dev-commons/STYLE.md"
check_meta "PUBLISH-CHECKLIST.md is meta"    "meta" "dev-commons/PUBLISH-CHECKLIST.md"
check_meta "decisions/0001-foo.md is meta"   "meta" "decisions/0001-naimor-oss-org.md"
check_meta "audits/2026-04.md is meta"       "meta" "audits/2026-04-style-sweep.md"
check_meta "find-fixmes.sh is meta"          "meta" "bin/find-fixmes.sh"
check_meta "template-appliance-virtualized/foo.sh is meta" \
    "meta" "template-appliance-virtualized/scripts/foo.sh"
check_meta "template-appliance-iot/anything is meta" \
    "meta" "template-appliance-iot/CONTEXT.md"

# Included — real source paths that LOOK similar but aren't meta.
check_meta "AGENTS.md is REAL (just sits next to STYLE.md)" \
    "real" "AGENTS.md"
check_meta "README.md is REAL" \
    "real" "smb-proxy-appliance/README.md"
check_meta "scripts/foo.sh in a real repo is REAL" \
    "real" "smb-proxy-appliance/scripts/foo.sh"
check_meta "lab/scenarios/x.sh is REAL" \
    "real" "smb-proxy-appliance/lab/scenarios/end-to-end.sh"
check_meta "decisions.txt (no .md) is REAL" \
    "real" "decisions.txt"
check_meta "audits.md (singular, top-level) is REAL" \
    "real" "audits.md"
check_meta "template-not-a-dir.md (no trailing slash) is REAL" \
    "real" "template-not-a-dir.md"

# Adversarial: paths that would have caught the previous grep -vE
# regex's failure modes.
check_meta "STYLE.md.bak is REAL (we don't exclude backup files)" \
    "real" "STYLE.md.bak"
check_meta "MY-STYLE.md is REAL (substring match would wrongly exclude)" \
    "real" "MY-STYLE.md"
check_meta "find-fixmes.sh.bak is REAL" \
    "real" "bin/find-fixmes.sh.bak"

# Bug regression check: STYLE.md inside a REAL repo's docs/ subdir.
# The original grep -vE used '(^|/)(PUBLISH-CHECKLIST|STYLE)\.md:' —
# the trailing colon was meant to match grep's path:line:content
# format, but as a path-test it'd never match a path ending in .md
# without a colon. The new is_meta_path matches the path proper.
check_meta "docs/STYLE.md inside a sibling is meta" \
    "meta" "smb-proxy-appliance/docs/STYLE.md"

#-------------------------------------------------------------------------------
echo
echo "summary: $PASS passed, $FAIL failed"
if [[ "$FAIL" -gt 0 ]]; then
    echo "first failure: $FIRST_FAIL"
    exit 1
fi
exit 0
