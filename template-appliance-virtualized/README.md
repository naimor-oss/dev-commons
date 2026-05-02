# <APPLIANCE-TITLE>

<APPLIANCE-PURPOSE>

## Where do I start?

| If you want to … | Read |
| --- | --- |
| **Deploy** the appliance from a release artifact (`.ova` / `.qcow2` / `.vhdx`) | [`docs/RELEASE.md`](docs/RELEASE.md) |
| **Build your own master** image, run the test lab, or contribute changes | [`docs/SETUP.md`](docs/SETUP.md) |
| Understand the **test methodology** | [`docs/LAB-TESTING.md`](docs/LAB-TESTING.md) |
| Understand the **sibling-repo split** | [`../dev-commons/REPO-SPLIT.md`](../dev-commons/REPO-SPLIT.md) |
| Look up **shared coding/docs/test conventions** | [`../dev-commons/STYLE.md`](../dev-commons/STYLE.md) |

This appliance is one of the sibling-repo family under `Debian-SAMBA/`.
See [`../dev-commons/REPO-SPLIT.md`](../dev-commons/REPO-SPLIT.md) for
the full layout. At runtime it depends on `lab-kit` (test runner)
and `lab-router` (lab DHCP/DNS).

## Repository Map

| Path | Purpose |
| --- | --- |
| `prepare-image.sh` | One-time Debian image preparation. Vendor-, realm-, credential-neutral. Produces a host-agnostic master image. |
| `<APPLIANCE-SHORT>-sconfig.sh` | Main appliance configuration tool. Whiptail TUI plus headless CLI for per-deployment configuration. |
| `lab/proxy.env` | (rename to `<APPLIANCE-SHORT>.env`) Lab environment file consumed by the generic runner. |
| `lab/run-scenario.sh` | Appliance-specific wrapper around `../lab-kit/bin/run-scenario.sh`. |
| `lab/scenarios/` | Scenario shell files (`smoke-prepared-image`, plus appliance-specific scenarios). |
| `lab/templates/cloud-init/` | NoCloud seed templates (meta-data, network-config, user-data). |
| `lab/keys/` | Operator SSH pubkeys baked into the image at build time. See `lab/keys/README.md`. |
| `lab/hyperv/` | Hyper-V-specific PowerShell helpers. |
| `docs/` | Setup, lab-testing, release docs. |
| `AGENTS.md` | Vendor-neutral coding-agent guide for this repo. |
| `CLAUDE.md` | Claude Code compatibility pointer back to `AGENTS.md`. |
| `HANDOFF.md` | Pointer to the maintained docs. |

Cross-cutting docs (sibling-layout reference, coding conventions,
multi-agent process, project narrative) live in
[`../dev-commons/`](../dev-commons/) and are linked from
[`AGENTS.md`](AGENTS.md).

## Status

(Replace this section with a real "Status" paragraph once the appliance
has its first build. The `samba-addc-appliance` and `smb-proxy-appliance`
sibling READMEs are good references for the shape this section takes
once the work is real.)
