# Decision Log

Lightweight ADR-style entries for choices that affect more than one
sibling repo. Numbered sequentially; once accepted, kept as-is for
the historical record (later supersedence noted in a new entry, not
by editing the old one).

## Format

Each file is `NNNN-short-slug.md` containing:

- **Status** — proposed / accepted / superseded
- **Date** — ISO yyyy-mm-dd
- **Context** — what situation forced the decision
- **Decision** — what was chosen
- **Consequences** — what the choice implies, including downsides

Keep entries short. ADRs are journal entries, not specifications.

For decisions that need a longer specification (lib contracts,
call-site maps, migration ordering), pair the ADR with a draft in
[`../proposals/`](../proposals/). The ADR records *what* and *why*;
the proposal records *how*.

## Entries

| # | Title | Status |
| --- | --- | --- |
| [0001](0001-github-org-naimor-oss.md) | GitHub org for the open-source workplace tooling | accepted |
| [0002](0002-appliance-core.md) | Appliance core as a new sibling repo (paired with [proposal](../proposals/appliance-core-design.md)) | accepted |
