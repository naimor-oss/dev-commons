# template-appliance-iot — placeholder

This directory is a **placeholder** for the bare-metal IoT appliance
template. No working skeleton ships yet; the first IoT appliance
(planned within ~6 months per `../CONTEXT.md`) will solidify the
pattern, and at that point this directory gets fleshed out properly.

## Why a placeholder rather than nothing

Two reasons:

1. So that `../STYLE.md` §8 ("Pattern B — bare-metal IoT") has a
   concrete future home referenced by name, rather than dangling.
2. So that when the first IoT appliance lands, the work of "where
   do I scaffold this?" is already answered.

## What the IoT pattern is expected to differ on

Per `../STYLE.md` §8 (Pattern B), the bare-metal IoT pattern shares
the *two-script split* (`prepare-image.sh` + `<sconfig>.sh`) and the
*credential-neutral master image* discipline with the virtualized
pattern, but diverges on:

- **Image delivery**: SD/eMMC/NVMe written via `dd` or `pi-imager`,
  not VHDX. Build flow is pi-gen-derived or `debian-installer`
  preseed, not `qemu-img convert`.
- **No hypervisor**: no guest-agent cache. The `firstboot` service
  does *hardware* detection (Pi model, peripherals) instead of
  hypervisor detection.
- **No two-snapshot dance**: the analogue of `deploy-master` is the
  written image; the analogue of `golden-image` doesn't apply.
- **Networking**: usually single Ethernet + maybe Wi-Fi; the
  dual-NIC conventions in `../STYLE.md` §6 don't apply directly.
- **Console**: serial console (UART) or HDMI + USB keyboard, not
  SSH-jump-through-a-Hyper-V-host.
- **Architecture**: arm64 (sometimes armhf for older Pi). The
  virtualized template is amd64-only today.

## When to fill this in

When you (the maintainer) start the first real IoT appliance:

1. Scaffold a sibling repo by hand, using the virtualized template
   plus the modifications above as guidance.
2. Once the appliance is working and at least one other IoT
   appliance is on the horizon, distill what was actually shared
   between them into a real `template-appliance-iot/` skeleton
   here, mirroring what `template-appliance-virtualized/` does for
   the virtualized pattern.

Per `../STYLE.md` §16 ("promote up, don't propagate sideways"),
the right time to write this template is when you're about to
copy from the first IoT appliance to a second.
