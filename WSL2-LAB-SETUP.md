# Lab workstation on Windows 11 with WSL2

The supported development and lab workstation is Windows 11 (x86_64) with
Hyper-V and WSL2 (`SUPPORTED-ENVIRONMENTS.md`). The lab scripts run in a
WSL2 Linux shell; Hyper-V runs the lab VMs. The workstation-specific parts
(ISO share path, seed ISO builder, checksums) live in one helper,
`lab-kit/lib/lab-host.sh`, which every staging, build, export and scenario
script sources. macOS still works through the same helper but is no longer
tested.

This page is also the checklist for validating the WSL2 pipeline the first
time.

## 1. Windows side

1. Windows 11 Pro or Enterprise with **Hyper-V** enabled
   (`Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All`).
2. **PowerShell 7** (`pwsh`), used by the Hyper-V helper scripts.
3. **OpenSSH Server** enabled and running, with key authentication for
   the account that manages Hyper-V. The lab scripts reach the Hyper-V host
   with `ssh <HV_USER>@<HV_HOST> 'pwsh -File D:\ISO\lab-scripts\...'` and use
   it as the SSH jump host to the lab VMs, exactly as before.
4. The ISO directory **`D:\ISO\`** (the scripts expect this host path;
   `LAB_HOST_STAGE_DIR` and `ISO_DIR_HOST` override it).
5. The lab router and switches from `lab-router` (unchanged).

## 2. WSL2 side

```powershell
wsl --install -d Debian          # or Ubuntu
```

For WSL2 on the Hyper-V host itself, mirrored networking lets the WSL
shell reach the host's SSH server as `localhost`. In
`%UserProfile%\.wslconfig`:

```ini
[wsl2]
networkingMode=mirrored
```

then `wsl --shutdown` and reopen the shell.

Inside WSL2:

```bash
sudo apt-get update
sudo apt-get install -y git qemu-utils xorriso openssh-client curl \
    bats shellcheck docker.io
# lab-router --config needs mikefarah yq v4 (Debian's "yq" package is a
# different tool): install the release binary from github.com/mikefarah/yq.
git config --global core.autocrlf false     # scripts must keep LF endings
```

Clone the siblings **inside the WSL2 filesystem** (for example `~/src`),
not under `/mnt/c`: DrvFs loses Unix file modes and is slow.

```bash
mkdir -p ~/src && cd ~/src
for r in dev-commons appliance-core lab-kit lab-router \
         samba-addc-appliance smbproxy-session-vfs smb-proxy-appliance; do
    git clone git@github.com:naimor-oss/$r.git
done
```

## 3. The ISO share from WSL2

| Workstation | ISO share path (`lab_iso_dir`) |
| --- | --- |
| WSL2 on the Hyper-V host | `/mnt/d/ISO` (default) |
| WSL2 on another PC | mount the host's share, then `export LAB_ISO_DIR=<mount>` |
| macOS (legacy) | `/Volumes/ISO` |

For another PC, map the share in Windows (`net use I: \\hyperv-host\ISO`)
and use `/mnt/i`, or mount it in WSL2:

```bash
sudo mkdir -p /mnt/iso
sudo mount -t drvfs '\\hyperv-host\ISO' /mnt/iso
export LAB_ISO_DIR=/mnt/iso
```

`qemu-img` cannot lock files on DrvFs; the stagers already convert images
in `/tmp` and then copy them to the share.

## 4. Validation checklist (first run)

Run these in order from `~/src` and note anything that fails:

1. **Preflight**: `dev-commons/bin/preflight.sh` → `ALL CLEAN`.
2. **Workstation helper**: `bash lab-kit/tests/lab-host.sh` → all passed
   (includes a real seed ISO with label `CIDATA`).
3. **Detection**: `bash -c 'source lab-kit/lib/lab-host.sh; lab_host_os; lab_iso_dir'`
   prints `wsl` and the ISO path you expect.
4. **SSH to the Hyper-V host**: `ssh <HV_USER>@<HV_HOST> 'pwsh -NoProfile -Command "Get-VM | Select Name,State"'`.
5. **Router**: `lab-router/scripts/stage-router-artifacts.sh ...`, then
   create the router VM (lab-router `README.md`).
6. **Fresh base images** (each stages, creates the VM, prepares it, and
   takes the golden checkpoint):
   - `samba-addc-appliance/lab/build-fresh-base.sh`
   - `smb-proxy-appliance/lab/build-fresh-base.sh`

   Check the new release files on each VM:
   `samba-addc-update status` / `smbproxy-update status`.
7. **VM gate**: the ten scenarios in `RELEASE-GATE.md` (pending lab checks
   for remediation sessions 01–04 are part of these runs).
8. **Update gate**: build the 0.5.0 bundles
   (`samba-addc-appliance/updates/build-bundle.sh`,
   `smb-proxy-appliance/updates/build-bundle.sh`), then T-UPG-1 and
   T-UPG-4 against lab units built from the same old images as the field
   units (`RELEASE-GATE.md` step 3).
9. **Export**: `lab/export-deploy-master.sh` in each appliance (VHDX; OVA
   only if `ovftool` is on `PATH` or `OVFTOOL` is set).

## 5. Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `error: lab-kit not found at ...` | Clone `lab-kit` next to the appliance repo, or set `LAB_KIT_DIR`. |
| `stage dir not mounted: /mnt/d/ISO` | WSL2 is not on the Hyper-V host, or the drive letter differs: set `LAB_ISO_DIR`. |
| `no ISO builder` | `sudo apt-get install xorriso`. |
| `$'\r': command not found` | The repo was cloned with CRLF endings: `git config core.autocrlf false`, re-clone. |
| Permission bits lost / scripts not executable | The clone lives under `/mnt/c`; move it into the WSL2 filesystem. |
| `ssh: connect to host localhost port 22` | OpenSSH Server not running on Windows, or mirrored networking is off (use the host's IP as `HV_HOST`). |
