# How to instantiate this template into a new appliance repo

**Use the wizard:**

```bash
dev-commons/bin/new-appliance.sh \
    --name <APPLIANCE-NAME> \
    --short <APPLIANCE-SHORT> \
    --title "<APPLIANCE-TITLE>" \
    --purpose "<one-line purpose>"
```

Or run it with no arguments to walk through interactive prompts.

The wizard:

1. Copies the template tree to `../<APPLIANCE-NAME>/` (sibling layout).
2. Renames the placeholder-named sconfig to `<APPLIANCE-SHORT>-sconfig.sh`.
3. Substitutes every `<APPLIANCE-*>` placeholder via portable in-place edit.
4. Installs `tests/compliance.sh` so the new repo can re-check itself.
5. Initializes git + makes an initial commit (skip with `--no-git`).
6. Runs `appliance-core/bin/compliance-check.sh` against the result;
   reports PASS/FAIL per check.

The fresh scaffold passes all 10 appliance-core compliance checks
on day one (template was made compliance-clean specifically so this
holds). Close any FAILs that surface as you flesh the appliance
out — the checker is the contract between this appliance and
`appliance-core`.

## Naming conventions

| Placeholder | Form | Example (proxy appliance) |
| --- | --- | --- |
| `<APPLIANCE-NAME>` | repo / directory name (lowercase-hyphenated) | `smb-proxy-appliance` |
| `<APPLIANCE-SHORT>` | short script-prefix (lowercase, no hyphens) | `smbproxy` |
| `<APPLIANCE-TITLE>` | human-readable name | `SMB1↔SMB3 Proxy Appliance` |
| `<APPLIANCE-PURPOSE>` | one-line purpose sentence | `Front a legacy SMB1 file server and re-publish it as a modern AD-joined SMB3 share, with strict locking enforced at the proxy.` |

- Names end in `-appliance` (`samba-addc-appliance`, `smb-proxy-appliance`).
- The script prefix matches the sconfig name: `samba-sconfig`,
  `smbproxy-sconfig`. Pick a prefix that reads naturally.

## Manual fallback

If you can't (or don't want to) use the wizard, the steps it
automates are:

```bash
# 1. Copy.
PARENT="$(cd "$DEV_COMMONS/.." && pwd)"
APPLIANCE_NAME="<APPLIANCE-NAME>"
cp -r "$DEV_COMMONS/template-appliance-virtualized" \
      "$PARENT/$APPLIANCE_NAME"
cd "$PARENT/$APPLIANCE_NAME"
rm INSTANTIATE.md

# 2. Rename the placeholder sconfig.
mv APPLIANCE-SHORT-sconfig.sh "${APPLIANCE_SHORT}-sconfig.sh"
mv lab/APPLIANCE-SHORT.env "lab/${APPLIANCE_SHORT}.env"

# 3. Replace placeholders.
find . -type f \( -name '*.sh' -o -name '*.md' -o -name '*.env' \) -print0 \
    | xargs -0 perl -i -pe \
        "s/<APPLIANCE-NAME>/${APPLIANCE_NAME}/g;
         s/<APPLIANCE-SHORT>/${APPLIANCE_SHORT}/g;
         s/<APPLIANCE-TITLE>/<your title>/g;
         s/<APPLIANCE-PURPOSE>/<your purpose>/g;"

# 4. Drop the tests/compliance.sh invoker (copy from any sibling).

# 5. git init + initial commit.

# 6. Check.
$PARENT/appliance-core/bin/compliance-check.sh --report .
```

## What the compliance checker enforces

Each compliance check guards against a specific bug class we've
actually seen in the field. Run `compliance-check.sh --list` for
the full table. Examples:

- **C01–C02** — appliance-core libs are actually vendored + sourced
  with sentinel guards (so an older image without a lib degrades
  gracefully).
- **C03** — no writes to `/etc/network/interfaces` (silently ignored
  on Debian 13).
- **C04–C05** — no hand-fixed `12×64` whiptail dimensions outside
  the documented fallback; `info()`/`yesno()`/`die()` delegate to
  `appcore_tui_msgbox`/`yesno`.
- **C06–C07** — DOMAIN\\Group input + hostname/realm changes go
  through appliance-core primitives rather than ad-hoc parsing /
  direct `/etc/hosts` writes.
- **C08** — `prepare-image.sh` records the appliance-core commit
  hash to `/etc/appliance-core.provenance`.
- **C09** — every sourced lab scenario carries `# shellcheck shell=bash`.
- **C10** — DFS-N consumers don't carry the well-known
  `Dfsn-Configuration` typo (the correct AD container name is
  `Dfs-Configuration`).
