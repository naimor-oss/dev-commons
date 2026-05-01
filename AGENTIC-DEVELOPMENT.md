# Multi-Agent Development Guide

This project is intentionally friendly to a mixed developer team: human owner,
senior cloud agents, vendor-specific coding agents, and lightweight local
agents for routine work.

The goal is not to let many agents edit randomly. The goal is to use different
tools for different strengths while keeping ownership, review, and project
memory clear.

## Team Model

Use three broad agent roles.

### Senior Coding Agents

Use for:

- architecture decisions
- cross-repo refactors
- security-sensitive changes
- test strategy
- hard debugging
- code review

Expect them to read context, reason about tradeoffs, and leave a clear summary.

### Specialized Vendor Agents

Use for:

- alternative implementation ideas
- second-opinion reviews
- focused investigation of tricky areas
- documentation or UX critique from another perspective

Keep vendor-specific state in private dot folders. Promote generally useful
findings to tracked docs.

### Lightweight Local Agents

Use for:

- scaffolding files
- repetitive boilerplate
- mechanical renames
- formatting
- simple Markdown tables
- test fixture generation

Give local agents narrow write scopes. Review their diffs before asking a
senior agent to build on top of them.

## Repository Conventions

Tracked, shared knowledge:

- `README.md`
- `AGENTS.md`
- `docs/*.md`
- scenario comments and script comments

Private, untracked agent state:

- `.claude/`
- `.codex/`
- `.cursor/`
- `.continue/`
- `.aider*`
- any local scratch folder explicitly ignored by `.gitignore`

Rule of thumb: if another agent needs to know it next week, put it in tracked
docs. If only one tool needs it for local operation, keep it private.

## Local Checkout Layout

Expected sibling repos:

```text
Debian-SAMBA/
  lab-kit/
  lab-router/
  samba-addc-appliance/
```

Dependency direction:

```text
samba-addc-appliance
  uses lab-kit
  uses lab-router for lab networking

lab-kit
  may provision lab-router
  does not know Samba internals

lab-router
  does not depend on Samba or lab-kit
```

## Suggested Workflow

1. Start with a human goal.
2. Ask one senior agent to propose a scoped plan.
3. Assign independent subtasks to local or vendor agents only when ownership is
   clear.
4. Keep each agent's write scope small.
5. Run basic checks before handing work to another agent.
6. Ask a different agent to review important diffs.
7. Promote durable context into `AGENTS.md` or `docs/`.
8. Commit cohesive changes with clear messages.

## Ownership Patterns

Good task split:

| Task | Best Owner |
| --- | --- |
| Add a new scenario skeleton | local agent |
| Review Samba join behavior | senior agent |
| Rewrite README section | vendor or local agent, then review |
| Refactor shared lab runner | senior agent |
| Generate repetitive config examples | local agent |
| Security review of credential handling | senior or specialist agent |

Bad task split:

- Two agents editing the same large script at the same time.
- One agent refactoring paths while another updates docs for old paths.
- Local boilerplate agent changing behavior without tests.
- Private agent notes becoming the only record of an important decision.

## Handoff Contract Between Agents

Every agent that makes a meaningful change should leave:

- what changed
- why it changed
- files touched
- checks run
- known risks or follow-ups

For larger work, add or update tracked docs. Do not rely on chat history as the
only source of truth.

## Review Strategy

Use diverse agents for review, not only implementation.

Useful review passes:

- shell safety and idempotence
- PowerShell/Hyper-V assumptions
- Samba/Windows AD interop
- docs accuracy
- security and credential handling
- portability to future hypervisors

Reviews should focus on concrete findings with file references and suggested
fixes.

## Sanity Checks Before Publishing

Run these from the parent directory when all three sibling repos exist:

```bash
(cd samba-addc-appliance && bash -n prepare-image.sh samba-sconfig.sh lab/run-scenario.sh lab/scenarios/*.sh)
(cd lab-kit && bash -n bin/run-scenario.sh scenarios/common/*.sh)
(cd lab-router && bash -n scripts/stage-router-artifacts.sh)
```

Check repo state:

```bash
git -C samba-addc-appliance status -sb
git -C lab-kit status -sb
git -C lab-router status -sb
```

Optional text hygiene:

```bash
LC_ALL=C rg -n "[^[:ascii:]]" samba-addc-appliance lab-kit lab-router
```

Non-ASCII is not forbidden when intentional, but new public docs should default
to ASCII unless there is a reason.

## Publishing Rules

- Do not publish private dot folders.
- Do not publish accidental logs unless selected as evidence.
- Make each repo useful from its own README before pushing.
- Prefer public repos only after the first commit builds a coherent project.
- Add remotes only after checking GitHub auth and intended repository names.

## Practical Prompting Patterns

For a senior agent:

```text
Read AGENTS.md and docs/REPO-SPLIT.md. Propose a minimal change plan before
editing. Keep Samba-specific logic out of lab-kit and lab-router.
```

For a local boilerplate agent:

```text
Only create files under docs/examples/. Do not edit scripts. Use ASCII
Markdown. Stop after generating the skeleton.
```

For a review agent:

```text
Review this diff for behavioral regressions and missing tests. Lead with
findings and cite file paths.
```
