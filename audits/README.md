# Audits

Periodic sweeps of the sibling-repo family against `dev-commons/STYLE.md`.

## Format

Each audit is `YYYY-MM-DD-<scope>.md` with the following structure:

- **Findings** — ordered by severity (HIGH / MEDIUM / LOW), each with
  the §N STYLE.md reference, the affected files, the deviation, and
  a one-sentence reason it matters.
- **Resolution** — for each finding, one of `fix` / `defer` / `reject`,
  filled in by the reviewer (the human owner) before any compliance
  work begins.
- **Done** — for findings marked `fix`, the commit that resolved it,
  filled in after compliance work.

The audit is the gate: no edits land in the sibling repos until the
reviewer marks each finding.

## Index

| Date | Scope | Status |
| --- | --- | --- |
| [2026-05-01](2026-05-01-style-compliance.md) | First full sweep against STYLE.md (all five siblings) | complete (all 10 findings resolved same-day) |
