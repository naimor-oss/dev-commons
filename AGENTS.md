# Agent Guide — dev-commons

`dev-commons` is the meta-repo for the sibling-repo family living
under `Debian-SAMBA/`. It carries cross-cutting docs, templates, and
tooling that apply across the appliance and lab repos but don't
naturally live in any one of them.

## Read order for a new agent

1. **`CONTEXT.md`** — *first*. Why this project is shaped the way it
   is. Without this, the rules below will look arbitrary.
2. **`STYLE.md`** — coding, scripting, doc, and test conventions.
3. **`AGENTIC-DEVELOPMENT.md`** — multi-agent process and
   ownership patterns.
4. **`REPO-SPLIT.md`** — why there are four sibling repos and how
   they relate.
5. **`SUPPORTED-ENVIRONMENTS.md`** — the validated-vs-intended
   matrix of hypervisors and CPU archs.

## What's in scope for `dev-commons`

- **Cross-cutting docs**: rules, conventions, narrative context that
  applies to every sibling.
- **Templates**: starter skeletons for new appliance repos
  (`template-appliance-virtualized/`, `template-appliance-iot/`).
- **Cross-repo tooling**: scripts that operate across siblings
  (sanity check, status overview, FIXME trawler).
- **Decision log**: ADR-style notes for choices that affect more
  than one sibling.

## What's NOT in scope

- Any appliance-specific code or scenario. That lives in the
  appliance's own repo.
- The lab runner itself. That's `lab-kit`. `dev-commons` may
  *describe* it, but the code is `lab-kit`'s.
- Operator-facing material. See `CONTEXT.md` §"the boundary that
  matters most" — operator surfaces are not in any source repo;
  they live with the deployed appliance.

## Sibling repos this touches

```text
Debian-SAMBA/
  dev-commons/             this repo — meta + tooling + templates
  lab-kit/                 reusable lab harness (code)
  lab-router/              reusable router VM builder (code)
  samba-addc-appliance/    Samba AD DC appliance + scenarios
  smb-proxy-appliance/     SMB1<->SMB3 proxy appliance + scenarios
```

`dev-commons` is referenced by every sibling's `AGENTS.md` for the
shared conventions.

## Working in `dev-commons`

Same conventions as everywhere else in this project — see `STYLE.md`.
A few things specific to a meta-repo:

- **Don't put code here that belongs in a sibling.** If you find
  yourself writing appliance-specific or runner-specific logic, it
  belongs in the appliance repo or in `lab-kit`. The bar for
  `dev-commons` is "this is genuinely cross-cutting".
- **Updating `CONTEXT.md` is encouraged when reality changes.** A
  stale `CONTEXT.md` is worse than no `CONTEXT.md`.
- **Templates evolve as patterns settle.** When something shows up
  in two appliance repos in a similar shape, promote it to the
  template here.

## Vendor-specific notes

### Claude Code

`CLAUDE.md` (when added) is a thin compatibility pointer back to this
file. Treat `AGENTS.md` as the authoritative brief.

### Other coding agents

Use this file as the starting brief. Per-tool state stays in private
ignored dirs (`.claude/`, `.codex/`, etc.) and never gets committed.
