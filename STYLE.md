# Project Style and Governing Rules

This document codifies the day-to-day coding, scripting, and documentation
conventions for the sibling-repo family under `Debian-SAMBA/`
(`dev-commons`, `lab-kit`, `lab-router`, `appliance-core`,
`samba-addc-appliance`, `smb-proxy-appliance`, plus future siblings). It is meant for future
maintainers and for any agent — local, vendor, or senior — picking up work
here.

**Read [`CONTEXT.md`](CONTEXT.md) first.** The rules below are
defenses against specific failure modes the project has paid for or
expects to face; without that context they look arbitrary.

It complements, rather than duplicates:

- [`AGENTIC-DEVELOPMENT.md`](AGENTIC-DEVELOPMENT.md) — covers *who*
  should do *what kind of work*; this file covers *how the work is
  shaped* once started.
- [`REPO-SPLIT.md`](REPO-SPLIT.md) — covers *which sibling owns
  what*; this file covers *how to write code/docs in any of them*.

The rules below are observations distilled from the existing tracked code.
When in doubt, search the existing repos for a precedent before inventing
one.

## Mission, in one sentence

Build small, sharply-scoped Debian appliances and a lab harness that exercises
them, with the appliance images themselves remaining vendor-, realm-, and
credential-neutral so they can be shipped and re-imported into any
hypervisor without surprise.

Everything below is in service of that.

## 1. Repository layout and the sibling assumption

Each repo is independently versioned, lives next to the others, and assumes
the others can be found via relative paths:

```text
Debian-SAMBA/
  dev-commons/             this repo — meta + tooling + templates
  lab-kit/                 reusable runner + helpers
  lab-router/              reusable router VM builder
  appliance-core/          shared runtime libraries + blank test appliance
  samba-addc-appliance/    AD DC appliance + its scenarios
  smbproxy-session-vfs/    private Samba VFS component + compatibility builds
  smb-proxy-appliance/     SMB1<->SMB3 proxy appliance + its scenarios
```

See [`REPO-SPLIT.md`](REPO-SPLIT.md) for a per-repo description and
the full dependency map.

Per-repo top-level structure (where applicable):

| Path | Purpose |
| --- | --- |
| `README.md` | User-facing entry. Leads with a "Where do I start?" table. Repository-map table for files. |
| `AGENTS.md` | Authoritative agent brief. Vendor-neutral. |
| `CLAUDE.md` | Thin compatibility pointer back to `AGENTS.md`. |
| `HANDOFF.md` | One-paragraph landing pointer to the maintained docs. Not a doc itself. |
| `docs/` | Long-form: setup, lab-testing, release, repo-split, style, agentic-development. |
| `lab/` | Orchestration: env file, runner wrapper, scenarios, hypervisor helpers, cloud-init templates, keys. |
| `prepare-image.sh` / `<name>-sconfig.sh` | Two-script appliance pattern: image prep + sconfig TUI/CLI. |
| `dist/` | Release artifacts (gitignored). |
| `test-results/` | Scenario evidence (raw `.log` gitignored, distilled `.md` tracked). |

Dependency direction is enforced by convention: appliances depend on
`lab-kit` and `lab-router`; product appliances vendor `appliance-core`;
the lab and router repos do not know product appliances exist.

## 2. `.gitignore` conventions

Always ignore:

- macOS / SMB-share crud (`.DS_Store`, `._*`, `.AppleDouble`, etc.)
- Private agent dirs: `.claude/`, `.codex/`, `.cursor/`, `.continue/`, `.aider*`
- Raw scenario transcripts: `test-results/*.log`. Distilled findings (`.md`) stay tracked.
- Release artifacts: `dist/`
- Operator SSH pubkeys baked into images: `lab/keys/*` with `!lab/keys/README.md`
- Anything credential-shaped: `*creds*`

For credential-shaped files, always add positive exceptions for:

- The original sketch in `docs/sketch-*` (for historical reference)
- Tracked `.example` templates (e.g. `!lab/backend-creds.env.example`)

When you add a new gitignore entry, also add the matching `!exception`
on the same commit if the file pattern would otherwise eat tracked content.

## 3. Documentation

Tracked Markdown is where durable knowledge lives. Private agent notes
(.claude/, etc.) are short-lived working memory only.

Style:

- Lead with a one-line purpose. Then a short "where do I start" table for
  any nontrivial doc.
- Tables (`| ... | ... |`) for navigational content; prose for rationale.
- Explain **why**, not just **what**. The codebase already says what.
- Cross-repo references use relative paths
  (`../samba-addc-appliance/docs/REPO-SPLIT.md`), not absolute ones.
- Default to ASCII unless there's a reason. Symbols like `↔` are fine in
  product names ("SMB1↔SMB3 Proxy Appliance"); avoid in machine-parsed
  content.
- Don't write "how the code is structured" — `git ls-files` and a careful
  read tell you that. Write "why this code is the shape it is".
- Never duplicate setup instructions across docs. Link.

`README.md` shape:

1. One-paragraph purpose
2. "Where do I start?" table mapping intent → doc
3. Sibling-repos paragraph
4. Repository-map table
5. "Intended Workflow" or "Status" section if applicable

`HANDOFF.md` is a one-screen pointer to the maintained docs. It is **not**
the place to put information.

## 4. Bash style

Shebang and safety:

- `#!/usr/bin/env bash` always. Never `/bin/sh` for non-trivial scripts.
- `set -euo pipefail` for executables.
- Exception: scripts that intentionally tolerate non-zero from a TUI
  (whiptail returns non-zero on Cancel, for instance) may relax to
  `set -uo pipefail` and check exit codes locally. The `smbproxy-sconfig.sh`
  header is the precedent.

Layout:

- Top-of-file banner with `#====` rule, title, purpose paragraph, usage
  examples, and a maintainer note when the script has subtle invariants
  (cf. `prepare-image.sh`).
- Number major sections (`# 1. ...`, `# 2. ...`) for any script over ~150 lines.
- Functions defined before use; `local` for variables in functions.
- `command -v X >/dev/null || die "..."` for prereq checks at the top.
- Standard helpers when applicable:
  - `die()` — print to stderr and exit non-zero.
  - `say()` — timestamped progress line: `--- [HH:MM:SS] message`.
  - `step()` — visually distinct section header for long pipelines.
- Heredoc tags meaningful and uppercased: `EOF`, `MOTDEOF`, `FBEOF`,
  `BLEOF`, `NPY`. Quote the opening tag (`<<'EOF'`) when you don't want
  variable expansion.

Comments:

- Inline comments explain **why a value or technique was chosen**, not
  what the line does. The user will read both your code and your comments;
  add only what they couldn't infer from the code.
- For workarounds, see §10.

Portability:

- macOS bash 3.2 is the orchestrator runtime. Don't use `${var^^}` or
  `${var,,}` in code that runs on the Mac side; pipe through `tr` instead.
  See `lab/scenarios/join-domain.sh` for the precedent.
- `find . -name '*.sh'` rather than `find / ...`; never scan from `/`.

Sourced files (scenarios):

- Scenario files under `lab/scenarios/` are *sourced* by the
  generic runner, not executed directly. They are function libraries
  that define `pre_hook` / `run_scenario` / `verify` (see §7), so
  they intentionally **do not** carry shebangs or `set` lines —
  doing so would either trip the runner's own `set -euo pipefail`
  during the source step or be inert noise. The same applies to any
  other shell file documented as "sourced" rather than "executable".

## 5. Hypervisor-orchestration code

Hyper-V is the **primary** build/test host today, but it is not the only
target — see `SUPPORTED-ENVIRONMENTS.md` for the full matrix
(Parallels, Apple Virtualization, Synology VMM, Pi/IoT bare-metal as
near-term additions). Conventions below are written for the Hyper-V
case because it's the precedent; equivalents for other backends should
follow the same shape (heredoc'd remote scripting, helper script per
operation, throw on missing prereqs) regardless of which CLI tool
they wrap.

### Driving Hyper-V from the Mac

When the Mac drives a Hyper-V host via SSH, prefer the
`pwsh -File - <<'PWSH'` heredoc pattern over `pwsh -Command "..."`:

```bash
ssh nmadmin@server pwsh -File - <<'PWSH' 2>&1 | tail -10
$adapterName = 'vEthernet (Lab-NAT)'
Enable-NetAdapter -Name $adapterName -Confirm:$false
PWSH
```

Reasons (all paid for in this project):

- `pwsh -Command` mishandles parentheses, wildcards, and embedded quotes
  when wrapped in double-quoted SSH arguments.
- The heredoc gives you natural multi-line scripting and avoids the
  "build a giant string and pray" trap.

Helper PowerShell scripts (`<appliance>/lab/hyperv/*.ps1`):

- `#Requires -RunAsAdministrator` and `#Requires -Modules Hyper-V` at top.
- Comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`,
  `.EXAMPLE`).
- Throw on missing prereqs ("Switch '$x' not found. Build the lab
  router first.").
- `Write-Step` / `Write-OK` for output; reuse from existing scripts.

### Other backends (when added)

Equivalent helper scripts for non-Hyper-V backends should mirror this
shape. Probable directory layout when each lands:

- `<appliance>/lab/parallels/*.sh` — `prlctl` wrappers
- `<appliance>/lab/apple-virt/*.sh` or `*.swift` — `tart` / Virtualization
  framework wrappers
- `<appliance>/lab/synology-vmm/*.sh` — Synology VMM API wrappers
- `<appliance>/lab/iot/` — bare-metal Pi imaging tools (different
  pattern; see §8)

Promote the cross-backend bits (e.g. a generic "wait for SSH at IP X
through jump host Y" helper) to `lab-kit/` once the second backend
needs them. Don't pre-abstract.

## 6. Cloud-init / netplan templates (virtualized pattern)

Applies to **virtualized** appliances using the cloud-init NoCloud
seed pattern. The bare-metal IoT pattern uses different mechanisms
(see §8 Pattern B).

Conventions used by the staging scripts:

- Placeholders are `@@TOKEN@@`, sed-substituted by the stager.
- Multi-line placeholders (e.g. `@@SSH_KEYS_BLOCK@@`) are awk-substituted
  via `ENVIRON[]` because sed can't insert multi-line content cleanly.
  See `lab/stage-proxy-base.sh` and `lab/stage-samba-base.sh`.
- Match interfaces by MAC, not by name. The cloud image's
  predictable-naming gives different names per hypervisor (`eth0` on
  Hyper-V, `ens3` on QEMU, `enp1s0` on KVM, `ens33` on VMware).
- Always set `dhcp-identifier: mac` on DHCP-using stanzas. Without it,
  systemd-networkd's default DUID client-id breaks dnsmasq MAC reservations.
  See `lab/templates/cloud-init/network-config.tpl`.
- NICs that are wired but don't have a DHCP server (e.g. LegacyZone)
  must NOT be listed in the netplan, OR if listed must be marked
  `optional: true`. Otherwise systemd-networkd-wait-online blocks boot.
- The first runcmd line of every per-VM seed should
  `touch /etc/cloud/cloud-init.disabled` so cloud-init becomes a no-op
  on subsequent boots.

## 7. Lab scenarios

Every scenario file under `lab/scenarios/` defines:

| Function | Required | Purpose |
| --- | --- | --- |
| `run_scenario` | yes | The action under test. |
| `verify` | yes | Assert final state, return non-zero on failure. |
| `pre_hook` | optional | Idempotent setup (cleanup, prerequisites). |
| `post_hook` | optional | Evidence collection or cleanup after verification. |

These functions take advantage of helpers exported by the `lab-kit` runner:
`ssh_vm`, `ssh_host`, `scp_to_vm`, `say`, `step`, plus the `LAB_VM_*` /
`LAB_HV_*` env vars.

Composing scenarios:

- Factor the actual work into `do_*` functions (e.g. `do_join_domain`,
  `do_configure_backend`). `pre_hook` and `run_scenario` should be thin
  wrappers that call them.
- Downstream scenarios `source` upstream ones to pick up the `do_*`
  helpers, then redefine `pre_hook`/`run_scenario`/`verify`. The runner's
  source-then-call ordering makes the latest definition win.
- For end-to-end composition that *reuses* the upstream verify, capture
  it before redefining: `eval "$(declare -f verify | sed '1s/^verify/_upstream_verify/')"`.

`verify` discipline:

- Print evidence (`systemctl is-active`, `mount | grep cifs`, `nft list ruleset`,
  etc.) **before** the pass/fail decision. The transcript is the artifact.
- Assert final state, not exit codes.
- Use `local rc=0` and `... || rc=1` per check; `return "$rc"` at the end.

`pre_hook` discipline:

- Idempotent: re-running the scenario must not break.
- Where AD or similar shared state needs cleanup, support `--no-cleanup`
  (skip) and `--dry-cleanup` (inspect-only) by reading
  `SC_SKIP_CLEANUP` / `SC_DRY_CLEANUP`. The runner wrapper translates the
  flags into env vars.

Parameters:

- All scenario knobs are `SC_*` env vars with sane defaults that track
  the lab's expected state.
- Credentials never hardcoded; read from env (or sourced gitignored file
  for backend creds — see §9).

## 8. The two-script appliance pattern + image-preparation philosophy

Each appliance has exactly two scripts, regardless of whether it
targets virtualization or bare-metal:

- `prepare-image.sh` — runs once on a fresh Debian install. Vendor-,
  realm-, credential-neutral. Produces a host-agnostic master image.
- `<name>-sconfig.sh` — whiptail TUI plus headless CLI. Owns every
  per-deployment decision (realm, DC IP, share, credentials, NIC
  roles, etc.).

`prepare-image.sh` rules apply universally:

- **No realm, DC IP, share name, or credentials baked in.** They belong
  in sconfig prompts. Skeleton `krb5.conf` ships with `YOURREALM.LAN`
  precisely so the smoke test can assert "no deployment-specific values
  baked in".
- chrony skeleton ships with **no NTP servers** — sconfig points at the
  domain time source after join.
- `/etc/samba/smb.conf` is **not** present in the prepared image. sconfig
  writes it after a join.
- Defensive workarounds for known kernel/firmware bugs (e.g. ixgbevf
  blacklist) belong here, with FIXME blocks per §10 and operator-visible
  warnings per the same §.

The two appliance patterns differ in how the image is delivered and
booted; section §6 (cloud-init) covers Pattern A, the rest of this
section sketches the differences.

### Pattern A — virtualized (cloud-init seed + base VHDX/qcow2)

This is the pattern in use today (`samba-addc-appliance`,
`smb-proxy-appliance`).

- Hypervisor guest agents are pre-staged offline (cache directory of
  `.deb` files, one subdirectory per hypervisor); a `firstboot` service
  detects the actual host on first boot and `dpkg -i`'s the matching
  one, then deletes the rest. This is what makes the image
  host-agnostic across Hyper-V / Parallels / Apple Virtualization /
  Synology VMM / KVM / VMware.
- Two snapshots per build:
  - `deploy-master` — host-agnostic, **post-prepare-image, pre-firstboot**.
    **Ship this.**
  - `golden-image` — Hyper-V tailored, post-firstboot. Lab-only, used
    by lab scenarios.
- `build-fresh-base.sh --deploy-only` exists precisely because dist-only
  builds shouldn't risk Hyper-V tailoring contaminating the snapshot
  they will export.
- Release pipeline (`export-deploy-master.sh`) produces vhdx + qcow2 +
  vmdk + ova + SHA256SUMS so any of the supported environments can
  consume the artifact natively.

### Pattern B — bare-metal IoT (forthcoming, sketch only)

This pattern is **not yet implemented**. When the first IoT appliance
lands, the conventions will fork from Pattern A in roughly these
ways:

- Image delivery is SD/eMMC/NVMe, not VHDX. Build flow is
  pi-gen-derived or `debian-installer` preseed, not `qemu-img convert`.
- No hypervisor; no guest-agent cache. The `firstboot` service still
  exists but does hardware detection (which Pi model, which
  peripherals) instead of hypervisor detection.
- No two-snapshot dance — the analogue of `deploy-master` is the
  written image; the analogue of `golden-image` doesn't apply.
- Networking: usually single Ethernet + maybe Wi-Fi; the dual-NIC
  conventions in §6 don't apply directly.
- The `<name>-sconfig.sh` TUI runs on the device's serial console
  (or HDMI + USB keyboard) instead of via SSH-jump-through-host.

The two-script split (`prepare-image.sh` + `sconfig`), the
credential-neutral master image, the FIXME discipline, and the
operator/builder boundary all carry over unchanged. When the first
IoT appliance is built, the pattern-specific conventions will
solidify and this section gets a proper §6B sibling.

### Architecture: amd64 today, arm64 within ~6 months

Today every shipped image is amd64. Per `CONTEXT.md`, arm64 is
inevitable on a near horizon (Apple Silicon for local AI inference,
ARM-based Edge AI / IoT hardware).

Forward-compat rules for code being written today:

- Don't bake `amd64` into filenames, paths, or hard-coded assumptions
  where `<arch>` would do. Where naming `amd64` *is* meaningful
  (e.g. the cached `debian-13-genericcloud-amd64.qcow2`), include the
  arch in the filename so an `arm64` sibling is unambiguous.
- Stagers should accept an arch parameter even if today only `amd64`
  is implemented. Future-proof the interface; defer the
  implementation.
- The OVA's `guestOS = "debian12-64"` and similar VMware identifiers
  will need an arm64 variant when the time comes; track at OVA-build
  time, not now.

## 9. Credentials

Layered defenses:

1. **`*creds*` is gitignored**, with positive exceptions for the
   historical sketch and for tracked `.example` templates only.
2. **Passwords flow via stdin (`--pass-stdin`)** so they don't appear in
   process listings on the VM.
3. **Mode 0600, owned by root** for any creds file landing on disk
   (e.g. `/etc/samba/.legacy_creds`).
4. **Backend creds come from a sourced file**:
   `lab/run-scenario.sh` auto-sources `lab/backend-creds.env` (gitignored
   by `*creds*`) before invoking the scenario. A tracked
   `.example` template documents the format.
5. **Scenarios MUST NOT contain backend passwords.** The historical sketch
   (`docs/sketch-*.sh`) preserved the original credentials for reference;
   nothing else gets to.

Lab passwords (`P@ssword123456!` for `LAB\Administrator`, etc.) appear in
scenarios because the lab itself is disposable and isolated. Production
credentials never go in scenarios.

## 10. Defensive workarounds and FIXME tracking

When a workaround is shipped (e.g. blacklisting `ixgbevf` for the
SR-IOV-VF kernel panic), it carries a `FIXME(remove-when-fixed)` block
that documents:

1. **What is broken** — the specific symptom, with version coordinates
   precise enough to verify against in the future (kernel version,
   firmware version, hardware combo).
2. **Why this workaround is safe in our context** — i.e. why we can
   suppress the broken thing without breaking what we actually care about.
3. **How to remove or improve it** — the conditions under which the
   workaround can be deleted, and the link/issue/keywords to track.

Both the script section comment and any installed config file (e.g.
`/etc/modprobe.d/smbproxy-blacklist-ixgbevf.conf`) carry the FIXME.

When a workaround is invisible at runtime (a blacklist, a disabled
service, a special mount option), surface it in the **MOTD** so future
operators know what's been disabled and why. The MOTD piece must be
silent when the workaround is not currently in effect — a banner that
fires when nothing is wrong gets ignored.

## 11. Diagnostics and evidence

- Every scenario, build, and export pipeline writes a transcript to
  `test-results/<name>-<timestamp>.log`.
- `say` and `step` exist so that transcripts are scannable.
- When a build fails, the transcript should contain enough info to
  diagnose without re-running. Print state before transitions
  (e.g. `lsblk` before mount, `systemctl is-active` before restart).
- For ambient state checks (network reachability, file presence), accept
  noisy output as the cost of debuggability.

## 12. Git workflow

- `main` as the default branch on every repo.
- No remote until the first commit makes the repo coherent on its own.
  ("Make each repo useful from its own README before pushing.")
- Commits are focused. Subject ≤ 70 chars, imperative mood.
- Body explains **why**. Future-you reads commit bodies; nobody reads
  diff-only commits.
- `Co-Authored-By` for AI-agent contributions. Use the model identifier
  the harness gave you.
- Don't push from automation. Operator pushes when ready.
- For changes that span sibling repos (e.g. adding a dnsmasq reservation
  in `lab-router` that `smb-proxy-appliance` will rely on), commit them
  in dependency order: producer first, then consumer.

## 13. Risk handling and operator confirmation

Before taking any action with material blast radius, pause and confirm.

Always confirm:

- Creating, destroying, or modifying VMs.
- Modifying live infrastructure (router config, dnsmasq state).
- Pushing branches to a remote.
- Anything irreversible.

Don't confirm:

- Local file edits.
- Git operations local to your working tree.
- Tests / dry-runs.

When you do take risky action, name what changed and how to undo it.
The user should never have to ask "what did you just do?".

When you encounter an obstacle, diagnose root cause rather than bypass.
`--no-verify`, `--force`, `git reset --hard`, etc. are not shortcuts;
they're escape hatches for when you understand what they break.

## 14. Empirical priority

Two rules that override everything else when they conflict with
"convention":

1. **Verify before claiming.** A script that's "designed to work" but
   has never been run is unfinished. Run it. Hit the bug. Fix it. The
   commit message can then say it works because it does.
2. **Test in a different environment before declaring host-agnostic.**
   The whole point of the `deploy-master` snapshot is that it boots
   somewhere else. The `ixgbevf` panic was found this way; it would
   never have surfaced inside the build lab.

## 15. The builder / operator boundary

This is a load-bearing rule. See `CONTEXT.md` §"the boundary that matters
most" for the full narrative; the short form here.

Two distinct audiences exist for this work:

- **Builders / maintainers** — the owner, AI agents, future trusted
  internal contributors. See *everything*: source repos, build pipeline,
  this style guide, the appliances' custom-built nature, FIXMEs.
- **Operators** — future outsourced part-time IT helpers. See
  *only* the deployed appliance and any monitoring/runbook around it,
  framed as standard system administration of a Debian Linux server.

Anything an operator's eye reaches must read as boring system admin.
Avoid words like "custom", "in-house", "tailored", "appliance",
"bespoke", or anything that flags the special-sauce nature, in:

- Appliance MOTDs and login banners
- `<name>-init` console wizard text
- Log-line prefixes that show in routine ops
- Monitoring dashboard names and alert text
- Operator-facing runbooks

It's fine — actually preferred — for builder-facing surfaces (this
doc, source comments, commit messages, `AGENTS.md`) to say what they
mean. The full context lives in tracked docs, not in operator-facing
copy.

When adding a new banner, MOTD entry, log line, or doc:

> *Is this in front of an operator?*  If yes, write it boring.
> If no, write it useful.

When auditing existing code, this is a routine flag: places where
operator-visible text reveals the appliance's nature without
operational reason are deviations and should be softened.

## 16. Process patterns to apply, not memorize

- **Plan before doing** for anything beyond ~3 steps. A `TaskList` is
  cheap.
- **Compose, don't duplicate.** The scenarios chain via source +
  function override; the appliances depend on `lab-kit` + `lab-router`;
  the dist OVA is built from the same `deploy-master` that the lab
  scenarios run against.
- **Update the source of truth and the live state together.** When a
  config change needs to apply now (e.g. a dnsmasq reservation), edit
  the YAML, re-stage, and also push the change to the running router.
  The live override file should reference the source-of-truth commit
  so future maintainers can see how to remove it.
- **One repo, one concern.** `lab-kit` doesn't know about Samba.
  `lab-router` doesn't know about either appliance. Appliances don't
  embed their lab harness in `prepare-image.sh`. `dev-commons` doesn't
  ship runtime code.
- **Promote up, don't propagate sideways.** When a pattern shows up in
  two siblings in similar shape, promote it to `dev-commons/template-*`
  or to `lab-kit/`. Don't copy it to the third sibling.

## What this document is not

- Not a how-to. The how-to is in each appliance's `docs/SETUP.md` and
  `docs/LAB-TESTING.md`.
- Not a multi-agent process guide. That's
  [`AGENTIC-DEVELOPMENT.md`](AGENTIC-DEVELOPMENT.md).
- Not the project narrative. That's [`CONTEXT.md`](CONTEXT.md).
- Not the per-repo description. That's [`REPO-SPLIT.md`](REPO-SPLIT.md).
- Not exhaustive. Add a section here when a recurring pattern emerges.
  Don't add a section for one-off design choices — those belong in code
  comments at the relevant file.
