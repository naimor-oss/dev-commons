# Code-review remediation sessions

The comprehensive review on 2026-08-10 found no P0 defect, but it identified
four P1 findings and five P2 findings across `appliance-core`,
`samba-addc-appliance`, `smb-proxy-appliance`, and
`smbproxy-session-vfs`. The implementation work is split into the bounded
sessions below so each change can be reviewed, tested, and rolled back on its
own.

The session number maps to the numbered review finding. Numbering is stable;
it is not the recommended execution order.

| Session | Finding | Priority | Primary repositories |
|---|---|---:|---|
| [01](docs/code-review-session-plans/01-secret-free-authentication.md) | Remove credentials from process arguments | P1 | AD DC, proxy |
| [02](docs/code-review-session-plans/02-proxy-share-lifecycle.md) | Serialize proxy share lifecycle and VFS sessions | P1 | proxy, VFS integration |
| [03](docs/code-review-session-plans/03-atomic-sysvol-updates.md) | Make per-GPO SYSVOL replacement genuinely atomic | P1 | AD DC |
| [04](docs/code-review-session-plans/04-dfs-withdrawal-convergence.md) | Converge DFS offline and deletion transitions | P1 | AD DC |
| [05](docs/code-review-session-plans/05-safe-state-serialization.md) | Replace executable state serialization and validate inputs | P2 | core, AD DC, proxy |
| [06](docs/code-review-session-plans/06-transactional-config-application.md) | Propagate apply failures and roll back partial configuration | P2 | proxy |
| [07](docs/code-review-session-plans/07-worker-fail-closed-inventory.md) | Keep missing or corrupt proxy shares withdrawn | P2 | proxy |
| [08](docs/code-review-session-plans/08-vfs-partial-read-semantics.md) | Preserve successful partial VFS reads | P2 | VFS, proxy consumer |
| [09](docs/code-review-session-plans/09-windows-filemode-hygiene.md) | Eliminate Windows executable-bit drift | P2 | all four repositories |

## Recommended execution order

Run Session 09 before staging any source changes. Then use this order:

1. Session 01 — remove credential disclosure.
2. Session 02 — establish the lifecycle state machine and lock ordering.
3. Session 06 — add transactional failure handling on top of that lifecycle.
4. Session 05 — migrate state serialization and centralize validation.
5. Session 07 — make the worker fail closed against the new inventory format.
6. Sessions 03 and 04 — independent AD DC correctness work.
7. Session 08 — VFS correction, package rebuild, and proxy pin update.

Sessions 03 and 04 may be run in either order. Do not combine Sessions 02,
05, 06, and 07 into one change: they overlap, but separate commits keep
lifecycle, persistence, apply behavior, and health-policy regressions
independently diagnosable.

## Baseline at this handoff

No product source was changed during the review or while creating these plans.
The proxy worktree already contains intentional, uncommitted fail-fast changes
from the SMB delay investigation; preserve and re-audit those changes when a
session overlaps the same files.

Checks completed on 2026-08-10:

- Shell syntax passed across the reviewed shell sources.
- Proxy helper tests passed: 115 assertions.
- Proxy worker/fail-fast tests passed: 38 assertions.
- Backend-probe tests passed.
- VFS fast source/repository contracts, version guard, proxy VFS contract,
  in-place migration, and VFS hotfix updater checks passed.
- `git diff --check` passed in all four repositories.

Windows host limitations at handoff:

- Bats, ShellCheck, and a Samba C build environment are not installed.
- The session-mount test requires a Linux `/etc/passwd`.
- The domain-DNS test needs a Unix-compatible `hostname -s`.
- The AD TUI harness needs dialog/whiptail/tmux or Docker.

Use a Linux lab appliance or CI runner for those gates rather than weakening
the tests to accommodate Git Bash.

## Common rules for every session

- Read the repository `AGENTS.md` plus `dev-commons/CONTEXT.md` and
  `dev-commons/STYLE.md` before editing.
- Preserve unrelated working-tree changes. The proxy contains intentional
  uncommitted fail-fast work from the delay investigation.
- Add a regression test that fails before the fix and passes afterward.
- Run each repository's documented fast checks and `git diff --check`.
- Test appliance mutations in the lab before production deployment.
- Do not weaken the VFS exact-Samba-version guard, VUID/CNUM/PID identity,
  per-tree hard SMB1 mounts, or the `fileid` locking identity.
- Record source commits, package versions, deployed host versions, test
  evidence, and rollback instructions in the session handoff.
