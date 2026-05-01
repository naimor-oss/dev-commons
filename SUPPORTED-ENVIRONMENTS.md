# Supported Build and Runtime Environments

This file tracks which hypervisors and hardware platforms have been
**actually validated** with the appliance images we ship, vs which are
**intended-but-unverified**.

The distinction matters: §14 of `STYLE.md` ("Empirical priority")
treats *unverified host-agnostic* as a red flag. This file is the
ledger that protects us against that drift.

## How to use this file

When you successfully build, import, or run an appliance image on a
new combination of (hypervisor, CPU arch, host OS), update the
matching row. Include the appliance + version, the date, and any
relevant notes (panics avoided, tweaks needed, performance
observations).

When you encounter a *failure* on a new combination, also record it —
either inline under the relevant row or as a row in the "Known Failure
Modes" section. The ixgbevf panic is the canonical example: it's not
"Hyper-V failed", it's "Hyper-V on host X with firmware Y plus
ixgbevf passthrough failed for reason Z".

## Hypervisor / Host Matrix

| Environment | CPU arch | Status | Last validated | Notes |
| --- | --- | --- | --- | --- |
| Hyper-V on Windows Server | amd64 | **build host** | 2026-05-01 | Primary build/test host; `samba-addc-appliance` and `smb-proxy-appliance` lab targets |
| Hyper-V on Windows Server (different host) | amd64 | **validated** | 2026-05-01 | `smb-proxy-appliance v2026.05.01` OVA imports cleanly after Secure Boot disabled; ixgbevf VF passthrough must be off (`Set-VMNetworkAdapter -IovWeight 0`) — see Known Failure Modes |
| Client Hyper-V on Windows desktop | amd64 | intended | — | Same APIs as Server; expected to work |
| Parallels Desktop on macOS | amd64 | intended | — | OVA carries `firmware = "efi"` + Secure Boot off; should import |
| Parallels Desktop on macOS | arm64 | intended | — | Awaits arm64 image variant |
| Apple Virtualization framework (Tart, etc.) | arm64 | intended | — | Awaits arm64 image variant |
| Synology VMM | amd64 | intended | — | KVM-based; qcow2 artifact is the natural fit |
| Synology VMM | arm64 | not applicable | — | Synology DSM virtualization is amd64-only as of this writing |
| Raspberry Pi (bare metal) | arm64 | intended (IoT pattern) | — | Awaits IoT appliance template (different pattern from virtualized — see CONTEXT.md) |
| Raspberry Pi (bare metal) | armhf | not planned | — | New work targets arm64 only |
| KVM/QEMU on Linux desktop | amd64 | intended | — | qcow2 artifact directly usable |
| Proxmox VE | amd64 | intended | — | qcow2 import expected to work |
| VirtualBox | amd64 | intended | — | OVA import expected to work |
| VMware Workstation / Fusion | amd64 | intended | — | OVA import expected to work |
| ESXi | amd64 | intended | — | OVA import expected to work |

**Status legend:**
- **build host** — actively used to build images; assumed-working
- **validated** — image successfully booted and reached login prompt
- **fully tested** — validated *and* the lab scenarios were exercised
- *intended* — believed to work; awaiting verification
- *not applicable* — combination doesn't exist or isn't planned
- *not planned* — explicitly out of scope

## Known Failure Modes

Each entry: what fails, on which combination, with what symptom, and
the workaround currently in effect (if any).

### `ixgbevf` NULL-deref kernel panic on SR-IOV passthrough

- **Where**: Hyper-V on hosts with Intel 82599/X540/X550 PFs and
  SR-IOV enabled, exposing the VF to the guest. Confirmed on
  Hyper-V UEFI Release v4.1 09/25/2025.
- **Kernel**: Linux 6.12.74 (Debian trixie kernel `6.12.74+deb13+1-cloud-amd64`).
- **Symptom**: VM never finishes booting. Panic in
  `ixgbevf_negotiate_api+0x66/0x160` with `RIP: 0010:0x0`.
- **Workaround in effect**: `prepare-image.sh §21B` blacklists
  `ixgbevf` defensively. `update-motd.d/16-smbproxy-vf-warning`
  surfaces the situation to the operator on login when an unbound
  Ethernet PCI device is detected.
- **Operator-side mitigation**: `Set-VMNetworkAdapter -VMName <vm>
  -IovWeight 0` on the affected vNIC. The synthetic `hv_netvsc` NIC
  is used regardless.
- **How to retire the workaround**: track LKML / Debian kernel-team
  for an `ixgbevf NULL deref in negotiate_api` fix; verify on the
  same host firmware combo; remove
  `/etc/modprobe.d/smbproxy-blacklist-ixgbevf.conf` and
  `update-initramfs -u`.

## Architecture Coverage

Today: **amd64 only.** All shipped images, the build pipeline, and
the lab harness target amd64.

Within ~6 months (per `CONTEXT.md`): **arm64 expected** for at least
two reasons — Apple Silicon for local AI inference, and ARM-based
Edge AI / IoT hardware for shop-floor use cases.

Implications already in code:

- Avoid baking `amd64` into filenames, paths, or hard-coded
  assumptions where `<arch>` would do
- The Debian cloud image base is currently
  `debian-13-genericcloud-amd64.qcow2`; an arm64 sibling will be
  `debian-13-genericcloud-arm64.qcow2` and stagers should
  parameterize the arch
- The OVA's `guestOS = "debian12-64"` will need an arm64 variant;
  research closer to the time

When the first arm64 build lands, expand this file with a column
or sibling matrix for arm64 results.
