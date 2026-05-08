# 0002 — Appliance core as a new sibling repo

**Status**: accepted
**Date**: 2026-05-08

## Context

Three regressions surfaced in two days of operator testing, all in
shared "infrastructure" code that lives separately in each appliance
repo:

- Stale PTR cache: `samba-firstboot` is one-shot, so the cached PTR
  in `/var/lib/samba-init-detected.env` never refreshes after the
  operator changes the hostname.
- Stale upgrade count: `apt list --upgradable` includes phased-rollout
  packages that `full-upgrade` won't actually install, so the
  `[U] Update OS (N pending)` banner stays at N forever.
- Stale realm in hostname prompt: `samba-sconfig`'s `config_hostname`
  asks for the full FQDN and pre-fills with `hostname -f`, which
  embeds whatever realm a previous join wrote into `/etc/hosts`.

In each case the fix landed in `samba-addc-appliance` and was either
not present in `smb-proxy-appliance` or had drifted out of sync
between the two. The first-boot console wizard, hostname-change
flow, network configuration, MOTD render, and update flow are
roughly equivalent across both appliances; the duplication is the
regression vector.

The two appliances total ~8.5k lines of bash. A meaningful fraction
is duplicated infrastructure code.

The owner's near-term outlook (`CONTEXT.md`):

- 2-9 months: partial outsourcing of IT operations. The fewer
  failure modes that survive in shared code, the better.
- Within ~6 months: arm64 (Apple Silicon, Pi/IoT). A second arch
  multiplies the duplication if the shared code lives separately.

## Decision

Create a new sibling repo `appliance-core` next to the existing
five (`dev-commons`, `lab-kit`, `lab-router`, `samba-addc-appliance`,
`smb-proxy-appliance`).

The new repo is **both** a shared library and a deployable blank
appliance:

- `lib/` — bash libraries (detect-net, apt-helpers, hostname,
  netconfig, console-wizard, motd) consumed by appliance
  `prepare-image.sh` scripts at image-prep time. Vendored — copied
  into the target image at `/usr/local/lib/appliance-core/`.
- `prepare-image.sh` + `core-sconfig.sh` — the blank appliance.
  Same two-script pattern as every other appliance. The blank
  has no product service: it ships first-boot wizard, hostname
  change, network config, MOTD, update flow, reboot handling.
- `lab/scenarios/` — lab tests for the blank appliance covering
  exactly the surfaces the recent regressions hit (deploy, hostname
  change post-reboot, network change, update flow, reboot-required
  propagation). Run independently of any product appliance.
- `dist/` — release artifacts for the blank appliance, shipped in
  the same vhdx/qcow2/vmdk/ova formats as the product appliances.
  Tested across the SUPPORTED-ENVIRONMENTS matrix.

The blank image is a **test harness today** — its primary job is
catching shared-code regressions before they reach product
appliances. Whether it also becomes a **product base** (downstream
appliances chained off its deploy-master via differencing VHDX or
qcow2 backing chain) is deferred to a future decision. The library
extraction does not depend on that path; the chained-image path can
land later without restructuring the lib layout.

Repo name: `appliance-core` (builder-facing).
Image name in operator-facing artifacts (OVA metadata, MOTD, etc.):
neutral (e.g. `debian-13-base-server`, exact wording TBD), per the
builder/operator boundary in `CONTEXT.md`.

Out of scope for the initial extraction:

- AD-DC discovery, LDAP probes, Samba-specific helpers — stay in
  `samba-addc-appliance`.
- Dual-NIC / NIC-role assignment, backend-creds, smb.conf edits —
  stay in `smb-proxy-appliance`.
- Product-specific MOTD lines — each appliance overrides a slot
  the core renders.
- Unattended-upgrades policy presets (operator policy choice) —
  stay in each product's sconfig.
- arm64 implementation — image is amd64-first, but filenames and
  paths are arch-tagged from day one (`*-amd64.vhdx`) so the arm64
  variant slots in without rename.

## Consequences

**Wins**:

- One canonical implementation of each shared surface. Fixing PTR
  cache once fixes it for all consumers.
- The blank image's lab covers exactly the surfaces regressions
  have hit — caught before they reach product appliances.
- arm64 / IoT future has a natural seam: the core grows arch
  variants; products consume the matching variant.

**Costs**:

- One more repo to push, one more sibling to keep aligned.
- Migration is gradual: extract one lib at a time, migrate one
  appliance, run its scenarios, then move on. Both appliances
  remain releasable throughout.
- Cross-version skew risk: a core change can break a downstream.
  Mitigation: `appliance-core/lib/VERSION` carries a SemVer;
  consumers' `prepare-image.sh` reads it at prep time and refuses
  to build against an unsupported range.

**Risks accepted**:

- The first extraction picks a contract shape that's wrong for some
  call site we hadn't noticed. Mitigation: contracts drafted before
  code, with explicit "Excludes" lists; first migration is one lib
  + one appliance, scenarios run before moving to the next.
- The blank image's lab isn't comprehensive at v0.1.0. Mitigation:
  initial scenario set is exactly the recent-regression surfaces;
  more scenarios added as new core surfaces land.

## Pointers

- Design draft (lib contracts, call-site map, test-suite shape):
  [`../proposals/appliance-core-design.md`](../proposals/appliance-core-design.md)
- Builder/operator boundary that constrains operator-facing strings:
  [`../CONTEXT.md`](../CONTEXT.md) §"the boundary that matters most"
- Two-script pattern preserved in the new repo: [`../STYLE.md`](../STYLE.md) §8
- arm64 forward-compat rules: [`../STYLE.md`](../STYLE.md) §15
