# Session 03 — Atomic per-GPO SYSVOL replacement

## Goal

Make the generated `sysvol-sync` implementation satisfy its documented
atomic-per-GPO guarantee. Clients must see either the complete old GPO or the
complete new GPO, including when download, validation, swap, or ACL reset
fails.

## Scope

- The `sysvol-sync` generator in `samba-addc-appliance/prepare-image.sh`
- SYSVOL sync tests, operational documentation, and lab scenarios

## Plan

1. Stage each downloaded GPO on the same filesystem as the live `Policies`
   directory. Reject incomplete downloads and validate the staged `GPT.INI`,
   expected GUID, version, file types, and tree boundaries before publication.
2. Preserve required ownership, modes, ACL-related metadata, and extended
   attributes in the staged tree. Establish the exact relationship between
   the swap and the existing durable `sysvolreset` operation.
3. Replace new GPOs with a same-filesystem rename. For an existing non-empty
   directory, use a tested atomic directory exchange supported by the target
   Debian kernel/filesystem, then remove the old tree only after the exchange
   succeeds. Do not implement a delete-then-rename sequence.
4. Remove `--max-delete` from the live publication path. It may be used for
   cleanup of an already detached old staging tree, where failure cannot
   expose a mixed live GPO.
5. Serialize publication against another sync and retain a recoverable old
   tree until the swap and required ACL reset have succeeded.
6. Bound and log cleanup without deleting the only valid generation.

## Verification

- Add fault injection after download, midway through staging, immediately
  before exchange, immediately after exchange, and during cleanup/ACL reset.
- Run a concurrent reader loop over `GPT.INI` and representative policy files;
  every observed tree must match one complete generation.
- Test new GPO, update, more than 100 deletions, interrupted cleanup, and a
  filesystem that does not support the selected exchange primitive.
- Run the existing SYSVOL freshness and ACL reset tests, then validate GPO
  retrieval from a Windows lab client.

## Completion criteria

- No code writes or deletes inside the live GPO tree before publication.
- Failure always leaves one complete, readable live generation.
- The implementation, comments, and docs describe the same atomicity model.

## Rollback

Retain the detached old generation until post-swap checks pass. Provide an
operator command that exchanges it back without recursively copying over the
live tree.
