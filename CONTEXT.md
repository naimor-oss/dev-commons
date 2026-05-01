# Project Context

This file is the one-page narrative of *why* this project shaped the way it
did. Read it before reading any of the rule documents (`STYLE.md`,
`AGENTIC-DEVELOPMENT.md`, `REPO-SPLIT.md`) — those documents make sense
only if you know what they're protecting against.

## The owner's situation

Solo operator running a small metal fabrication shop. Builds custom
in-house tooling — Linux appliances, lab harnesses, AI-assisted dev
workflows — to solve specific blocking needs that off-the-shelf or SaaS
offerings either don't address or don't address well at this scale.

Working primarily with AI agents (Claude Code et al.) as collaborators
today. **2-9 month outlook**: partially outsourcing IT operations to
remote part-time helpers.

## Why discipline matters here

The owner's natural mode is "solve the immediate blocker, ship it,
move on." This works until it doesn't — and the past has shown that
shortcuts come back to bite hard, especially around:

- **Lab-specific values baked into shipped artifacts** (realm, IPs,
  credentials, hypervisor assumptions) that look fine until the
  artifact is moved to a different environment and silently behaves
  wrong.
- **Workarounds that survive past their cause**, with nobody
  remembering why they exist or whether they're still needed.
- **Documentation that drifts from reality**, leaving the operator
  six months later with no usable map of what they built.

So `STYLE.md`, the FIXME discipline, the host-agnostic deploy-master
snapshot, the cross-env testing rule, the sibling-repo split — these
exist specifically to defend against the failure modes the owner has
already paid for.

The rule of thumb: **meet the immediate need well, but don't take
shortcuts that close future doors.** Closing doors early is the
specific failure mode this project structure defends against.

## The boundary that matters most: builders vs operators

Two distinct audiences for this work, and the boundary between them
is load-bearing:

### Builders / maintainers (this is who reads this file)

- The owner
- AI coding agents
- Future trusted internal contributors

This audience sees:

- All sibling source repos (`dev-commons`, `lab-kit`, `lab-router`,
  `<appliance>-appliance`)
- The build pipeline
- Lab credentials (lab-only, intentionally disposable)
- The internal narrative — i.e. that these are custom-built
  appliances tailored to specific needs

### Operators (the future outsourced helpers)

- Remote part-time IT helpers contracted for routine monitoring and
  maintenance

This audience sees:

- The deployed appliance (SSH access, monitoring dashboards, the
  appliance's own MOTD/UI)
- Operations runbooks, framed in standard system-administration
  language
- Whatever incident workflow the owner sets up

This audience does **NOT** see:

- The dev-commons repo or any sibling source repo
- The build pipeline
- The lab harness
- Any document that describes the appliance as "custom-built"

### Why the boundary

Outsourced IT helpers tend to spook when they realize a small business
is running custom in-house infrastructure rather than off-the-shelf or
SaaS-promoted solutions. Spooked helpers escalate, ask for more
involvement, push for replacement with their preferred stack — none
of which serves the small-business use case the appliances exist to
serve.

The mitigation isn't dishonesty; it's **framing**. From the operator
side, the deployed appliance is a Debian Linux system running Samba
and supporting services. That description is true and complete for
their job. The fact that it was built in-house rather than purchased
is a procurement detail, not an operational one.

### What this means for our code and docs

- **Operator-facing surfaces** (appliance MOTD, banners, console
  wizard text, log-line prefixes, monitoring dashboard names) should
  read as straightforward system-admin language. Avoid "custom",
  "in-house", "appliance", "tailored", or anything that flags
  bespoke nature without operational reason.
- **Builder-facing surfaces** (this repo, AGENTS.md, source
  comments, commit messages, `STYLE.md`) say what they mean. The
  full context lives here.
- When adding a new banner/MOTD/log line, ask: *is this in front of
  an operator?* If yes, write it boring. If no, write it useful.

## Hardware and platform reality

The project lives in an environment with multiple hypervisors and
target architectures, both today and on a credible near-term
roadmap. The implication: **assumptions about "the host" or "the
architecture" need to be qualified explicitly**, not silently
defaulted.

Today (validated, in active use):

- Hyper-V on Windows Server (primary build/test host)
- Hyper-V on Windows workstations (Client Hyper-V — same APIs, some
  cmdlets stripped)

Today (occasional / case-by-case use):

- Parallels (macOS host)
- Apple Virtualization framework (Apple Silicon — arm64)
- Synology VMM (KVM-based, AMD CPUs)

Within ~6 months (inevitable, planning for):

- arm64 appliances (Apple Silicon for local AI inference; ARM-based
  Edge AI hardware)
- IoT / Raspberry Pi appliances for shop-floor use cases (different
  pattern: bare-metal, SD/eMMC images, no virtualization)

Implication for current work:

- amd64 stays the default *today* — no premature porting
- Don't bake `amd64` into filenames, paths, or assumptions where
  `arch` would do
- `dev-commons/SUPPORTED-ENVIRONMENTS.md` tracks what's been
  validated where, so "host-agnostic" is a verified claim, not an
  aspiration
- The two-script appliance pattern (`prepare-image.sh` + `sconfig`)
  generalizes to bare-metal IoT; the lab harness assumptions
  (Hyper-V VM lifecycle, snapshot/revert, dnsmasq reservations) do
  not. When the first IoT appliance lands, the lab pieces split out
  cleanly.

## Publication and ownership

These tools are open-source-ready in posture but not yet published.
When they are pushed to GitHub, they go to a dedicated org for
workplace open-source — not the owner's personal account, and not
mixed with private/proprietary work.

Working name for the org: **`NaimorOSS`** (custom domain
`oss.naimorinc.com`). See
[`decisions/0001-github-org-naimoross.md`](decisions/0001-github-org-naimoross.md)
for the full rationale and consequences.

Pre-publish hygiene runs through
[`PUBLISH-CHECKLIST.md`](PUBLISH-CHECKLIST.md). The known
pre-publish blockers (e.g. the WS2008 backend credential
embedded in `smb-proxy-appliance/docs/sketch-smb1-smb3-proxy.sh`)
are tracked there so they don't get forgotten.

Not all future tooling is open-source-ready. The decision ADR
sketches what to do for closed-side work when it appears.

## How to use this file

Refer back to `CONTEXT.md` when:

- A `STYLE.md` rule feels arbitrary — the rationale is here
- An audit finds a deviation and you're deciding fix vs defer — the
  trust model and "spooked helpers" framing is here
- A new appliance is being scoped and you need to remember which
  patterns are real vs aspirational — the platform reality section
  is here

When the situation changes (helpers brought on, first arm64 image
shipped, first IoT appliance lands, etc.), **edit this file** to
reflect the new reality. A stale `CONTEXT.md` is worse than no
`CONTEXT.md` because it misleads.
