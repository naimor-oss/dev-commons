#!/usr/bin/env bash
# Claude Code PreToolUse hook — blocks force-push and rm -rf on unsafe targets.
# Claude Code passes the tool call input as JSON on stdin.
# Exit non-zero to block the tool call; stderr is shown as the reason.
set -uo pipefail

cmd=$(python3 -c "import sys, json; print(json.load(sys.stdin).get('command', ''))" 2>/dev/null || true)

# Force-push to a remote always requires explicit user approval first.
if printf '%s\n' "$cmd" | grep -qE 'git\s+push.+(--force\b|-f\b)'; then
    printf 'Hook blocked: git push --force requires explicit user approval.\n' >&2
    exit 2
fi

# rm -rf on root paths or parent-directory traversal is never safe without review.
if printf '%s\n' "$cmd" | grep -qE '\brm\s+(-rf|-fr|-r\s+-f|-f\s+-r)\s+(/|\.\.)'; then
    printf 'Hook blocked: rm -rf on root or parent path requires explicit user approval.\n' >&2
    exit 2
fi
