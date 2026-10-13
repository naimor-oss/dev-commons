#!/usr/bin/env bash
#===============================================================================
# ws-merge.sh — merge one branch's pull requests across the siblings, in order
#
# Walks the siblings in dependency order (producer first). For each one with
# an open PR for BRANCH: wait for its checks, merge it (merge commit), then
# move on. A red check STOPS the run, because everything after it may depend
# on it; --allow-red merges through a red check, and is only for a failure
# that is the CI infrastructure's and not the code's (for example a registry
# rate limit) — say so in the PR when you use it.
#
# Without --yes it prints the plan and the state of each PR and merges
# nothing. After the last merge it runs ws-sync.sh --prune-merged so every
# checkout is back on the default branch, current, with merged branches gone.
#
# Usage:
#   bin/ws-merge.sh BRANCH               # show the plan, merge nothing
#   bin/ws-merge.sh BRANCH --yes         # wait for green, merge in order
#   bin/ws-merge.sh BRANCH --yes --allow-red
#   bin/ws-merge.sh -d /some/dir ...     # parent dir override
#
# Exit 0 when every PR merged; 1 when the run stopped early.
#===============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-workspace.sh
source "$SCRIPT_DIR/lib-workspace.sh"

usage() { sed -n '/^# Usage:/,/^# Exit/p' "$0" | sed 's/^# \{0,1\}//'; }

BRANCH="" YES=0 ALLOW_RED=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--parent-dir) WS_PARENT_DIR="$2"; shift 2 ;;
        --yes)           YES=1; shift ;;
        --allow-red)     ALLOW_RED=1; shift ;;
        -h|--help)       usage; exit 0 ;;
        -*)              ws_die "unknown option: $1" ;;
        *)               [[ -z "$BRANCH" ]] || ws_die "one BRANCH only"; BRANCH="$1"; shift ;;
    esac
done
[[ -n "$BRANCH" ]] || { usage >&2; exit 2; }
ws_parse_common "$SCRIPT_DIR"
command -v gh >/dev/null || ws_die "needs the gh CLI"

plan_repos=() plan_prs=()
for r in $(ws_repos); do
    n=$(ws_open_pr_number "$r" "$BRANCH")
    [[ -n "$n" ]] || continue
    plan_repos+=("$r"); plan_prs+=("$n")
done
[[ ${#plan_repos[@]} -gt 0 ]] || { ws_say "no open PRs for $BRANCH"; exit 0; }

acct=$(ws_gh_account)
ws_say "gh account: ${acct:-unknown}"
ws_say "merge order for $BRANCH:"
for i in "${!plan_repos[@]}"; do
    ws_say "  $((i+1)). $WS_ORG/${plan_repos[$i]}#${plan_prs[$i]}"
done
if [[ "$YES" -ne 1 ]]; then
    for r in "${plan_repos[@]}"; do
        ws_gh_can_push "$r" || ws_say "  warning: '${acct:-?}' cannot push to $WS_ORG/$r"
    done
    ws_say "(plan only — add --yes to merge)"
    exit 0
fi

for i in "${!plan_repos[@]}"; do
    r="${plan_repos[$i]}" n="${plan_prs[$i]}"
    ws_say "== $r #$n"
    if gh pr checks "$n" -R "$WS_ORG/$r" --watch --interval 20 >/dev/null 2>&1; then
        ws_say "   checks green"
    elif [[ "$ALLOW_RED" -eq 1 ]]; then
        ws_say "   checks NOT green — merging anyway (--allow-red)"
    else
        ws_say "   checks not green — stopping. Fix it, or re-run with --allow-red if the failure is CI infrastructure."
        exit 1
    fi
    gh pr merge "$n" -R "$WS_ORG/$r" --merge || { ws_say "   merge failed — stopping"; exit 1; }
done

ws_say "== returning every checkout to the default branch"
"$SCRIPT_DIR/ws-sync.sh" --prune-merged -d "$WS_PARENT_DIR"
