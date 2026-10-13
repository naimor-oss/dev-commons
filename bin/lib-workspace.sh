# shellcheck shell=bash
# lib-workspace.sh — the one place that knows the sibling repos and the order
# to publish and merge them in. Sourced by ws-sync.sh, ws-publish.sh and
# ws-merge.sh. Bash 3.2 safe (macOS system bash): no associative arrays,
# no mapfile, no case-conversion expansions.
#
# Order = dependency direction, producer first (REPO-SPLIT.md "Dependency
# Direction"): lab-kit and lab-router have no upstream deps, appliance-core
# consumes both, the two appliances consume appliance-core (and the proxy
# consumes smbproxy-session-vfs). dev-commons goes first because the shared
# CI workflow and the shellcheck/preflight gate live there.
#
# wine and wine-webapp are deliberately not in the list.
#
# Overrides: WS_PARENT_DIR (directory holding the sibling checkouts),
# WS_ORG (GitHub organisation).

WS_ORG="${WS_ORG:-naimor-oss}"
WS_ORDER=(dev-commons lab-kit lab-router appliance-core smbproxy-session-vfs
          samba-addc-appliance smb-proxy-appliance)

ws_say() { printf '%s\n' "$*"; }
ws_die() { printf 'error: %s\n' "$*" >&2; exit 2; }

# Siblings that exist as git checkouts, in dependency order.
ws_repos() {
    local r
    for r in "${WS_ORDER[@]}"; do
        [[ -d "$WS_PARENT_DIR/$r/.git" ]] && printf '%s\n' "$r"
    done
    return 0
}

# ws_git REPO ARGS...   (never uses the current directory)
ws_git() { local r="$1"; shift; git -C "$WS_PARENT_DIR/$r" "$@"; }

ws_dirty() { [[ -n "$(ws_git "$1" status --porcelain 2>/dev/null)" ]]; }

ws_default_branch() {
    local b
    b=$(ws_git "$1" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null) || b=""
    b="${b#origin/}"
    printf '%s\n' "${b:-main}"
}

ws_branch_local()  { ws_git "$1" show-ref --verify --quiet "refs/heads/$2"; }
ws_branch_remote() { ws_git "$1" show-ref --verify --quiet "refs/remotes/origin/$2"; }
ws_branch_exists() { ws_branch_local "$1" "$2" || ws_branch_remote "$1" "$2"; }

# Commits on BRANCH (local, else origin) that are not on origin/<default>.
ws_commits_beyond_default() {
    local r="$1" b="$2" def ref
    def=$(ws_default_branch "$r" | head -1)
    if ws_branch_local "$r" "$b"; then ref="$b"; else ref="origin/$b"; fi
    ws_git "$r" rev-list --count "origin/$def..$ref" 2>/dev/null || echo 0
}

# GitHub: can the active gh account push to ORG/REPO? (A read-only account
# fails later, at PR creation, with "must be a collaborator".)
ws_gh_can_push() {
    [[ "$(gh api "repos/$WS_ORG/$1" --jq .permissions.push 2>/dev/null)" == "true" ]]
}

ws_gh_account() { gh api user --jq .login 2>/dev/null; }

ws_open_pr_number() {
    gh pr list -R "$WS_ORG/$1" --head "$2" --state open --json number \
        --jq '.[0].number // empty' 2>/dev/null
}

ws_parse_common() {  # sets WS_PARENT_DIR default; caller passes script dir
    WS_PARENT_DIR="${WS_PARENT_DIR:-$(cd "$1/../.." && pwd)}"
}
