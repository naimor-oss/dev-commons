#!/usr/bin/env bash
#===============================================================================
# ws-sync.sh — bring every sibling checkout to a known, current state
#
# For each sibling (dependency order): fetch, then check out BRANCH when it
# exists there (locally or on origin), otherwise the default branch, and
# fast-forward to its upstream. Never discards anything:
#   - a dirty working tree is skipped and reported, not touched;
#   - a branch that cannot fast-forward (local commits, or diverged) is
#     reported as "diverged" and left as it is.
#
# After a merge, run it without BRANCH (or with --prune-merged) to get every
# repo back on the default branch and drop local branches whose commits are
# already on origin/<default>. Deletion uses `git branch -d`, which refuses
# anything not fully merged.
#
# Usage:
#   bin/ws-sync.sh                       # every repo on its default branch
#   bin/ws-sync.sh BRANCH                # repos that have BRANCH switch to it
#   bin/ws-sync.sh --prune-merged        # also delete merged local branches
#   bin/ws-sync.sh -d /some/dir          # parent dir override
#
# Exit 0 when every repo is clean and current; 1 when any was skipped.
#===============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-workspace.sh
source "$SCRIPT_DIR/lib-workspace.sh"

usage() { sed -n '/^# Usage:/,/^# Exit/p' "$0" | sed 's/^# \{0,1\}//'; }

BRANCH="" PRUNE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--parent-dir)  WS_PARENT_DIR="$2"; shift 2 ;;
        --prune-merged)   PRUNE=1; shift ;;
        -h|--help)        usage; exit 0 ;;
        -*)               ws_die "unknown option: $1" ;;
        *)                [[ -z "$BRANCH" ]] || ws_die "one BRANCH only"; BRANCH="$1"; shift ;;
    esac
done
ws_parse_common "$SCRIPT_DIR"

skipped=0
for r in $(ws_repos); do
    if ! ws_git "$r" fetch -q --prune origin 2>/dev/null; then
        ws_say "$(printf '%-24s' "$r") fetch failed (offline? no remote?) — skipped"
        skipped=1; continue
    fi
    if ws_dirty "$r"; then
        ws_say "$(printf '%-24s' "$r") dirty working tree — skipped (commit or stash first)"
        skipped=1; continue
    fi
    def=$(ws_default_branch "$r" | head -1)
    target="$def"
    if [[ -n "$BRANCH" ]] && ws_branch_exists "$r" "$BRANCH"; then target="$BRANCH"; fi

    cur=$(ws_git "$r" branch --show-current)
    if [[ "$cur" != "$target" ]]; then
        if ws_branch_local "$r" "$target"; then
            ws_git "$r" checkout -q "$target" || { ws_say "$r: checkout $target failed"; skipped=1; continue; }
        else
            ws_git "$r" checkout -q -b "$target" --track "origin/$target" \
                || { ws_say "$r: checkout $target failed"; skipped=1; continue; }
        fi
    fi

    state="current"
    if ws_branch_remote "$r" "$target"; then
        if ! ws_git "$r" merge --ff-only -q "origin/$target" >/dev/null 2>&1; then
            ahead=$(ws_git "$r" rev-list --count "origin/$target..$target")
            behind=$(ws_git "$r" rev-list --count "$target..origin/$target")
            state="DIVERGED (ahead $ahead, behind $behind) — left alone"
            skipped=1
        else
            ahead=$(ws_git "$r" rev-list --count "origin/$target..$target")
            [[ "$ahead" -eq 0 ]] || state="ahead of origin by $ahead (unpushed)"
        fi
    else
        state="no origin/$target (not pushed yet)"
    fi
    ws_say "$(printf '%-24s' "$r") $target: $state"

    # Local branches already contained in origin/<default>.
    for b in $(ws_git "$r" for-each-ref --format='%(refname:short)' refs/heads); do
        [[ "$b" == "$target" || "$b" == "$def" ]] && continue
        if ws_git "$r" merge-base --is-ancestor "$b" "origin/$def" 2>/dev/null; then
            if [[ "$PRUNE" -eq 1 ]]; then
                ws_git "$r" branch -d -q "$b" 2>/dev/null \
                    && ws_say "$(printf '%-24s' '') deleted merged branch $b"
            else
                ws_say "$(printf '%-24s' '') merged, can delete: $b  (--prune-merged)"
            fi
        fi
    done
done
exit "$skipped"
