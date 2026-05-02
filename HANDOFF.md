# Handoff Notes

`dev-commons` is the meta-repo for the sibling-repo family under
`Debian-SAMBA/`. Read order for anyone landing here cold:

1. [`CONTEXT.md`](CONTEXT.md) — *first*. The project narrative and
   the failure modes everything else is shaped to defend against.
2. [`STYLE.md`](STYLE.md) — coding, scripting, doc, and test
   conventions.
3. [`AGENTIC-DEVELOPMENT.md`](AGENTIC-DEVELOPMENT.md) — multi-agent
   process and ownership patterns.
4. [`REPO-SPLIT.md`](REPO-SPLIT.md) — sibling layout and per-repo scope.
5. [`SUPPORTED-ENVIRONMENTS.md`](SUPPORTED-ENVIRONMENTS.md) — the
   validated-vs-intended hypervisor + arch matrix.
6. [`PUBLISH-CHECKLIST.md`](PUBLISH-CHECKLIST.md) — pre-publish gate
   for any sibling about to be pushed to GitHub.
7. [`decisions/`](decisions/) — ADR-style log of cross-cutting choices.
8. [`audits/`](audits/) — periodic STYLE.md compliance sweeps.
9. [`bin/`](bin/) — cross-sibling tooling (sanity check, status
   overview, FIXME trawler).
10. [`template-appliance-virtualized/`](template-appliance-virtualized/)
    — scaffold for new virtualized appliances.

For anything else, [`AGENTS.md`](AGENTS.md) is the agent brief and
[`README.md`](README.md) the user-facing entry.
