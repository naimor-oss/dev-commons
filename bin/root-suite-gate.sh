#!/usr/bin/env bash
# bin/root-suite-gate.sh — does this pull request owe a local root-suite run?
#
# GitHub's preflight doesn't run tests/root/*.sh (decision 0003);
# bin/root-tests.sh does, on a machine with Docker. So a pull request
# whose change a root suite exercises must state that run's summary line,
# with no failures, in its description:
#
#   root integration suites run: N, failed: 0
#
#   bin/root-suite-gate.sh <workspace-dir> <repo> <changed-files> <pr-body>
#
# <changed-files> holds the pull request's paths, one per line, relative to
# <repo>; <pr-body> holds its description. A change counts when <repo> has
# root suites, or a root suite names it as a sibling (../<repo>, as the
# update-bundle suites copy ../appliance-core), and it touches anything but
# documentation (*.md, docs/, LICENSE). Exit 0 when nothing is owed or the
# line is there, 1 when it's owed and missing.

set -euo pipefail
shopt -s nullglob

(($# == 4)) || { sed -n '2,/^set -euo/{/^set -euo/d;s/^# \{0,1\}//;p}' "$0" >&2; exit 2; }
ws=$1 repo=$2 changed=$3 body=$4

suites=("$ws"/*/tests/root/*.sh)
covered=0
for s in "${suites[@]}"; do
    owner=${s#"$ws"/}; owner=${owner%%/*}
    if [[ $owner == "$repo" ]] || grep -qE "\.\./$repo([/\"' ]|$)" "$s"; then
        covered=1
        break
    fi
done
if ((!covered)); then
    echo "root suites: none exercise $repo"
    exit 0
fi

code=()
while IFS= read -r f; do
    [[ -n $f ]] || continue
    case $f in
        *.md | docs/* | LICENSE) ;;
        *) code+=("$f") ;;
    esac
done < "$changed"
if ((${#code[@]} == 0)); then
    echo "root suites: only documentation changed in $repo"
    exit 0
fi

if grep -qE 'root integration suites run: [1-9][0-9]*, failed: 0' "$body"; then
    echo "root suites: the description states a passing local run"
    exit 0
fi
echo "::error::This change touches code the root suites exercise (${code[0]}$( ((${#code[@]} > 1)) && echo " and $((${#code[@]} - 1)) more")), but the description has no passing run. Run dev-commons/bin/root-tests.sh on a machine with Docker, put its last line (root integration suites run: N, failed: 0) in the description, then re-run this job."
exit 1
