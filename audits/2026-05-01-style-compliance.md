# 2026-05-01 — STYLE.md compliance sweep across all five siblings

Initial full audit against `../STYLE.md` (revision at commit
`1eeb2b6`). Scope: `dev-commons`, `lab-kit`, `lab-router`,
`samba-addc-appliance`, `smb-proxy-appliance`.

Scanning method: a mix of `grep -rn`, the `dev-commons/bin/` tooling
(`sanity-check.sh`, `find-fixmes.sh`), and manual file inspection.
No edits performed during the sweep.

## Resolution legend

Reviewer fills the `Resolution` column on each finding before Phase 6.

- `fix` — bring into compliance now
- `defer` — accept but track for later (write the deferral as a
  comment / TODO in code or as a note in this file)
- `reject` — STYLE.md is wrong here; the audit prompts a STYLE.md
  amendment instead

## HIGH severity

### H1 — Samba netplan template missing `dhcp-identifier: mac`

- **STYLE.md ref**: §6 (cloud-init / netplan templates)
- **Files**: `samba-addc-appliance/lab/templates/cloud-init/network-config.tpl`
- **Deviation**: stanza uses `match: name: "e*"` (kernel-name
  matching) and no `dhcp-identifier: mac`. The proxy appliance hit
  this exact bug on its first build attempt: dnsmasq's MAC
  reservation didn't match systemd-networkd's default DUID-based
  client-ID, so the VM got a dynamic-pool address instead of the
  reserved one.
- **Why it matters**: `samba-dc1` currently works because its
  initial DUID is in dnsmasq's lease file from a prior build, but
  `lab/build-fresh-base.sh -f` rebuilds the VM and could trigger a
  fresh DHCPDISCOVER. The same bug is one rebuild away.
- **Fix**: add `dhcp-identifier: mac` to the DHCP stanza, optionally
  also tighten `match: name: "e*"` to MAC-based matching for
  parity with the proxy template.
- **Resolution**: _________

### H2 — `samba-addc-appliance/.gitignore` missing `*creds*`

- **STYLE.md ref**: §2 (.gitignore conventions), §9 (credentials
  layered defenses)
- **Files**: `samba-addc-appliance/.gitignore`
- **Deviation**: the file lacks `*creds*` and the `!docs/**/*creds*`
  exception. Even though the Samba sibling doesn't currently carry
  a credential file, the rule is defensive *precisely* so an
  accidental drop of `/etc/samba/.legacy_creds` (or any file with
  "creds" in the name) doesn't slip in unnoticed.
- **Why it matters**: §9 layered defenses hold only if every repo
  has the same defaults. Samba is the one with the most apt to
  acquire creds files in the future (operator might copy
  `secrets.tdb` locally for inspection, etc.).
- **Fix**: add the same `*creds*` block as
  `smb-proxy-appliance/.gitignore`.
- **Resolution**: _________

### H3 — Operator-facing surfaces use "Appliance" framing

- **STYLE.md ref**: §15 (builder / operator boundary)
- **Files**:
  - `samba-addc-appliance/prepare-image.sh:444` — console banner
    `║ Debian 13 (Trixie) Appliance ║`
  - `samba-addc-appliance/prepare-image.sh:1224` — first-boot MOTD
    `=== Samba AD DC Appliance: first-boot host integration ===`
  - `samba-addc-appliance/prepare-image.sh:1797` — net-status MOTD
    `printf '\n  Samba AD DC Appliance\n'`
  - `smb-proxy-appliance/prepare-image.sh:380-381` — console banner
    `║ SMB1↔SMB3 Protocol-Version Proxy Appliance ║` /
    `║ Debian 13 (Trixie) Appliance ║`
  - `smb-proxy-appliance/prepare-image.sh:764` — first-boot MOTD
    `=== SMB1↔SMB3 Proxy Appliance: first-boot host integration ===`
  - `smb-proxy-appliance/prepare-image.sh:1477` — net-status MOTD
    `printf '\n  SMB1↔SMB3 Proxy Appliance\n'`
  - `smb-proxy-appliance/prepare-image.sh:1618-1647` — the §21B
    ixgbevf VF warning text repeatedly references "this appliance"
- **Deviation**: §15 prescribes that operator-eyed text reads as
  boring system administration. Words like "appliance" and
  "first-boot host integration" flag the bespoke nature without
  operational reason.
- **Why it matters**: per `CONTEXT.md`, future outsourced helpers
  see operator-facing surfaces only. Spooked helpers escalate
  unnecessarily. The mitigation is framing, not dishonesty.
- **Fix proposal**: replace operator-eyed strings with neutral
  descriptions. Suggested rewrites:
  - Console banner: `║ Debian 13 (Trixie) — File Server / AD DC ║` (Samba) or `║ Debian 13 (Trixie) — SMB Gateway ║` (proxy)
  - First-boot MOTD: `=== Debian first-boot host detection ===`
  - Net-status MOTD: `printf '\n  Debian SMB Server\n'` or `printf '\n  Debian SMB Gateway\n'`
  - ixgbevf warning: replace "this appliance" with "this server" or
    "this VM" throughout.
  - Builder-facing surfaces (script comments, AGENTS.md, commit
    messages) keep the "appliance" word — they're for builders.
- **Resolution**: _________

## MEDIUM severity

### M1 — Stagers hardcode `amd64` instead of accepting `--arch`

- **STYLE.md ref**: §8 ("Stagers should accept an arch parameter
  even if today only `amd64` is implemented. Future-proof the
  interface; defer the implementation.")
- **Files**:
  - `lab-router/scripts/stage-router-artifacts.sh:45,218`
  - `samba-addc-appliance/lab/stage-samba-base.sh:31,128`
  - `smb-proxy-appliance/lab/stage-proxy-base.sh:38,154`
- **Deviation**: each stager hardcodes `debian-13-genericcloud-amd64.qcow2`
  in both the download URL and the cache filename. STYLE.md §8
  explicitly calls out that arm64 is inevitable within ~6 months
  and the interface should be ready even before the implementation
  is.
- **Why it matters**: per `CONTEXT.md` the arm64 work is
  inevitable on a near horizon. Adding the `--arch` interface now
  while there's only one user is cheap; retrofitting it across
  three stagers later when arm64 work is in flight is not.
- **Fix proposal**: each stager grows an `-a / --arch ARCH` flag
  defaulting to `amd64`, computes the URL and cache filename from
  it, and rejects unsupported values cleanly. The OVA's
  `guestOS = "debian12-64"` in `export-deploy-master.sh` stays
  amd64 today — `STYLE.md` §8 says the architecture decision in
  ovftool can wait.
- **Resolution**: _________

### M2 — `lab-kit` and `lab-router` missing `CLAUDE.md` and `HANDOFF.md`

- **STYLE.md ref**: §1 (per-repo top-level structure table)
- **Files**: `lab-kit/`, `lab-router/`
- **Deviation**: §1's table lists `CLAUDE.md` and `HANDOFF.md` as
  standard. Both repos have `README.md`, `AGENTS.md`, and
  `.gitignore` but lack the other two.
- **Why it matters**: Claude Code reads `CLAUDE.md` by convention.
  Without it, agents starting in `lab-kit` or `lab-router` miss
  the project pointer. `HANDOFF.md` is a stable landing spot for
  "where do I read first?" — without it, the README has to do that
  job alone, which limits its other roles.
- **Fix proposal**: add minimal `CLAUDE.md` (compatibility pointer
  back to `AGENTS.md`) and `HANDOFF.md` (one-paragraph pointer at
  maintained docs) per the proxy / samba pattern, with paths
  updated for the lab-kit / lab-router context.
- **Resolution**: _________

### M3 — `lab-kit` and `lab-router` README missing "Where do I start?" table

- **STYLE.md ref**: §3 (`README.md` shape: "Where do I start?" table
  is item 2 of the standard shape)
- **Files**: `lab-kit/README.md`, `lab-router/README.md`
- **Deviation**: both READMEs jump from a one-paragraph purpose to a
  "Repository Map" table without the navigational "Where do I
  start?" intent-mapping table that other repos use.
- **Why it matters**: a stranger landing on a repo page benefits
  from being told *which doc answers which question* before being
  shown the file list. Per `CONTEXT.md`, future outsourced helpers
  and other contributors are exactly this audience.
- **Fix proposal**: add a "Where do I start?" table mapping
  intents (architecture? hypervisor backend support? configuration
  schema?) to docs.
- **Resolution**: _________

### M4 — `dev-commons` missing `HANDOFF.md`

- **STYLE.md ref**: §1 (standard files table)
- **Files**: `dev-commons/`
- **Deviation**: same as M2, but for `dev-commons` itself. Has
  `README.md`, `AGENTS.md`, `CLAUDE.md`, `CONTEXT.md`, and
  several others, but no `HANDOFF.md`.
- **Why it matters**: `dev-commons` doesn't strictly need a
  HANDOFF (the README's "Where do I start?" table covers it),
  but the convention is that every sibling has one for
  consistency. STYLE.md §1's table also lists it as standard.
- **Fix proposal**: either add a one-paragraph `HANDOFF.md`
  pointing at the maintained docs, OR amend `STYLE.md` §1 to
  mark `HANDOFF.md` as "(only where the repo is large enough to
  benefit; meta-repos may skip)". The second framing is closer to
  what was actually intended.
- **Resolution**: _________

## LOW severity

### L1 — `lab-kit` / `lab-router` `.gitignore` minimal

- **STYLE.md ref**: §2 (`.gitignore` conventions)
- **Files**: `lab-kit/.gitignore`, `lab-router/.gitignore`
- **Deviation**: both files have a small subset of the canonical
  block:
  - lab-kit: `.DS_Store`, `._*`, `test-results/`, `*.log`,
    `.env`, `.claude/`, `.codex/`, `.cursor/`, `.continue/`,
    `.aider*`. Missing: broader macOS set (AppleDouble, Spotlight,
    Trashes, AppleDB, etc.), `dist/`, `*creds*`.
  - lab-router: similar; also has `*.iso`, `*.qcow2`, `*.vhdx`
    (appropriate for a stager repo). Missing same items as lab-kit.
- **Why it matters**: defensive entries cost nothing and protect
  against the easy mistake (e.g. a credential file accidentally
  copied into the repo). Consistency across siblings makes
  audits easier too.
- **Fix proposal**: bring both `.gitignore` files up to the
  samba/proxy canonical version, minus the `lab/keys/*` and
  `dist/` entries that don't apply (lab-kit and lab-router don't
  have `lab/keys/` or `dist/` directories). Keep the existing
  appliance-specific entries (`*.iso`, `*.qcow2`, `*.vhdx` in
  lab-router are useful).
- **Resolution**: _________

### L2 — `STYLE.md` §4 silent on sourced files

- **STYLE.md ref**: §4 (Bash style)
- **Files**: `STYLE.md` itself
- **Deviation**: §4 prescribes `#!/usr/bin/env bash` and
  `set -euo pipefail` "always" but doesn't note that scenario
  files (under `lab/scenarios/`) are *sourced* by the runner,
  not executed, so they don't carry shebangs or `set` lines.
  Future maintainers reading §4 might mistakenly add them.
- **Why it matters**: a confused contributor would either add
  them and have the runner trip on `set -e` mid-source, or they
  would remove the no-shebang scenario files thinking they're
  broken.
- **Fix proposal**: add a one-paragraph clarification in §4 that
  scenario files are sourced fragments and follow a different
  contract (described in §7).
- **Resolution**: _________

### L3 — `find-fixmes.sh` exclusion misses `template-appliance-virtualized/`

- **STYLE.md ref**: §10 (FIXME tracking)
- **Files**: `dev-commons/bin/find-fixmes.sh`,
  `dev-commons/template-appliance-virtualized/prepare-image.sh:166`
- **Deviation**: the find-fixmes regex excludes meta-files that
  *describe* the FIXME convention (STYLE.md, decisions/,
  PUBLISH-CHECKLIST.md, the script itself). It does NOT exclude
  the appliance template's `prepare-image.sh` skeleton, which has
  a `# FIXME(remove-when-fixed)` reference inside a comment about
  *how* to use the convention. Smoke run picks it up as a false
  positive.
- **Why it matters**: false positives in the trawler erode trust
  in its output. If the trawler reports 4 hits and 1 is fake,
  next time someone might dismiss a real one as "probably the
  template again".
- **Fix proposal**: add `(^|/)template-[^/]+/` to the exclusion
  regex. Templates are meta by definition.
- **Resolution**: _________

## Items audited and clean

For posterity, things checked that turned out OK:

- §4 — no `${var^^}` / `${var,,}` actually used in
  orchestrator-side code (all hits are in *comments explaining
  why they're avoided*; the precedent is correctly followed).
- §4 — every executable shell script in every sibling has
  `#!/usr/bin/env bash` and `set -euo pipefail` (or the explicit
  `set -uo pipefail` for the two `*-sconfig.sh` files, which is
  the documented relaxation for whiptail's exit-on-Cancel
  behavior).
- §8 — `prepare-image.sh` skeletons are correctly
  deployment-neutral: `YOURREALM.LAN` placeholder present, no
  public NTP pools baked in, `/etc/samba/smb.conf` removed at
  image-prep time.
- §9 — production credentials no longer literal in tracked
  content (the WS2008 cred was rotated and replaced with a
  placeholder this same session).
- §10 — the two `FIXME(remove-when-fixed)` blocks for the ixgbevf
  blacklist are well-formed: each has the what / why-safe / how-to-remove
  triplet `STYLE.md` §10 prescribes.
- §3 — three out of five repos lead with the "Where do I start?"
  table (all three appliance-side repos plus dev-commons; only
  lab-kit and lab-router don't — see M3).
- §11 — `say` and `step` helpers are used consistently in all
  long-pipeline scripts.
- §12 — recent commits across all siblings have focused subjects,
  bodies explaining "why", and `Co-Authored-By` for AI
  contributions.

## Summary

10 findings: 3 HIGH, 4 MEDIUM, 3 LOW. None of them block the
existing deployments. The HIGH set is concentrated around two
themes that match this project's stated risk posture: rebuild
fragility (H1), credential discipline (H2), and the
builder/operator boundary (H3). The MEDIUM set is mostly
forward-compat hygiene (M1) and consistency across the
non-appliance siblings (M2, M3, M4). The LOW set is a mix of
defensive cleanups and a STYLE.md amendment.

## Reviewer notes

(Reviewer fills this section with any cross-cutting decisions, e.g.
"defer all M-series until after the NaimorOSS push" or "fix all
HIGH this week, treat MEDIUM as a separate audit pass".)
