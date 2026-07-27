# Sibling-Repo Layout

This project lives in six sibling repositories developed side by side
locally:

```text
Debian-SAMBA/
  dev-commons/             this repo — meta + tooling + templates
  lab-kit/                 reusable lab orchestration (code)
  lab-router/              reusable router VM builder (code)
  appliance-core/          shared appliance runtime libs + blank base appliance
  samba-addc-appliance/    Samba AD DC appliance + scenarios
  smb-proxy-appliance/     SMB1<->SMB3 proxy appliance + scenarios
```

Each repo is independently versioned and independently pushable. The
sibling layout is assumed by every script that uses relative paths
(`../<other-repo>/...`).

This doc is a reference for *where things live and where new work
belongs*. The "why we split" rationale is in the appendix at the
bottom for historical context.

## Repositories

### `dev-commons`

The meta-repo. Cross-cutting docs, templates, and tooling that apply
across siblings but don't naturally live in any one of them.

Ships:

- `CONTEXT.md` — project narrative; read first
- `STYLE.md` — coding/scripting/docs conventions
- `AGENTIC-DEVELOPMENT.md` — multi-agent process model
- `REPO-SPLIT.md` (this file)
- `SUPPORTED-ENVIRONMENTS.md` — validated-vs-intended hypervisor + arch matrix
- `bin/` — cross-sibling tooling (sanity check, status, FIXME trawler)
- `template-appliance-virtualized/` — skeleton for new virtualized appliance repo
- `template-appliance-iot/` — placeholder for the bare-metal IoT pattern
- `decisions/` — ADR-style log of cross-cutting choices

Boundary: no appliance code, no runner code, no operator-facing
material.

### `lab-kit`

Reusable appliance lab orchestration. Ships:

- `bin/run-scenario.sh` — generic pipeline: stage, reset, push,
  post-push, pre_hook, run_scenario, verify, post_hook.
- `hypervisors/hyperv/Revert-TestVM.ps1` — generic revert helper.
- `examples/samba-addc.env` — reference env file for an appliance
  consumer.
- `scenarios/common/` — shared scenario fragments.
- `docs/architecture.md`, `docs/hypervisors.md`.

Boundary: no appliance-specific logic. No Samba/SMB-proxy strings in
runner code. Hyper-V is the first backend; libvirt / Apple
Virtualization / Synology VMM should be addable without reshaping
the runner.

### `lab-router`

Simple lab router virtual appliance. Ships:

- `scripts/stage-router-artifacts.sh` — Mac-side stager that
  produces a reusable base VHDX and a per-router cloud-init seed
  ISO. Accepts CLI flags, `--config YAML` (single-LAN), and
  `--extra-dnsmasq` raw snippets.
- `templates/cloud-init/*.tpl` — Debian 13 cloud-init templates
  (nftables NAT, dnsmasq DHCP/DNS, hardened SSH).
- `hypervisors/hyperv/New-LabRouter.ps1` — Hyper-V VM builder.
- `configs/*.yaml` and `configs/samba-addc.dnsmasq.conf` — example
  configs.
- `docs/configuration.md` — YAML schema and what the stager reads.

Boundary: depends on neither lab-kit nor any appliance repo. Out of
scope: VPN, captive portal, WireGuard, firewall zones beyond NAT +
lab LAN.

### `appliance-core`

Shared bash libraries vendored into product appliances at
image-prep time, plus a deployable blank Debian appliance that
exists primarily to test those libraries across the
SUPPORTED-ENVIRONMENTS matrix. See ADR
[`decisions/0002-appliance-core.md`](decisions/0002-appliance-core.md)
for the why and the design draft at
[`proposals/appliance-core-design.md`](proposals/appliance-core-design.md)
for the lib contracts and migration plan.

- `lib/*.sh` + `lib/VERSION` — vendored at consumer prep time.
- `prepare-image.sh` + `core-sconfig.sh` — the blank appliance.
- `lab/scenarios/*.sh` — integration tests targeting the
  blank image.
- `tests/unit/*.bats` — bash unit tests for each lib.

Boundary: the libraries are infrastructure surfaces shared by
two-or-more appliances (network detection, hostname change, apt
helpers, MOTD, console wizard). Product-specific helpers stay in
their product repos.

### `samba-addc-appliance`

Samba AD DC appliance and its Samba-specific tests.

- `prepare-image.sh`, `samba-sconfig.sh` — the appliance itself.
- `lab/run-scenario.sh` — thin Samba wrapper around
  `../lab-kit/bin/run-scenario.sh`.
- `lab/samba.env` — appliance-specific wiring for the lab-kit runner.
- `lab/scenarios/*.sh` — Samba scenarios (`join-dc`,
  `smoke-prepared-image`, others).
- `lab/hyperv/*.ps1 *.xml` — Hyper-V/WS2025-specific helpers.
- `docs/SETUP.md`, `docs/LAB-TESTING.md`, `docs/RELEASE.md` —
  appliance-specific.

Boundary: reusable lab/router work belongs in the sibling repos.
Cross-cutting docs (style, repo-split, agentic-development) belong
in `dev-commons`.

### `smb-proxy-appliance`

SMB1↔SMB3 protocol-version proxy appliance and its proxy-specific
tests.

- `prepare-image.sh`, `smbproxy-sconfig.sh` — the appliance itself.
- `lab/run-scenario.sh` — thin proxy wrapper around
  `../lab-kit/bin/run-scenario.sh`.
- `lab/proxy.env` — appliance-specific wiring.
- `lab/scenarios/*.sh` — proxy scenarios (`smoke-prepared-image`,
  `bootstrap-network`, `join-domain`, `backend-mount`,
  `frontend-share`, `end-to-end`).
- `lab/hyperv/New-SmbProxyTestVM.ps1` — dual-NIC VM creator.
- `lab/templates/cloud-init/` — proxy-specific cloud-init templates.
- `lab/build-fresh-base.sh`, `lab/stage-proxy-base.sh`,
  `lab/export-deploy-master.sh` — build and release pipeline.
- `docs/SETUP.md`, `docs/LAB-TESTING.md` — appliance-specific.

Boundary: reuses the existing `samba-addc-appliance` lab environment
(router1, WS2025-DC1, LegacyZone) at runtime; does not stand up its
own AD DC. Cross-cutting docs live in `dev-commons`.

## Dependency Direction

```text
samba-addc-appliance       smb-proxy-appliance
  consumes lab-kit             consumes lab-kit
  consumes lab-router          consumes lab-router (router only)
  vendors appliance-core       vendors appliance-core
    libs at prep time            libs at prep time
                               relies on samba-addc-appliance
                                  *lab environment* at runtime
                                  (not on its source repo)

appliance-core              lab-kit                     lab-router
  consumes lab-kit            no upstream deps             no upstream deps
  consumes lab-router

dev-commons
  no runtime deps; referenced by every sibling's AGENTS.md for shared
  conventions
```

Note the asymmetry: `smb-proxy-appliance` joins the same WS2025
forest that `samba-addc-appliance`'s lab built, and shares the same
`lab-router` reservation file. That's a *runtime lab* dependency, not
a source-repo dependency — `smb-proxy-appliance`'s code does not
include any path under `../samba-addc-appliance/` other than docs
cross-references.

## When to add a new sibling vs extend an existing one

Add a **new sibling** when:

- It's a new appliance with its own image, sconfig, and scenarios.
- It's a reusable runtime piece that doesn't fit `lab-kit` or
  `lab-router` (rare).

Extend an **existing sibling** when:

- The work is a new scenario or new sconfig surface area for an
  existing appliance.
- The work is a new helper / hypervisor backend in `lab-kit`.

Promote to **`dev-commons`** when:

- A pattern shows up in two or more siblings in similar shape
  (template promotion).
- A piece of guidance applies across siblings (style or process
  rule).
- A decision that affects multiple siblings needs a durable home
  (ADR in `decisions/`).

Templates for new appliance repos live in
`dev-commons/template-appliance-virtualized/` (and
`template-appliance-iot/` once the first IoT appliance solidifies the
pattern).

## Publishing

Each repo is independently pushable. There is no top-level
super-repo or git-submodule structure. Cross-repo changes land as
ordered commits (dependency first, consumer second) and push in the
same order.

```bash
git -C dev-commons push origin main
git -C lab-kit push origin main
git -C lab-router push origin main
git -C samba-addc-appliance push origin main
git -C smb-proxy-appliance push origin main
```

The sibling-status helper (`dev-commons/bin/sibling-status.sh`) gives a
one-shot view of dirty trees and unpushed commits across all six.

## Appendix: how the project got to this layout

The work started as a single repository containing the Samba
appliance, the lab router, and the lab orchestration. Splitting
reusable pieces out of an appliance-specific home was the obvious
first step. The original split was three repos
(`samba-addc-appliance`, `lab-kit`, `lab-router`).

`smb-proxy-appliance` joined as the second appliance, reusing the
lab infrastructure rather than duplicating it. That made the
sibling layout's value concrete: a second appliance landed in days
because the lab pieces already existed.

`dev-commons` was added when the project's near-term outlook clarified
— additional appliances, partial outsourcing of IT operations, and a
move toward arm64 + IoT in the next ~6 months meant the cross-cutting
conventions needed a tracked home rather than living in one
appliance's `docs/` directory. See `dev-commons/CONTEXT.md` for the
fuller narrative.
