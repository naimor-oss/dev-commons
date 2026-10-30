#!/usr/bin/env bash
# bin/root-suite-gate.sh against a throwaway sibling layout: which pull
# requests owe a local root-suite run, and when the description settles it.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$HERE/../bin/root-suite-gate.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
PASS=0 FAIL=0
check() {
    if [[ "$2" == "$3" ]]; then PASS=$((PASS + 1)); else
        FAIL=$((FAIL + 1)); printf 'FAIL  %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"; fi
}
# gate <repo> <changed paths, space-separated> <description>: prints the exit status.
gate() {
    tr ' ' '\n' <<< "$2" > "$T/changed"
    printf '%s\n' "$3" > "$T/body"
    "$GATE" "$T/ws" "$1" "$T/changed" "$T/body" > "$T/out" 2>&1
    echo $?
}

# An appliance with a root suite that copies ../core, plus an unrelated repo.
mkdir -p "$T/ws/appliance/tests/root" "$T/ws/core/lib" "$T/ws/other"
# shellcheck disable=SC2016  # the suite body is literal
printf '#!/bin/bash\ncp -a "$SRC/../core" "$T/core"\n' > "$T/ws/appliance/tests/root/a.sh"
OK='Validation: root integration suites run: 4, failed: 0'

check "suite owner, code change, no line"   1 "$(gate appliance 'lib/x.sh' 'no run here')"
grep -q '::error::.*lib/x.sh' "$T/out"; check "error names the file" 0 $?
check "suite owner, code change, line"      0 "$(gate appliance 'lib/x.sh README.md' "$OK")"
check "a failed run doesn't count"          1 "$(gate appliance 'lib/x.sh' 'root integration suites run: 4, failed: 1')"
check "zero suites run doesn't count"       1 "$(gate appliance 'lib/x.sh' 'root integration suites run: 0, failed: 0')"
check "suite owner, docs only"              0 "$(gate appliance 'README.md docs/a.txt LICENSE' 'none')"
check "sibling a suite copies, code change" 1 "$(gate core 'lib/kv.sh' 'none')"
check "sibling a suite copies, with line"   0 "$(gate core 'lib/kv.sh' "$OK")"
check "repo no suite names"                 0 "$(gate other 'bin/x.sh' 'none')"
check "a name that only starts the same"    0 "$(gate cor 'x.sh' 'none')"
check "wrong argument count"                2 "$("$GATE" a b >/dev/null 2>&1; echo $?)"

echo "root-suite-gate: $PASS passed, $FAIL failed"
((FAIL == 0))
