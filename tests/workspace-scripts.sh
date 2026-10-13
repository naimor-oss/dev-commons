#!/usr/bin/env bash
# bin/ws-sync.sh, ws-publish.sh, ws-merge.sh against throwaway repositories
# (bare remotes in a temp dir) and a fake `gh`. Nothing touches GitHub.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HERE/../bin"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
PASS=0 FAIL=0
check() {
    if [[ "$2" == "$3" ]]; then PASS=$((PASS + 1)); else
        FAIL=$((FAIL + 1)); printf 'FAIL  %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"; fi
}
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

P="$T/ws"; R="$T/remotes"; mkdir -p "$P" "$R"
# Three of the real names, created in a shuffled order to prove the order
# comes from the list and not from the directory listing.
for r in appliance-core dev-commons lab-kit; do
    git init -q --bare -b main "$R/$r.git"
    git init -q -b main "$P/$r"
    git -C "$P/$r" remote add origin "$R/$r.git"
    echo a > "$P/$r/f"; git -C "$P/$r" add f; git -C "$P/$r" commit -q -m init
    git -C "$P/$r" push -q -u origin main
    git -C "$P/$r" remote set-head origin main >/dev/null 2>&1
done
# A non-sibling directory must be ignored.
git init -q -b main "$P/wine"

# --- fake gh: logs calls; PR state comes from files under $T/gh ------------
mkdir -p "$T/gh" "$T/fakebin"
cat > "$T/fakebin/gh" <<'EOF'
#!/usr/bin/env bash
echo "gh $*" >> "$GHLOG"
case "$1 $2" in
    "api user")   echo tester ;;
    "api repos/"*) echo true ;;
    "pr list")    repo=${4#*/}; cat "$GHSTATE/$repo.pr" 2>/dev/null ;;
    "pr create")  echo "https://example/pr/1" ;;
    "pr checks")  repo=${5#*/}; [[ "$(cat "$GHSTATE/$repo.checks" 2>/dev/null)" == red ]] && exit 1; exit 0 ;;
    "pr merge")   exit 0 ;;
esac
EOF
chmod +x "$T/fakebin/gh"
export PATH="$T/fakebin:$PATH" GHLOG="$T/ghlog" GHSTATE="$T/gh"

# --- ws-publish: order, skip rules, plan-only ------------------------------
for r in lab-kit appliance-core; do
    git -C "$P/$r" checkout -q -b feat/x
    echo b > "$P/$r/g"; git -C "$P/$r" add g; git -C "$P/$r" commit -q -m "feat $r"
done
git -C "$P/dev-commons" checkout -q -b feat/x     # branch with nothing new

out=$("$BIN/ws-publish.sh" feat/x -d "$P" 2>&1)
check "publish plan lists producer first" "1. lab-kit (1 commit(s))|2. appliance-core (1 commit(s))" \
    "$(printf '%s\n' "$out" | grep -E '^ +[0-9]\.' | sed 's/^ *//' | tr '\n' '|' | sed 's/|$//')"
check "publish plan skips a branch with nothing new" yes \
    "$(printf '%s' "$out" | grep -q 'skip dev-commons' && echo yes || echo no)"
check "plan-only pushes nothing" no \
    "$(git -C "$R/lab-kit.git" show-ref --verify --quiet refs/heads/feat/x && echo yes || echo no)"

"$BIN/ws-publish.sh" feat/x -d "$P" --yes >/dev/null 2>&1
check "--yes pushes the branch" yes \
    "$(git -C "$R/lab-kit.git" show-ref --verify --quiet refs/heads/feat/x && echo yes || echo no)"
check "--yes does not push a branch with nothing new" no \
    "$(git -C "$R/dev-commons.git" show-ref --verify --quiet refs/heads/feat/x && echo yes || echo no)"

echo dirty > "$P/lab-kit/f"
"$BIN/ws-publish.sh" feat/x -d "$P" --yes >/dev/null 2>&1; rc=$?
check "a dirty tree on the branch is refused" 2 "$rc"
git -C "$P/lab-kit" checkout -q -- f

: > "$GHLOG"
"$BIN/ws-publish.sh" feat/x -d "$P" --yes --pr >/dev/null 2>&1
check "--pr opens PRs in dependency order" "lab-kit|appliance-core" \
    "$(grep '^gh pr create' "$GHLOG" | sed -E 's/.*-R [^/]+\/([^ ]+) .*/\1/' | tr '\n' '|' | sed 's/|$//')"
check "--pr targets the default branch" yes \
    "$(grep '^gh pr create' "$GHLOG" | grep -q -- '--base main' && echo yes || echo no)"

# --- ws-merge: order, stop on red, --allow-red ------------------------------
echo 5 > "$GHSTATE/lab-kit.pr"; echo 7 > "$GHSTATE/appliance-core.pr"
: > "$GHLOG"
out=$("$BIN/ws-merge.sh" feat/x -d "$P" 2>&1)
check "merge plan is producer first" "1. naimor-oss/lab-kit#5|2. naimor-oss/appliance-core#7" \
    "$(printf '%s\n' "$out" | grep -E '^ +[0-9]\.' | sed 's/^ *//' | tr '\n' '|' | sed 's/|$//')"
check "merge plan merges nothing" 0 "$(grep -c '^gh pr merge' "$GHLOG")"

echo red > "$GHSTATE/lab-kit.checks"
: > "$GHLOG"
"$BIN/ws-merge.sh" feat/x -d "$P" --yes >/dev/null 2>&1; rc=$?
check "a red check stops the run with rc 1" 1 "$rc"
check "nothing is merged after a red check" 0 "$(grep -c '^gh pr merge' "$GHLOG")"

: > "$GHLOG"
"$BIN/ws-merge.sh" feat/x -d "$P" --yes --allow-red >/dev/null 2>&1; rc=$?
check "--allow-red merges through, in order" "5|7" \
    "$(grep '^gh pr merge' "$GHLOG" | awk '{print $4}' | tr '\n' '|' | sed 's/|$//')"

# --- ws-sync -----------------------------------------------------------------
# Simulate the merges having happened on the remotes.
for r in lab-kit appliance-core; do
    git -C "$P/$r" fetch -q origin
    git -C "$P/$r" push -q origin feat/x:main 2>/dev/null
done
out=$("$BIN/ws-sync.sh" -d "$P" 2>&1); rc=$?
check "sync returns every repo to main" "main|main|main" \
    "$(for r in dev-commons lab-kit appliance-core; do git -C "$P/$r" branch --show-current; done | tr '\n' '|' | sed 's/|$//')"
check "sync fast-forwards main to the merged work" yes \
    "$([[ -f "$P/appliance-core/g" ]] && echo yes || echo no)"
check "sync reports merged branches without deleting" yes \
    "$(printf '%s' "$out" | grep -q 'merged, can delete: feat/x' && echo yes || echo no)"
check "sync rc 0 when everything is clean" 0 "$rc"

"$BIN/ws-sync.sh" -d "$P" --prune-merged >/dev/null 2>&1
check "--prune-merged deletes merged local branches" no \
    "$(git -C "$P/lab-kit" show-ref --verify --quiet refs/heads/feat/x && echo yes || echo no)"

echo wip > "$P/lab-kit/f"
out=$("$BIN/ws-sync.sh" -d "$P" 2>&1); rc=$?
check "a dirty repo is skipped and rc is 1" "1|yes" \
    "$rc|$(printf '%s' "$out" | grep -q 'lab-kit .*dirty' && echo yes || echo no)"
check "dirty files are untouched" wip "$(cat "$P/lab-kit/f")"
git -C "$P/lab-kit" checkout -q -- f

git -C "$P/lab-kit" commit -q --allow-empty -m "local only"
git clone -q "$R/lab-kit.git" "$T/other"
git -C "$T/other" commit -q --allow-empty -m "remote only"
git -C "$T/other" push -q origin main
out=$("$BIN/ws-sync.sh" -d "$P" 2>&1); rc=$?
check "a diverged main is reported and rc is 1" "1|yes" \
    "$rc|$(printf '%s' "$out" | grep -q 'DIVERGED' && echo yes || echo no)"
check "a diverged main is not rewritten" "local only" "$(git -C "$P/lab-kit" log -1 --format=%s)"

check "wine (not a sibling in the list) is ignored" no \
    "$("$BIN/ws-sync.sh" -d "$P" 2>&1 | grep -q '^wine' && echo yes || echo no)"

echo "summary: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
