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
| Understand **why there are seven sibling repos** | [`REPO-SPLIT.md`](REPO-SPLIT.md) |
| See **which hypervisors / arches are validated** | [`SUPPORTED-ENVIRONMENTS.md`](SUPPORTED-ENVIRONMENTS.md) |
| Check a repo before **publishing it to GitHub** | [`PUBLISH-CHECKLIST.md`](PUBLISH-CHECKLIST.md) |
| Run the **release gate** before shipping a change | [`RELEASE-GATE.md`](RELEASE-GATE.md) |
| Look up a **cross-cutting decision** | [`decisions/`](decisions/) |
| **Scaffold a new appliance repo** from the template | `bin/new-appliance.sh` (template lives at `template-appliance-virtualized/`) |
| Run a cross-sibling **sanity check / status / FIXME trawl** | `bin/sanity-check.sh`, `bin/sibling-status.sh`, `bin/find-fixmes.sh` |
| Run the **no-VM preflight** before any lab scenario | `bin/preflight.sh` |

## Sibling layout

```text
Debian-SAMBA/
  dev-commons/             this repo
  lab-kit/                 reusable lab harness (code)
  lab-router/              reusable router VM builder (code)
  appliance-core/          shared appliance runtime libraries + blank test appliance
  samba-addc-appliance/    Samba AD DC appliance + scenarios
  smbproxy-session-vfs/    private Samba VFS component + compatibility builds
  smb-proxy-appliance/     SMB1<->SMB3 proxy appliance + scenarios
```

The appliances depend on `lab-kit` and `lab-router`; product appliances
vendor shared libraries from `appliance-core` at image-prep time.
`dev-commons` is referenced by every sibling's `AGENTS.md` for the shared
conventions but is otherwise independent — it doesn't ship runtime code.

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
| `PUBLISH-CHECKLIST.md` | Pre-publish gate for pushing repos to GitHub |
| `RELEASE-GATE.md` | Preflight + nine-scenario VM gate before shipping a change |
| `decisions/` | ADR-style log of choices that affect multiple repos |
| `AGENTS.md` | Agent brief for `dev-commons` itself |
| `CLAUDE.md` | Compatibility pointer back to `AGENTS.md` |
| `bin/` | Cross-cutting tooling: preflight, sanity check, status, shellcheck, FIXME trawler, and scaffolding |
| `template-appliance-virtualized/` | Skeleton for a new virtualized appliance |
| `template-appliance-iot/` | Stub for a future IoT appliance pattern |

## Status

Active. Six sibling repositories are public; the new `smbproxy-session-vfs`
repository is staged locally pending first publication. Cross-repo tooling and
the virtualized-appliance template are in place, and
[`RELEASE-GATE.md`](RELEASE-GATE.md) is the readiness source of truth.
The IoT template remains intentionally skeletal until the first
bare-metal appliance establishes that pattern.
