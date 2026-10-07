# Session 09 — Windows executable-bit hygiene

## Goal

Remove false executable-bit modifications from all four Windows worktrees and
prevent a Windows commit from changing appliance scripts from mode `100755` to
`100644`.

## Scope

- Repository-local Git configuration for `appliance-core`,
  `samba-addc-appliance`, `smb-proxy-appliance`, and
  `smbproxy-session-vfs`
- Maintained Windows setup documentation and a CI/release mode check

This session must not discard or rewrite the proxy's intentional textual
fail-fast changes.

## Plan

1. Record `git status`, `git diff --summary`, and `git diff --numstat` in each
   repository. Separate mode-only changes from textual changes before making
   any adjustment.
2. Set repository-local `core.fileMode=false` for these Windows checkouts.
   Do not change the global Git configuration unless the operator explicitly
   requests it.
3. Verify the index still records every shipped executable as `100755` using
   `git ls-files --stage`. Do not use checkout/reset commands to hide status.
4. Add Windows setup guidance explaining why the local setting is required
   and how to audit executable modes before commit.
5. Add a Linux CI/release check containing the explicit executable manifest or
   another deterministic index-mode assertion for installed scripts, build
   scripts, tests, and update installers.
6. Inspect the final staged diff from Linux or with `git diff --cached
   --summary` before publishing any later session.

## Verification

- Mode-only `M` entries disappear locally while all intentional text changes
  remain visible.
- `git ls-tree`/`git ls-files --stage` reports `100755` for every required
  executable.
- Deliberately changing one manifest entry to `100644` makes the CI/release
  check fail.
- `git diff --check` and each repository's fast checks still pass.

## Completion criteria

- Clean repositories have no Windows-induced mode drift.
- The proxy shows only its intentional textual/untracked changes.
- A future accidental executable-bit regression is caught before release.

## Rollback

The local configuration can be removed with `git config --local --unset
core.fileMode`. Removing it must not alter the index. Revert documentation and
CI changes as a normal isolated commit if necessary.
