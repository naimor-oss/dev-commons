# How to instantiate this template into a new appliance repo

This template carries the **shape** of a virtualized appliance: the
boilerplate files (AGENTS.md, README.md, CLAUDE.md, HANDOFF.md,
.gitignore), the appliance-script skeletons (`prepare-image.sh`,
`<appliance>-sconfig.sh`), and the lab harness wrapper. For larger
files where copy-and-adapt from an existing sibling is faster than
filling in a placeholder, this template points at the sibling rather
than duplicating its content.

## Step 1 — Pick names

You need three names:

| Placeholder | Form | Example (proxy appliance) |
| --- | --- | --- |
| `<APPLIANCE-NAME>` | repo / directory name (lowercase-hyphenated) | `smb-proxy-appliance` |
| `<APPLIANCE-SHORT>` | short script-prefix (lowercase, no hyphens) | `smbproxy` |
| `<APPLIANCE-TITLE>` | human-readable name | `SMB1↔SMB3 Proxy Appliance` |
| `<APPLIANCE-PURPOSE>` | one-line purpose sentence | `Front a legacy SMB1 file server with strict-locking SMB3 semantics for AD-joined clients.` |

Conventions in use today:

- Names end in `-appliance` (`samba-addc-appliance`, `smb-proxy-appliance`)
- The script prefix matches the sconfig name: `samba-sconfig`,
  `smbproxy-sconfig`. Pick a prefix that reads naturally.
- The title may use Unicode arrows or symbols where they help
  readability (e.g. `↔`); the README and AGENTS.md are both
  builder-facing and rendered in Markdown, so this is fine.

## Step 2 — Copy the template

```bash
PARENT="$(cd ../.. && pwd)"   # one level above dev-commons
APPLIANCE_NAME="<APPLIANCE-NAME>"
cp -r "$PARENT/dev-commons/template-appliance-virtualized" \
      "$PARENT/$APPLIANCE_NAME"
cd "$PARENT/$APPLIANCE_NAME"
rm INSTANTIATE.md   # this file doesn't belong in the new repo
```

## Step 3 — Rename the sconfig script

The template ships with a placeholder filename. Rename to match
your prefix:

```bash
mv APPLIANCE-SHORT-sconfig.sh "${APPLIANCE_SHORT:-changeme}-sconfig.sh"
```

## Step 4 — Find-and-replace the placeholders

Every placeholder in the template is in angle brackets so the search
is unambiguous:

```bash
git grep -n '<APPLIANCE-NAME>'
git grep -n '<APPLIANCE-SHORT>'
git grep -n '<APPLIANCE-TITLE>'
git grep -n '<APPLIANCE-PURPOSE>'
```

Replace each with the values you picked in Step 1. On macOS:

```bash
LC_ALL=C find . -type f \( -name '*.md' -o -name '*.sh' -o -name '*.tpl' \
                          -o -name '*.env' -o -name 'AGENTS.md' \
                          -o -name 'CLAUDE.md' -o -name 'HANDOFF.md' \
                          -o -name '.gitignore' \) \
    -exec sed -i '' "s|<APPLIANCE-NAME>|$APPLIANCE_NAME|g" {} +
# repeat for the other placeholders, OR run a single sed -e ... -e ... pass.
```

## Step 5 — Copy the lab pieces from an existing sibling

These files are large and pattern-stable enough that copying them
from `smb-proxy-appliance` (the most recent and most thorough
sibling) and adapting is faster than filling placeholders. From
your new repo's directory:

```bash
SIBLING="$PARENT/smb-proxy-appliance"

# Cloud-init templates — copy + adapt the user-data placeholders
cp "$SIBLING/lab/templates/cloud-init/meta-data.tpl"     lab/templates/cloud-init/
cp "$SIBLING/lab/templates/cloud-init/network-config.tpl" lab/templates/cloud-init/
# user-data: copy the proxy's user-data-proxy.tpl and rename:
cp "$SIBLING/lab/templates/cloud-init/user-data-proxy.tpl" \
   "lab/templates/cloud-init/user-data-${APPLIANCE_SHORT}.tpl"

# Stage / build / export pipeline — copy + s/proxy/${APPLIANCE_SHORT}/g
cp "$SIBLING/lab/stage-proxy-base.sh"       "lab/stage-${APPLIANCE_SHORT}-base.sh"
cp "$SIBLING/lab/build-fresh-base.sh"        lab/build-fresh-base.sh
cp "$SIBLING/lab/export-deploy-master.sh"    lab/export-deploy-master.sh

# Hyper-V VM creator (only if you need a custom shape — single NIC,
# different switches, different MAC scheme). Otherwise copy the
# samba sibling's New-SambaTestVM.ps1 as the simpler starting point.
cp "$SIBLING/lab/hyperv/New-SmbProxyTestVM.ps1" \
   "lab/hyperv/New-${APPLIANCE_NAME^}TestVM.ps1"   # case-adjust to taste
```

After copying, walk through each file with `git diff` and tighten:

- Adjust the per-NIC topology (single NIC vs dual NIC).
- Adjust the dnsmasq reservation MAC and IP (and remember to add
  the matching entry to `lab-router/configs/samba-addc.yaml` —
  see `dev-commons/decisions/0001-github-org-naimor-oss.md` history
  for why and how).
- Adjust default values to match the new appliance's purpose.

## Step 6 — Pre-publish review

Before pushing to a remote (which today means the `naimor-oss` org —
see `dev-commons/decisions/0001-github-org-naimor-oss.md`), walk
through `dev-commons/PUBLISH-CHECKLIST.md`. The credentials sweep
is the most important check.

## Step 7 — Add to dev-commons/SUPPORTED-ENVIRONMENTS.md

When the new appliance is built and tested somewhere, add a row
documenting the validated environment. This is what makes the
"host-agnostic" claim defensible.

## What to remove from the template after instantiation

- This `INSTANTIATE.md` file (already in Step 2).
- Anything in the template you don't need (e.g. the placeholder
  smoke scenario if you have a more specific one ready).

## What NOT to change

- The two-script pattern (`prepare-image.sh` + `<sconfig>.sh`).
  This is a STYLE.md §8 convention, not negotiable per-appliance.
- The lab-kit dependency layout (`../lab-kit/bin/run-scenario.sh`).
- The `dev-commons` reference at the top of AGENTS.md.
- The `.gitignore`'s `*creds*` rule and its existing exceptions.

Read [`../STYLE.md`](../STYLE.md) before customizing extensively;
the conventions there describe the line between "fine to adjust"
and "load-bearing".
