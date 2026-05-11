#!/usr/bin/env bash
# dev-commons/bin/new-appliance.sh
#
# Scaffold a new appliance repo from
# dev-commons/template-appliance-virtualized/. Replaces the
# <APPLIANCE-*> placeholders with operator-supplied values, renames
# the placeholder-named sconfig file, drops the INSTANTIATE.md crumb,
# initializes git, and runs the compliance checker to confirm the
# resulting tree passes day-one.
#
# Usage:
#   dev-commons/bin/new-appliance.sh \
#       --name foo-appliance \
#       --short foo \
#       --title "Foo Appliance" \
#       --purpose "One-line purpose."
#
# Flags:
#   --name N        Repo / directory name (lowercase-hyphenated;
#                   convention: ends in '-appliance').
#   --short S       Short script-prefix (lowercase, no hyphens).
#                   Will become 'foo-sconfig' etc.
#   --title T       Human-readable title.
#   --purpose P     One-line purpose sentence (appears in README +
#                   AGENTS.md).
#   --parent DIR    Where to create the new appliance repo. Default
#                   is the sibling layout parent (one level above
#                   dev-commons), matching the documented checkout
#                   shape.
#   --force         Overwrite the destination if it already exists.
#                   Refuses without this flag.
#   --no-git        Skip 'git init' + initial commit.
#   --no-check      Skip the post-scaffold compliance check.
#   -h, --help      This usage.
#
# Missing required flags trigger interactive prompts. Run with no
# args to walk through the wizard.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"          # dev-commons
PARENT_DEFAULT="$(cd "$REPO_DIR/.." && pwd)"      # sibling layout root
TEMPLATE_DIR="$REPO_DIR/template-appliance-virtualized"
COMPLIANCE_CHECKER="$PARENT_DEFAULT/appliance-core/bin/compliance-check.sh"

if [[ -t 1 ]]; then
    BOLD=$'\033[1m'; RST=$'\033[0m'
    GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; DIM=$'\033[2m'
else
    BOLD=''; RST=''; GREEN=''; YELLOW=''; RED=''; DIM=''
fi

step() { printf '\n%s== %s ==%s\n' "$BOLD" "$1" "$RST"; }
note() { printf '%s%s%s\n' "$DIM" "$*" "$RST"; }
warn() { printf '%sWARN%s %s\n' "$YELLOW" "$RST" "$*" >&2; }
fail() { printf '%sFAIL%s %s\n' "$RED" "$RST" "$*" >&2; exit 1; }
done_() { printf '%sDONE%s %s\n' "$GREEN" "$RST" "$*"; }

usage() {
    sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//; /^set -euo/d'
}

# Prompt for a value when the flag was not supplied. Validates via the
# supplied regex; re-prompts on failure.
prompt_if_unset() {
    local var_name="$1" question="$2" example="$3" pattern="$4"
    local cur="${!var_name:-}"
    while [[ -z "$cur" ]] || ! [[ "$cur" =~ $pattern ]]; do
        if [[ -n "$cur" ]]; then
            printf '%sInvalid: %s does not match expected shape.%s\n' "$RED" "$cur" "$RST"
        fi
        printf '%s\n  example: %s\n  > ' "$question" "$example"
        read -r cur || cur=""
    done
    printf -v "$var_name" '%s' "$cur"
}

# ----------------------------------------------------------------------------
# Argument parsing.
# ----------------------------------------------------------------------------

APPLIANCE_NAME=""
APPLIANCE_SHORT=""
APPLIANCE_TITLE=""
APPLIANCE_PURPOSE=""
PARENT_DIR="$PARENT_DEFAULT"
FORCE=0
DO_GIT=1
DO_CHECK=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)     APPLIANCE_NAME="$2";    shift 2 ;;
        --short)    APPLIANCE_SHORT="$2";   shift 2 ;;
        --title)    APPLIANCE_TITLE="$2";   shift 2 ;;
        --purpose)  APPLIANCE_PURPOSE="$2"; shift 2 ;;
        --parent)   PARENT_DIR="$2";        shift 2 ;;
        --force)    FORCE=1; shift ;;
        --no-git)   DO_GIT=0; shift ;;
        --no-check) DO_CHECK=0; shift ;;
        -h|--help)  usage; exit 0 ;;
        *)          echo "new-appliance: unknown flag '$1'" >&2; usage >&2; exit 2 ;;
    esac
done

step "0. inputs"

# Validate / collect each.
prompt_if_unset APPLIANCE_NAME \
    "Repo / directory name (lowercase-hyphenated; convention: ends in '-appliance'):" \
    "smb-proxy-appliance" \
    '^[a-z][a-z0-9-]+$'

prompt_if_unset APPLIANCE_SHORT \
    "Short script-prefix (lowercase, no hyphens, used in sconfig/firstboot names):" \
    "smbproxy" \
    '^[a-z][a-z0-9]+$'

prompt_if_unset APPLIANCE_TITLE \
    "Human-readable title:" \
    "SMB1<->SMB3 Proxy Appliance" \
    '.+'

prompt_if_unset APPLIANCE_PURPOSE \
    "One-line purpose sentence:" \
    "Front a legacy SMB1 file server as a modern AD-joined SMB3 share." \
    '.+'

printf '\n  name:    %s\n' "$APPLIANCE_NAME"
printf '  short:   %s\n' "$APPLIANCE_SHORT"
printf '  title:   %s\n' "$APPLIANCE_TITLE"
printf '  purpose: %s\n' "$APPLIANCE_PURPOSE"
printf '  parent:  %s\n' "$PARENT_DIR"

DEST="$PARENT_DIR/$APPLIANCE_NAME"

# ----------------------------------------------------------------------------
# Pre-flight: template + destination.
# ----------------------------------------------------------------------------

[[ -d "$TEMPLATE_DIR" ]] || fail "template not found: $TEMPLATE_DIR"
[[ -d "$PARENT_DIR"   ]] || fail "parent dir not found: $PARENT_DIR"

if [[ -e "$DEST" ]]; then
    if [[ $FORCE -eq 1 ]]; then
        warn "destination exists, removing: $DEST"
        rm -rf "$DEST"
    else
        fail "destination exists: $DEST   (pass --force to overwrite)"
    fi
fi

# ----------------------------------------------------------------------------
# Step 1: copy template.
# ----------------------------------------------------------------------------

step "1. copy template -> $DEST"
cp -R "$TEMPLATE_DIR" "$DEST"
# Drop INSTANTIATE.md — this wizard supersedes its manual steps.
rm -f "$DEST/INSTANTIATE.md"
done_ "copied"

# ----------------------------------------------------------------------------
# Step 2: rename the placeholder-named sconfig.
# ----------------------------------------------------------------------------

step "2. rename placeholder sconfig"
mv "$DEST/APPLIANCE-SHORT-sconfig.sh" "$DEST/${APPLIANCE_SHORT}-sconfig.sh"
# lab env file shares the prefix.
if [[ -f "$DEST/lab/APPLIANCE-SHORT.env" ]]; then
    mv "$DEST/lab/APPLIANCE-SHORT.env" "$DEST/lab/${APPLIANCE_SHORT}.env"
fi
done_ "renamed to ${APPLIANCE_SHORT}-sconfig.sh"

# ----------------------------------------------------------------------------
# Step 3: find-and-replace placeholders.
# ----------------------------------------------------------------------------

step "3. substitute placeholders"
# Use perl for portable in-place edit (BSD sed -i requires '' empty
# arg; GNU sed -i accepts no arg; perl works everywhere).
find "$DEST" -type f \
    \( -name '*.sh' -o -name '*.md' -o -name '*.env' -o -name '.gitignore' \) \
    -print0 \
    | while IFS= read -r -d '' f; do
        perl -i -pe '
            s/<APPLIANCE-NAME>/'"$APPLIANCE_NAME"'/g;
            s/<APPLIANCE-SHORT>/'"$APPLIANCE_SHORT"'/g;
            s/<APPLIANCE-TITLE>/'"$APPLIANCE_TITLE"'/g;
            s/<APPLIANCE-PURPOSE>/'"$APPLIANCE_PURPOSE"'/g;
        ' "$f"
    done

# Sanity: no <APPLIANCE-*> remains anywhere in the tree.
remaining=$(grep -rlE '<APPLIANCE-(NAME|SHORT|TITLE|PURPOSE)>' "$DEST" 2>/dev/null || true)
if [[ -n "$remaining" ]]; then
    warn "some placeholders remain after substitution:"
    printf '  %s\n' $remaining >&2
    fail "substitution incomplete"
fi
done_ "placeholders replaced everywhere"

# ----------------------------------------------------------------------------
# Step 3b: drop the tests/compliance.sh invoker so the new appliance
# has a one-line way to re-run compliance from day one.
# ----------------------------------------------------------------------------

step "3b. install tests/compliance.sh invoker"
install -d -m 0755 "$DEST/tests"
cat > "$DEST/tests/compliance.sh" <<'INVOKER_EOF'
#!/usr/bin/env bash
# tests/compliance.sh — invoke appliance-core's compliance checker
# against this appliance.
#
# Runs from any CWD. Picks the sibling appliance-core checkout (the
# documented layout per dev-commons/REPO-SPLIT.md). Skips with a clear
# message when appliance-core is not checked out next to this repo —
# the checker is a build-time gate, not a runtime dependency.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPDIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECKER="$APPDIR/../appliance-core/bin/compliance-check.sh"

if [[ ! -x "$CHECKER" ]]; then
    echo "[compliance] appliance-core/bin/compliance-check.sh not found at:" >&2
    echo "             $CHECKER" >&2
    echo "             Check out appliance-core as a sibling of this repo." >&2
    exit 0
fi

exec "$CHECKER" "$@" "$APPDIR"
INVOKER_EOF
chmod +x "$DEST/tests/compliance.sh"
done_ "tests/compliance.sh installed"

# ----------------------------------------------------------------------------
# Step 4: initial git commit.
# ----------------------------------------------------------------------------

if [[ $DO_GIT -eq 1 ]]; then
    step "4. git init"
    (
        cd "$DEST"
        git init -q -b main
        git add -A
        # GIT_AUTHOR_NAME may be unset in CI; provide a fallback so the
        # initial commit doesn't fail. Operators can amend or rebase
        # later as needed.
        git \
            -c "user.name=${GIT_COMMITTER_NAME:-${GIT_AUTHOR_NAME:-Appliance Maintainer}}" \
            -c "user.email=${GIT_COMMITTER_EMAIL:-${GIT_AUTHOR_EMAIL:-maintainer@example.invalid}}" \
            commit -q -m "Initial commit: scaffold ${APPLIANCE_NAME} from template-appliance-virtualized"
    )
    done_ "git initialized + initial commit"
else
    note "step 4 skipped (--no-git)"
fi

# ----------------------------------------------------------------------------
# Step 5: compliance check.
# ----------------------------------------------------------------------------

if [[ $DO_CHECK -eq 1 ]]; then
    step "5. compliance check (day-one)"
    if [[ -x "$COMPLIANCE_CHECKER" ]]; then
        # The brand-new scaffold WILL fail some checks today because
        # the template carries no real DOMAIN\Group surface, but
        # might be missing other contracts an operator would expect.
        # Run --report so the operator sees the full surface.
        if "$COMPLIANCE_CHECKER" --report "$DEST"; then
            done_ "scaffold passes appliance-core compliance"
        else
            warn "scaffold has compliance gaps — review the FAIL lines above"
            warn "(this is expected for a fresh skeleton; close them as you flesh it out)"
        fi
    else
        note "appliance-core/bin/compliance-check.sh not found at $COMPLIANCE_CHECKER; skipping"
    fi
else
    note "step 5 skipped (--no-check)"
fi

# ----------------------------------------------------------------------------
# Summary.
# ----------------------------------------------------------------------------

_editor="${EDITOR:-\$EDITOR}"
cat <<NEXT

$BOLD
Next steps:
$RST
  cd $DEST
  $_editor ${APPLIANCE_SHORT}-sconfig.sh   # flesh out the appliance
  $_editor prepare-image.sh                # add packages, MOTD, etc.
  tests/compliance.sh --report             # re-check after each batch
  ../dev-commons/bin/preflight.sh          # full preflight (when wired in)

Reference appliances:
  ../samba-addc-appliance/  — full AD DC + DFS-N example
  ../smb-proxy-appliance/   — SMB1<->SMB3 proxy example
NEXT
