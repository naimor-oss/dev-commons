# 0001 — GitHub org for the open-source workplace tooling

**Status**: accepted
**Date**: 2026-05-01

## Context

The sibling repos (`dev-commons`, `lab-kit`, `lab-router`,
`samba-addc-appliance`, `smb-proxy-appliance`, plus future
appliances) are open-source-ready in posture but not yet pushed
anywhere except local working trees.

The owner's GitHub identity is a personal account. Pushing
workplace-related tooling under a personal handle conflates two
distinct identities:

- the owner as an individual hobbyist developer
- the workplace (Naimor) as the institutional source and beneficiary
  of these tools

Both `samba-addc-appliance` and `smb-proxy-appliance` already carry
the workplace identity in tracked content (`naimor.naimorinc.com`
realm references in `docs/sketch-smb1-smb3-proxy.sh`, the
historical sketch script). With more sibling repos coming and an
expectation of partial outsourcing of IT operations within
2-9 months, the conflation will only get worse.

## Decision

Create a dedicated GitHub organization for the open-source
workplace tooling. Working name: **`NaimorOSS`**.

- Repos are pushed to `github.com/NaimorOSS/<repo-name>`, never to
  the owner's personal account.
- A custom domain `oss.naimorinc.com` is configured to point at the
  org's GitHub Pages site.
- The org's Pages site (built from a small `oss-site` repo or from
  `NaimorOSS/.github` profile README) provides a one-page landing
  with the project listing, links into the per-repo READMEs, and
  the "what these tools are and what they're not" framing.

## Consequences

### For the repos

- Cross-repo references in tracked docs that today say
  "`../<sibling>/...`" stay relative and unchanged — the sibling
  layout is a *local checkout* convention, not a published-URL
  convention.
- Where docs reference a repo by URL (rare today), use
  `https://github.com/NaimorOSS/<repo>` once the org exists; until
  then, leave the cross-references as relative paths.
- New cross-referencing docs (e.g. issue tracker links, "report a
  bug" guidance) wait until the org is set up before being added.

### For pre-publish hygiene

`PUBLISH-CHECKLIST.md` (in this repo) is the durable gate. Every
repo passes through it before its first push to `NaimorOSS`. The
ixgbevf credentials note (production WS2008 backend password
embedded in `smb-proxy-appliance/docs/sketch-smb1-smb3-proxy.sh`)
is the canonical example of why the checklist exists.

### For the builder/operator boundary

Public org membership lists are visible. Future outsourced helpers
should NOT be added to `NaimorOSS` — they don't need write or
read access to source repos (per `CONTEXT.md` §"the boundary that
matters most"). If they do need read access to specific repos for
operational reasons, prefer:

1. **Don't.** Operator-facing material lives outside the source repos.
2. If unavoidable, grant per-repo collaborator access (not org
   membership) with read-only scope.
3. Never grant write access from outside the trusted-builder set.

### For internal-only tooling

Some future tools may not be open-source-ready (proprietary
business logic, customer data handling). Those should NOT live in
`NaimorOSS`. Either:

- A separate private GitHub org (e.g. `Naimor` for the closed
  side), or
- A self-hosted git server, or
- Stay in personal accounts with private visibility.

When the first such tool is needed, decide then; this ADR doesn't
prescribe.

## Status notes

- Org `NaimorOSS` is not yet created on GitHub as of this writing.
- No repo has been pushed to a remote yet.
- This ADR documents the decision so it survives until enacted; it
  does not reflect current GitHub state.
