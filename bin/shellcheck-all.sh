#!/usr/bin/env bash
# bin/shellcheck-all.sh — shellcheck wrapper for the sibling repos.
#
# Runs shellcheck across every appliance's main scripts, prepare-image
# scripts, lab scenarios, lab tooling, and tests. Excludes a small,
# documented list of warnings that are noise rather than signal in this
# project's idioms (see EXCLUDE below).
#
# Behavior:
#   - shellcheck installed → run, print findings, exit 0 (advisory mode
#     by default) or non-zero in --strict mode.
#   - shellcheck NOT installed → print a one-line note and exit 0. This
#     keeps preflight green on machines without shellcheck installed
#     (e.g. minimal CI containers); the wrapper is a quality gate, not
#     a blocking dependency.
#
# Flags:
#   --strict      Exit non-zero if shellcheck finds anything at the
#                 configured severity (warning) or higher. Default is
#                 advisory: report and exit 0.
#   --severity=L  Override the severity floor. Default 'warning'. Set
#                 to 'info' to surface SC1xxx/SC2xxx info-level lines.
#   --files-only  List the files that would be checked and exit. Useful
#                 when adding a new entry to the FILES list below.
#   -h, --help    This message.
#
# Each excluded SC code carries a one-line rationale below. To add or
# drop one, edit EXCLUDE and explain the choice in the comment block.
#
# Sourced lab scenario files carry `# shellcheck shell=bash` on line 1
# so shellcheck doesn't fall back to sh-mode (which is more strict and
# would flag bash idioms). New scenarios MUST include the directive;
# the wrapper does not infer it.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"          # dev-commons
PARENT_DIR="$(cd "$REPO_DIR/.." && pwd)"          # sibling-layout root

if [[ -t 1 ]]; then
    BOLD=$'\033[1m'; RST=$'\033[0m'
    GREEN=$'\033[32m'; RED=$'\033[31m'; DIM=$'\033[2m'
else
    BOLD=''; RST=''; GREEN=''; RED=''; DIM=''
fi

#------------------------------------------------------------------
# Exclusion list. Each entry has a one-line rationale.
#------------------------------------------------------------------
# SC1090 — "ShellCheck can't follow non-constant source" — same root
#          cause as SC1091; fires when the source path is a variable
#          (e.g. `source "$SYSVOL_SYNC_CONF"`). Adding this with a
#          # shellcheck source=... directive per call site is doable
#          but yields no signal in this codebase (the runtime conf
#          files live outside the source tree). Excluded globally.
# SC1091 — "Not following: ./<file>" — sourced paths shellcheck cannot
#          statically resolve. The lab scripts source vendored
#          appliance-core libs from runtime paths (/usr/local/lib/...)
#          and sibling-relative scenario files via $(dirname BASH_SOURCE).
#          Pure static-analysis limitation, not a code-quality issue.
# SC2034 — "var appears unused" — the lab framework uses dynamic-scope
#          sourcing extensively: scenario files set SC_* globals that
#          sourced helpers consume, and load_share() populates state
#          variables used by code in another file. shellcheck can't
#          follow that and false-positives heavily. Real "unused
#          local" cases get flagged on individual functions when the
#          variable is local-scoped, which this exclusion does not
#          suppress (the warning shape differs).
EXCLUDE='SC1090,SC1091,SC2034'

#------------------------------------------------------------------
# File list. Globs and individual paths both work; missing files are
# silently skipped (so the wrapper is robust to a partial sibling
# checkout).
#------------------------------------------------------------------
declare -a CANDIDATES=(
    # dev-commons tooling
    "dev-commons/bin/sanity-check.sh"
    "dev-commons/bin/preflight.sh"
    "dev-commons/bin/shellcheck-all.sh"
    "dev-commons/bin/sibling-status.sh"
    "dev-commons/bin/find-fixmes.sh"
    "dev-commons/bin/check-dangerous-cmds.sh"
    "dev-commons/bin/new-appliance.sh"

    # appliance-core
    "appliance-core/prepare-image.sh"
    "appliance-core/core-sconfig.sh"
    "appliance-core/bin/compliance-check.sh"
    "appliance-core/lib/detect-net.sh"
    "appliance-core/lib/identity.sh"
    "appliance-core/lib/tui.sh"
    "appliance-core/lib/hostname.sh"
    "appliance-core/lib/apt-helpers.sh"
    "appliance-core/lib/netconfig.sh"

    # samba-addc
    "samba-addc-appliance/prepare-image.sh"
    "samba-addc-appliance/samba-sconfig.sh"
    "samba-addc-appliance/lab/build-fresh-base.sh"
    "samba-addc-appliance/lab/stage-samba-base.sh"
    "samba-addc-appliance/lab/export-deploy-master.sh"
    "samba-addc-appliance/lab/run-scenario.sh"
    "samba-addc-appliance/tests/compliance.sh"

    # smb-proxy
    "smb-proxy-appliance/prepare-image.sh"
    "smb-proxy-appliance/smbproxy-sconfig.sh"
    "smb-proxy-appliance/smbproxy-probe-backend"
    "smb-proxy-appliance/lab/build-fresh-base.sh"
    "smb-proxy-appliance/lab/stage-proxy-base.sh"
    "smb-proxy-appliance/lab/export-deploy-master.sh"
    "smb-proxy-appliance/lab/run-scenario.sh"
    "smb-proxy-appliance/tests/unit-helpers.sh"
    "smb-proxy-appliance/tests/compliance.sh"
)

# Glob-expanded entries: scenarios from both appliances. Globs are
# expanded inside the function so PARENT_DIR is honored.
collect_scenarios() {
    local d
    for d in samba-addc-appliance smb-proxy-appliance; do
        local scenarios_dir="$PARENT_DIR/$d/lab/scenarios"
        [[ -d "$scenarios_dir" ]] || continue
        local f
        for f in "$scenarios_dir"/*.sh; do
            [[ -f "$f" ]] && printf '%s\n' "${f#"$PARENT_DIR/"}"
        done
    done
}

#------------------------------------------------------------------
# Argument parsing.
#------------------------------------------------------------------
STRICT=0
SEVERITY='warning'
FILES_ONLY=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --strict)        STRICT=1; shift ;;
        --severity=*)    SEVERITY="${1#--severity=}"; shift ;;
        --files-only)    FILES_ONLY=1; shift ;;
        -h|--help)
            sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//; /^set -euo/d'
            exit 0
            ;;
        *)
            echo "shellcheck-all: unknown flag '$1'" >&2
            exit 2
            ;;
    esac
done

#------------------------------------------------------------------
# Resolve files to check.
#------------------------------------------------------------------
declare -a FILES=()
for entry in "${CANDIDATES[@]}"; do
    full="$PARENT_DIR/$entry"
    [[ -f "$full" ]] && FILES+=("$full")
done
while IFS= read -r rel; do
    full="$PARENT_DIR/$rel"
    [[ -f "$full" ]] && FILES+=("$full")
done < <(collect_scenarios)

if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "[shellcheck-all] no candidate files found under $PARENT_DIR"
    exit 0
fi

if [[ $FILES_ONLY -eq 1 ]]; then
    printf '%s\n' "${FILES[@]}"
    exit 0
fi

#------------------------------------------------------------------
# Run shellcheck (or skip with note).
#------------------------------------------------------------------
if ! command -v shellcheck >/dev/null 2>&1; then
    cat <<EOF
${BOLD}[shellcheck-all] shellcheck not installed; skipping.${RST}
  Install to enable static analysis on ${#FILES[@]} files:
    Mac:    brew install shellcheck
    Debian: sudo apt install shellcheck
  Configured exclusions: $EXCLUDE
EOF
    exit 0
fi

sc_version=$(shellcheck --version 2>/dev/null | awk '/^version:/ {print $2}')
printf '%s[shellcheck-all]%s shellcheck %s on %d files (severity=%s, exclude=%s)\n' \
    "$BOLD" "$RST" "${sc_version:-?}" "${#FILES[@]}" "$SEVERITY" "$EXCLUDE"

# -x follows external sources where it can; combined with the per-file
# `# shellcheck shell=bash` directive in scenarios, this gives the
# best-quality analysis without blowing up on legitimate dynamic sourcing.
set +e
shellcheck \
    --shell=bash \
    --severity="$SEVERITY" \
    --exclude="$EXCLUDE" \
    -x \
    "${FILES[@]}"
sc_rc=$?
set -e

if [[ $sc_rc -eq 0 ]]; then
    printf '%s[shellcheck-all]%s clean — no findings at severity=%s.\n' \
        "$GREEN" "$RST" "$SEVERITY"
    exit 0
fi

# Findings present.
if [[ $STRICT -eq 1 ]]; then
    printf '%s[shellcheck-all]%s findings present (rc=%d) — strict mode, failing.\n' \
        "$RED" "$RST" "$sc_rc" >&2
    exit "$sc_rc"
fi

printf '%s[shellcheck-all]%s findings present (rc=%d) — advisory mode, not failing preflight.\n' \
    "$DIM" "$RST" "$sc_rc"
printf '%s  fix incrementally; run with --strict once the count is zero.%s\n' "$DIM" "$RST"
exit 0
