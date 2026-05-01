# dev-commons

Cross-cutting docs, templates, and tooling for the sibling-repo family
under `Debian-SAMBA/`. This is the meta-repo that keeps the appliance
and lab repos consistent with each other.

## Read me first

If you're new to this project, read **[`CONTEXT.md`](CONTEXT.md)**
before anything else. The rule documents below make sense only once
you know what they're protecting against.

## Where do I start?

| If you want to … | Read |
| --- | --- |
| Understand **why this project is shaped the way it is** | [`CONTEXT.md`](CONTEXT.md) |
| Look up **coding / docs / scripting conventions** | [`STYLE.md`](STYLE.md) |
| Understand the **multi-agent process and ownership model** | [`AGENTIC-DEVELOPMENT.md`](AGENTIC-DEVELOPMENT.md) |
| Understand **why there are four (now five) sibling repos** | [`REPO-SPLIT.md`](REPO-SPLIT.md) |
| See **which hypervisors / arches are validated** | [`SUPPORTED-ENVIRONMENTS.md`](SUPPORTED-ENVIRONMENTS.md) |
| Start a **new appliance repo** | `template-appliance-virtualized/` (or `template-appliance-iot/`) |
| Run a cross-sibling **sanity check / status / FIXME trawl** | `bin/sanity-check.sh`, `bin/sibling-status.sh`, `bin/find-fixmes.sh` |

## Sibling layout

```text
Debian-SAMBA/
  dev-commons/             this repo
  lab-kit/                 reusable lab harness (code)
  lab-router/              reusable router VM builder (code)
  samba-addc-appliance/    Samba AD DC appliance + scenarios
  smb-proxy-appliance/     SMB1<->SMB3 proxy appliance + scenarios
```

The appliances depend on `lab-kit` and `lab-router`. `dev-commons` is
referenced by every sibling's `AGENTS.md` for the shared conventions
but is otherwise independent — it doesn't ship code that gets called
at runtime.

## The boundary that matters most

This repo, every sibling source repo, and the build pipeline are
**builder-facing only**. Operators (the future outsourced IT helpers
described in `CONTEXT.md`) do not see them.

When writing anything that ends up in front of an operator
(appliance MOTD, console wizard, monitoring dashboard, ops runbook),
write it as boring system administration. The "custom in-house
appliance" framing is for builder eyes only — see `CONTEXT.md` for
why.

## Repository map

| Path | Purpose |
| --- | --- |
| `CONTEXT.md` | Project narrative — read first |
| `STYLE.md` | Coding, scripting, docs, test conventions |
| `AGENTIC-DEVELOPMENT.md` | Multi-agent team model and process |
| `REPO-SPLIT.md` | Why the project is split across sibling repos |
| `SUPPORTED-ENVIRONMENTS.md` | Validated-vs-intended hypervisor + arch matrix |
| `AGENTS.md` | Agent brief for `dev-commons` itself |
| `CLAUDE.md` | Compatibility pointer back to `AGENTS.md` |
| `bin/` | Cross-cutting tooling (sanity check, status, FIXME trawler) |
| `template-appliance-virtualized/` | Skeleton for a new virtualized appliance |
| `template-appliance-iot/` | Stub for a future IoT appliance pattern |
| `decisions/` | ADR-style log of choices that affect multiple repos |

## Status

Initial scaffolding. Phase 1 (this repo + migrated meta docs) and
Phase 2 (sibling cleanup so they reference `../dev-commons/`) land
together as foundations. Phases 3-6 follow:

- Phase 3: cross-cutting tooling (`bin/`)
- Phase 4: appliance templates
- Phase 5: audit existing sibling repos against `STYLE.md`
- Phase 6: bring approved deviations into compliance
