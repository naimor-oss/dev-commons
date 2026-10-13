#!/usr/bin/env bash
#===============================================================================
# ws-publish.sh — push one branch name across the siblings, in order
#
# Cross-repo changes use the SAME branch name in every repo they touch: the
# shared CI workflow checks out a sibling's same-named branch when it exists,
# so a producer change and its consumers are validated together. This script
# takes the one branch name, so that rule cannot be broken by accident.
#
# For each sibling (dependency order) that has BRANCH locally and at least one
# commit beyond origin/<default>: refuse a dirty tree, push with upstream
# tracking, and with --pr open a pull request if none is open for it.
# Siblings without the branch, or with nothing new on it, are skipped.
#
# With --pr the active gh account must have push access to every repo that is
# about to get a PR; this is checked first so the run does not stop half way
# (a read-only account only fails at PR creation: "must be a collaborator").
# Switch accounts with `gh auth switch -u NAME`.
#
# Usage:
#   bin/ws-publish.sh BRANCH             # show the plan, push nothing
#   bin/ws-publish.sh BRANCH --yes       # push
#   bin/ws-publish.sh BRANCH --yes --pr  # push and open PRs
#   bin/ws-publish.sh BRANCH --yes --pr --title "TITLE" --body-file FILE
#   bin/ws-publish.sh -d /some/dir ...   # parent dir override
#===============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-workspace.sh
source "$SCRIPT_DIR/lib-workspace.sh"

usage() { sed -n '/^# Usage:/,/^#====/p' "$0" | sed 's/^# \{0,1\}//' | sed '$d'; }

BRANCH="" YES=0 PR=0 TITLE="" BODY_FILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--parent-dir) WS_PARENT_DIR="$2"; shift 2 ;;
        --yes)           YES=1; shift ;;
        --pr)            PR=1; shift ;;
        --title)         TITLE="$2"; shift 2 ;;
        --body-file)     BODY_FILE="$2"; shift 2 ;;
        -h|--help)       usage; exit 0 ;;
        -*)              ws_die "unknown option: $1" ;;
        *)               [[ -z "$BRANCH" ]] || ws_die "one BRANCH only"; BRANCH="$1"; shift ;;
    esac
done
[[ -n "$BRANCH" ]] || { usage >&2; exit 2; }
ws_parse_common "$SCRIPT_DIR"
[[ -z "$BODY_FILE" || -r "$BODY_FILE" ]] || ws_die "cannot read $BODY_FILE"

plan=()
for r in $(ws_repos); do
    ws_branch_local "$r" "$BRANCH" || continue
    n=$(ws_commits_beyond_default "$r" "$BRANCH")
    [[ "$n" -gt 0 ]] || { ws_say "skip $r: $BRANCH has nothing beyond origin/$(ws_default_branch "$r" | head -1)"; continue; }
    if ws_dirty "$r" && [[ "$(ws_git "$r" branch --show-current)" == "$BRANCH" ]]; then
        ws_die "$r has uncommitted changes on $BRANCH; commit or stash first"
    fi
    plan+=("$r")
done
[[ ${#plan[@]} -gt 0 ]] || { ws_say "nothing to publish for $BRANCH"; exit 0; }

ws_say "publish order for $BRANCH:"
i=1; for r in "${plan[@]}"; do
    ws_say "  $i. $r ($(ws_commits_beyond_default "$r" "$BRANCH") commit(s))"; i=$((i+1))
done

if [[ "$PR" -eq 1 ]]; then
    command -v gh >/dev/null || ws_die "--pr needs the gh CLI"
    acct=$(ws_gh_account)
    ws_say "gh account: ${acct:-unknown}"
    for r in "${plan[@]}"; do
        ws_gh_can_push "$r" || ws_die "gh account '${acct:-?}' cannot push to $WS_ORG/$r (try: gh auth switch -u NAME)"
    done
fi
[[ "$YES" -eq 1 ]] || { ws_say "(plan only — add --yes to push)"; exit 0; }

for r in "${plan[@]}"; do
    ws_say "== $r"
    ws_git "$r" push -q -u origin "$BRANCH" || ws_die "push failed in $r (stopping: later repos may depend on it)"
    [[ "$PR" -eq 1 ]] || continue
    existing=$(ws_open_pr_number "$r" "$BRANCH")
    if [[ -n "$existing" ]]; then ws_say "   PR already open: #$existing"; continue; fi
    def=$(ws_default_branch "$r" | head -1)
    t="${TITLE:-$BRANCH}"
    if [[ -n "$BODY_FILE" ]]; then
        gh pr create -R "$WS_ORG/$r" --base "$def" --head "$BRANCH" --title "$t" --body-file "$BODY_FILE"
    else
        gh pr create -R "$WS_ORG/$r" --base "$def" --head "$BRANCH" --title "$t" \
            --body "Branch $BRANCH. Merge in dependency order (bin/ws-merge.sh)."
    fi || ws_die "PR creation failed in $r"
done
