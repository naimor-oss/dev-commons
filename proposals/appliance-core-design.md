# Appliance core — design draft

**Status**: draft, paired with [decisions/0002-appliance-core.md](../decisions/0002-appliance-core.md)
**Date**: 2026-05-08
**Owner**: Hooman Mehr

This is the supplemental design draft for the `appliance-core` ADR.
It carries:

1. Repo layout.
2. Lib contracts for the first three extraction targets.
3. Call-site map proving the contracts are right-sized.
4. Test-suite shape and lab scenario list for the blank image.
5. Migration plan (what lands in what order).
6. Naming + arch + version-pinning rules.

The ADR itself is a journal entry. This document is the
specification — it is expected to grow as more libs are extracted.

## 1. Repo layout

```text
appliance-core/
├── README.md                 # builder-facing entry; links to dev-commons/
├── AGENTS.md                 # vendor-neutral agent brief
├── CLAUDE.md                 # compatibility pointer to AGENTS.md
├── HANDOFF.md                # one-paragraph landing pointer
├── LICENSE
├── prepare-image.sh          # image-prep for the BLANK appliance
├── core-sconfig.sh           # the blank's TUI (system tools only, no product)
├── lib/                      # bash libs vendored into downstream appliances
│   ├── VERSION               # SemVer (e.g. 0.1.0); read by consumers
│   ├── detect-net.sh
│   ├── apt-helpers.sh
│   ├── hostname.sh
│   ├── netconfig.sh          # (later)
│   ├── console-wizard.sh     # (later)
│   ├── motd.sh               # (later)
│   └── README.md             # contract index, links to docs/lib-*.md
├── docs/
│   ├── SETUP.md
│   ├── LAB-TESTING.md
│   ├── RELEASE.md
│   ├── lib-detect-net.md     # full contract for detect-net.sh
│   ├── lib-apt-helpers.md
│   ├── lib-hostname.md
│   └── ...
├── lab/
│   ├── core.env
│   ├── run-scenario.sh       # thin wrapper around lab-kit
│   ├── stage-core-base.sh
│   ├── build-fresh-base.sh
│   ├── export-deploy-master.sh
│   ├── hyperv/               # hypervisor-specific helpers (Hyper-V first)
│   ├── scenarios/            # lab tests for the BLANK appliance
│   │   ├── smoke-prepared-image.sh
│   │   ├── hostname-change-survives-reboot.sh
│   │   ├── network-dhcp-to-static-and-back.sh
│   │   ├── update-flow-applies-kernel.sh
│   │   ├── update-count-converges-to-zero.sh
│   │   └── ptr-detection-after-rename.sh
│   └── keys/                 # SSH pubkeys for image bake-in (gitignored)
├── tests/
│   ├── README.md             # how + where bats runs
│   └── unit/
│       ├── detect-net.bats
│       ├── apt-helpers.bats
│       └── hostname.bats
├── dist/                     # release artifacts (gitignored)
└── test-results/             # raw .log gitignored, distilled .md tracked
```

Notes:

- Two-script pattern (`prepare-image.sh` + `core-sconfig.sh`) is
  preserved per `STYLE.md` §8. `lib/` is supporting material, not a
  third top-level script.
- `lib/<name>.sh` carries implementation; `docs/lib-<name>.md`
  carries the contract. Both live under `appliance-core/`. The
  contract document is authoritative when behavior is questioned.
- `lib/VERSION` is a single line containing the SemVer (e.g. `0.1.0`).
  Consumers read this at image-prep time; the consuming
  `prepare-image.sh` aborts if the version is outside the supported
  range it declares. Mechanism described in §6.

## 2. Lib contracts (first three)

Each contract has the same shape: **Provides** (what the lib exposes
and guarantees), **Excludes** (what callers must NOT push into the
lib), **Side effects**, **Inputs**, **Outputs**, **Failure modes**,
**Bash version**.

**Naming convention** (applies to every lib in this section and
every later one):

- All exported function names carry the `appcore_` prefix.
- All exported variable names carry the `APPCORE_` prefix.
- Internal helpers (only sourced within a lib) carry a leading
  underscore: `_appcore_…`. Consumers must not call these.

The prefix exists so a downstream appliance can grep its own files
to see which symbols come from the core and which are local.

### 2.1 `lib/detect-net.sh`

**Provides**:

- `appcore_detect_net_init` — populate exported variables
  `APPCORE_DET_IP`, `APPCORE_DET_GATEWAY`, `APPCORE_DET_DHCP_DNS`,
  `APPCORE_DET_DHCP_DOMAIN`, `APPCORE_DET_PTR_FQDN`,
  `APPCORE_DET_PTR_NAME`, `APPCORE_DET_PTR_DOMAIN`,
  `APPCORE_DET_EFFECTIVE_DOMAIN`. Idempotent. Live every call.
- `appcore_detect_net_write_cache <path>` — write current values to
  a file in the same `KEY="value"` shape the existing
  `samba-init-detected.env` uses, for callers that want a snapshot.
- `appcore_detect_net_load_cache <path>` — source a file written by
  the writer; refresh IP, gateway, PTR, DHCP-domain live (per the
  fix that just landed); leave the slow probes (AD-DC, DHCP-DNS) at
  cache values.

**Excludes**:

- AD-DC discovery via SRV records (Samba-only; lives in
  `samba-addc-appliance`).
- LDAP probes against any discovered DC.
- Anything that requires Samba-specific paths or databases.
- Static-IP planning or netplan rendering — that's `netconfig.sh`.

**Side effects**: read-only network probes; no writes outside an
explicit cache path argument.

**Inputs**: none. Reads `ip`, `resolvectl`, `dig` from `$PATH`.

**Outputs**: exported `APPCORE_DET_*` variables. Cache file when
`write_cache` is called.

**Failure modes**:

- `ip route show default` empty → `APPCORE_DET_IP` and
  `APPCORE_DET_GATEWAY` blank, function still succeeds.
- `dig +short -x` times out (5s bound) → `APPCORE_DET_PTR_*` blank,
  function still succeeds.
- The cache loader treats empty live results as "keep cached value"
  (transient flake protection). Non-empty live wins.

**Bash version**: appliance side, bash 5+. No mac-orchestrator use.

**Source**: extracted from `samba-addc-appliance/prepare-image.sh`
lines 1280-1356 (firstboot detection) + lines 1484-1538 (sconfig
load_detect_env). The `smb-proxy-appliance/prepare-image.sh`
counterpart at lines 893-915 is a degenerate subset; consolidating
upgrades that one for free.

### 2.2 `lib/apt-helpers.sh`

**Provides**:

- `appcore_apt_count_upgrades` — print `<total> <security>` to
  stdout. Counts via `apt-get --simulate dist-upgrade` so phased
  rollouts are excluded. `0 0` when offline.
- `appcore_apt_freshness_line` — print one-line freshness banner
  for image-prep logs / MOTD. Same source of truth as `count_upgrades`.
- `appcore_apt_run_full_upgrade` — `apt-get update && apt-get -y
  full-upgrade`. Returns 0 on success. After-effect: prints a
  `REBOOT REQUIRED` notice if `/var/run/reboot-required` exists.
- `appcore_apt_reboot_banner_line` — single line for MOTD/banner if
  reboot pending; empty if not. Caller decides where to render.

**Excludes**:

- Unattended-upgrades policy presets (manual / security / full
  automatic). That's an operator-policy choice; lives in each
  product's sconfig because the blacklist set differs per product
  (Samba blacklists samba/krb5; proxy blacklists smb-related, etc.).
- Mirror/source pinning, apt-cacher-ng integration, proxy config.
  All deployment-environment choices.

**Side effects**: `count_upgrades` and `freshness_line` are
read-only against the apt cache; they do not run `apt-get update`.
`run_full_upgrade` modifies the system. Caller must have already
run an `apt-get update` if it wants the freshest count.

**Inputs**: none.

**Outputs**: stdout. Exit codes per function (`run_full_upgrade`
inherits apt's exit code).

**Failure modes**:

- No network (`ip route show default` empty) → counts return `0 0`.
- `apt-get --simulate` parse fails → counts return `0 0` (caller
  treats as "I don't know" rather than "0 pending").

**Bash version**: appliance side, bash 5+.

**Source**: extracted from
`samba-addc-appliance/prepare-image.sh:1540-1559` and matching
`smb-proxy-appliance/prepare-image.sh:916-930`. The freshness line
logic is in `samba-addc-appliance/prepare-image.sh:1255-1281`.

### 2.3 `lib/hostname.sh`

**Provides**:

- `appcore_hostname_validate_short <name>` — return 0 if `<name>`
  is a valid NetBIOS short name (regex
  `^[a-zA-Z][a-zA-Z0-9-]{0,14}$`); else print rejection reason to
  stderr and return non-zero.
- `appcore_hostname_compose_fqdn <short> <domain>` — print FQDN.
  Empty `<domain>` → print `<short>` only.
- `appcore_hostname_apply <short> <domain> <ip>` — apply via
  `hostnamectl set-hostname`, write `/etc/hostname`, rewrite
  `/etc/hosts` safely (drop by IP and old short name, not by
  stale FQDN string), idempotent.
- `appcore_hostname_default_domain` — print the best-guess domain
  for an unprovisioned host (live DHCP search domain, then PTR
  domain, then current `dnsdomainname`). Empty when nothing is
  available.

**Excludes**:

- Post-provision rename guards. AD DC must refuse; SMB proxy can
  allow under most circumstances. The product sconfig wraps the
  apply call with its own state check.
- Realm/forest selection. AD-realm is a Samba concept handled in
  `samba-addc-appliance`'s domain operations.
- Anything that touches Kerberos keytabs, machine accounts, or
  SPNs.

**Side effects**: `apply` writes `/etc/hostname`, `/etc/hosts`, and
calls `hostnamectl set-hostname`. The other functions are pure.

**Inputs**: positional args. Reads `resolvectl`, `dig`,
`dnsdomainname` from `$PATH` for `default_domain`.

**Outputs**: stdout for the printers. Exit code for the validator.

**Failure modes**:

- `hostnamectl` failure → propagates non-zero.
- Bad `<short>` arg to `apply` → return non-zero before mutating.

**Bash version**: appliance side, bash 5+.

**Source**: extracted from
`samba-addc-appliance/prepare-image.sh:1693-1737` (firstboot wizard
`set_hostname`), the new
`samba-addc-appliance/samba-sconfig.sh:316-389` (`config_hostname`,
which just landed), and
`smb-proxy-appliance/prepare-image.sh:1239-1251` (firstboot
`set_hostname`). The smb-proxy version is the simplest; it gets
upgraded in-place to the shared contract.

## 3. Call-site map

Each row identifies a function in a current appliance file and
which lib it migrates to. The migration is a delete-and-call:
remove the local definition, source the lib, call the lib's
function. The product-specific wrapping (e.g. AD-DC discovery) stays
local.

| Current file | Function | Lines | Migrates to |
| --- | --- | --- | --- |
| `samba-addc-appliance/prepare-image.sh` | net detection block | 1280-1356 | `appcore_detect_net_init` + `appcore_detect_net_write_cache` |
| `samba-addc-appliance/prepare-image.sh` | `load_detect_env` | 1484-1538 | `appcore_detect_net_load_cache` |
| `samba-addc-appliance/prepare-image.sh` | `count_upgrades` | 1540-1559 | `appcore_apt_count_upgrades` |
| `samba-addc-appliance/prepare-image.sh` | freshness check | 1255-1281 | `appcore_apt_freshness_line` |
| `samba-addc-appliance/prepare-image.sh` | `set_hostname` | 1693-1737 | `appcore_hostname_*` (full set) |
| `samba-addc-appliance/prepare-image.sh` | `action_update` | 1817-1851 | `appcore_apt_run_full_upgrade` + product banner |
| `samba-addc-appliance/samba-sconfig.sh` | `config_hostname` | 316-389 | `appcore_hostname_*` + AD-provisioned guard |
| `samba-addc-appliance/samba-sconfig.sh` | `run_updates_now` | 601-635 | `appcore_apt_run_full_upgrade` + product banner |
| `smb-proxy-appliance/prepare-image.sh` | net detection block | 893-915 | `appcore_detect_net_init` + `..._write_cache` |
| `smb-proxy-appliance/prepare-image.sh` | `count_upgrades` | 916-930 | `appcore_apt_count_upgrades` |
| `smb-proxy-appliance/prepare-image.sh` | `set_hostname` | 1239-1251 | `appcore_hostname_*` (full set) |
| `smb-proxy-appliance/prepare-image.sh` | `action_update` | 1346-1365 | `appcore_apt_run_full_upgrade` + product banner |
| `smb-proxy-appliance/smbproxy-sconfig.sh` | `config_hostname` | 608-? | `appcore_hostname_*` |
| `smb-proxy-appliance/smbproxy-sconfig.sh` | `run_updates_now` | 646-667 | `appcore_apt_run_full_upgrade` + product banner |

13 call sites for the first three libs across both appliances.
Each migration is mechanical: delete-and-call. No call site
straddles two libs; no lib needs to know anything about the
specific product.

## 4. Test-suite shape

Two layers:

### 4.1 `tests/unit/*.bats` — pure-shell unit tests

Run on the appliance (the blank image's `golden-image` checkpoint),
not on the Mac. Bash 5+ is the appliance bash; mac orchestrator
bash 3.2 lacks `bats-core`'s assumed features and isn't worth
backporting for. The lab harness already has the SSH plumbing.

Coverage for the first three libs:

- **`detect-net.bats`** — known-input fixtures for `dig +short -x`
  and `resolvectl`, mocked via `PATH` overrides; assert that
  populated values match expectations across a network change
  (DHCP→static→DHCP).
- **`apt-helpers.bats`** — fixture an `apt-get --simulate dist-upgrade`
  output with phased and non-phased lines; assert
  `count_upgrades` returns the non-phased count. Fixture a
  `/var/run/reboot-required` and assert the banner line renders.
- **`hostname.bats`** — feed every adversarial input from the local
  unit harness used during the DFS-N validator development (single
  letters, NetBIOS-illegal chars, mDNS-conflict domains, etc.) to
  the validator and asserts each is rejected. Assert
  `compose_fqdn` produces the right string with and without a
  domain. Assert `apply` is idempotent (running twice with the
  same args does not produce duplicate `/etc/hosts` lines).

Each `.bats` file declares its own test data inline. No external
fixture dependencies.

Runner: `tests/run-unit.sh` ssh's into the lab VM, copies tests
+ libs to `/tmp/`, runs `bats tests/`, returns non-zero on any
failure. Wired up as a lab scenario `unit-tests` so it runs in
the same harness as everything else.

`bats-core` is added to the appliance's base-tools install
(`prepare-image.sh` §4) — one extra Debian package
(`bats` in trixie). The package is small (~80 KB) and stays in the
image. Operator-facing surfaces don't reveal it.

### 4.2 `lab/scenarios/*.sh` — integration scenarios for the blank image

Each scenario follows the lab-kit pattern (`pre_hook`,
`run_scenario`, `verify`, `post_hook`). Initial scenarios — chosen
to cover exactly the surfaces recent regressions hit:

| Scenario | What it proves |
| --- | --- |
| `smoke-prepared-image` | Blank image boots, MOTD renders, samba-init wizard reachable, no product service active. |
| `hostname-change-survives-reboot` | Operator changes hostname via wizard → reboot → init banner shows new short name, PTR detection live-refreshes when DHCP catches up. |
| `network-dhcp-to-static-and-back` | Operator pins DHCP lease as static → reboot → IP unchanged. Operator reverts to DHCP → reboot → IP unchanged. No `/etc/hosts` divergence. |
| `update-flow-applies-kernel` | Pin a specifically-old `linux-image-cloud-amd64` via `apt-mark hold` + `apt-get install <oldver>`, drop the hold, run `[U] Update OS`. Verify the kernel metapackage is now at the latest version Debian ships. The "artificially stale" mechanic is operator-controlled (apt-mark + downgrade), not network-poisoned. |
| `update-count-converges-to-zero` | After a successful `full-upgrade`, the banner count is 0 (not stuck on phased). |
| `ptr-detection-after-rename` | Same as `hostname-change-survives-reboot` but specifically asserts the PTR field in the banner reflects the new name once dnsmasq has it. |

Cross-environment validation: same scenarios run against the
exported `dist/blank-appliance-vYYYY.MM.DD-amd64.{vhdx,qcow2,...}`
artifacts on each hypervisor in `SUPPORTED-ENVIRONMENTS.md`. The
scenarios stay environment-agnostic; the runner picks the artifact.

## 5. Migration plan

Phase ordering — extract one lib + migrate one appliance at a time.
Both appliances stay releasable throughout.

**Why this order**:

1. `detect-net` first — read-only probes, no system mutations,
   lowest risk. If the lib pattern is wrong, we find out before
   touching anything that writes.
2. `hostname` second — this is the *live* regression operators
   are hitting right now (the "stuck on lab.test" report from the
   field-test pass). Migrating it second validates the lib pattern
   against a known-bad surface. If post-extraction the same
   regression can't recur, the pattern is sound.
3. `apt-helpers` third — well-understood code (we fixed it twice
   this session: full-upgrade verb + phased-rollout count). Lowest
   marginal information; extract last when the pattern is proven.

| Step | What | Validation |
| --- | --- | --- |
| 1 | Create `appliance-core/` repo skeleton (template-derived); push to `naimor-oss/appliance-core`. | `git clone` builds the placeholder image. |
| 2 | Land `lib/detect-net.sh` + `docs/lib-detect-net.md` + unit tests + `lib/VERSION=0.1.0`. | `tests/run-unit.sh` green. |
| 3 | Migrate `samba-addc-appliance/prepare-image.sh` and `samba-sconfig.sh` to consume `detect-net.sh`. | `lab/run-scenario.sh dfs-namespace` and `join-dc` still pass. |
| 4 | Migrate `smb-proxy-appliance` likewise. | proxy lab scenarios still pass. |
| 5 | Land `lib/hostname.sh` + tests; bump `lib/VERSION=0.2.0`. | unit tests green. |
| 6 | Migrate both appliances to consume `hostname.sh`. | scenarios still pass on both sides; the recent stale-realm regression cannot recur. |
| 7 | Land `lib/apt-helpers.sh` + tests; bump `lib/VERSION=0.3.0`. | unit tests green. |
| 8 | Migrate both appliances to consume `apt-helpers.sh`. | scenarios still pass on both sides. |
| 9 | Build + export `appliance-core` blank image. Run all `lab/scenarios/*` against it across the SUPPORTED-ENVIRONMENTS matrix. | All scenarios green; freshness/PTR/update regressions stay caught. |
| 10 | Bump `lib/VERSION=1.0.0`, tag `appliance-core` v1.0.0, both appliances declare supported range. | First stable core release. |

After Phase 10: subsequent libs (`netconfig`, `console-wizard`,
`motd`) follow the same one-lib-at-a-time pattern.

## 6. Naming, arch, and version-pinning

**Repo name**: `appliance-core` (builder-facing). Operator-facing
artifact name is neutral — initial proposal `debian-13-base-server`
or `naimor-base-appliance`; final wording resolved before the v1.0.0
tag.

**Filenames carry the arch from day one**:

```
appliance-core/dist/appliance-core-vYYYY.MM.DD-amd64.{vhdx,qcow2,vmdk,ova}
```

Per `STYLE.md` §15, an arm64 sibling slots in as
`*-arm64.{vhdx,...}` without rename.

**Versioning + identity between core and consumers**:

Two layers, with different jobs:

1. **SemVer for documentation and operator-readable identity**:
   `appliance-core/lib/VERSION` is a single line (`0.3.0`).
   Surfaced in MOTD's builder-comment block, in `RELEASE.md`, and
   in commit messages on both sides. Lets a human ask "which core
   am I running" and get a recognisable answer. Core may break
   compatibility on a major bump only; minors are additive,
   patches are bug-fixes only. SemVer's normal rules.

2. **Commit hash for build-time identity and regression hunts**:
   each consumer's `prepare-image.sh` records the actual git
   commit hash of `appliance-core` at image-prep time:

   ```bash
   appcore_record_provenance() {
       local hash
       hash=$(git -C ../appliance-core rev-parse HEAD 2>/dev/null \
              || echo "unknown")
       printf 'appliance-core %s\n' "$hash" \
           > /etc/appliance-core.provenance
       chmod 0644 /etc/appliance-core.provenance
   }
   ```

   The file is written into the image and stays there. A six-month
   old regression can be traced to a specific core commit without
   guesswork.

The SemVer is informational: a hand-edited working tree happily
reads `0.3.0` even though the libs on disk no longer match the
0.3.0 release. The commit hash is the load-bearing identity. We
record both because they answer different questions ("what
release?" vs "which exact bytes?").

We do NOT implement an `APPLIANCE_CORE_MIN/MAX` range check that
gates the build. Such a check looks defensive but only catches
a specific failure mode (operator runs prep against a wildly
mismatched core version with no other signals); the cost is more
machinery than it's worth at this scale. A single CI smoke test
that exercises consumers against tip-of-`appliance-core` before
release catches the same regressions, more reliably.

**Boundary line on operator-facing strings**:

- The string `appliance-core` MUST NOT appear in: MOTD, login
  banners, `core-sconfig` title bar, OVA metadata names, log line
  prefixes that show in routine ops.
- It MAY appear in: source comments, commit messages, builder docs,
  `docs/RELEASE.md`, hashes file headers.

A test harness file `tests/no-leak.sh` greps the staged image's
`/etc/`, `/usr/local/`, `/var/lib/`, and OVA descriptor for the
forbidden strings and fails the build if any leak.

## 7. Open questions

These are deferred until the first migration is in flight:

- Exactly which directory under `/usr/local/` holds the vendored
  libs at runtime. Current proposal: `/usr/local/lib/appliance-core/`,
  matching the FHS pattern.
- Whether `core-sconfig.sh` is a symlink to a generic `sconfig`
  binary or stays as a copy per appliance. Current lean: per-appliance
  copy, since each product's sconfig diverges product-side anyway.
- The future product-base path (chained images via differencing
  VHDX) — whether to design for it now (image-prep flag like
  `--from-core <path>`) or defer entirely. Current lean: defer; the
  test-harness path doesn't depend on it.
- arm64 cross-build mechanics — `qemu-user-static` on the Mac
  orchestrator vs native arm64 build host. Explicitly a v2.0
  milestone; does not block v1.0. Filenames and paths are
  arch-tagged today (per `STYLE.md` §15) so the slot is reserved.
