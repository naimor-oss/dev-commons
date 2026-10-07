# Session 04 — DFS withdrawal and deletion convergence

## Goal

Make both AD-derived DFS mechanisms converge valid offline, empty, and deleted
state by withdrawing stale referrals, while still preserving last-known-good
configuration for discovery, parse, validation, or publication failures.

## Scope

- Automatic domain-root proxy synchronization in
  `samba-addc-appliance/samba-sconfig.sh`
- Tertiary namespace link materialization and pruning in the same file
- DFS parser, Bats tests, documentation, and lab scenarios

## Plan

1. Define three distinct result classes: valid populated state, valid empty or
   offline state, and indeterminate/invalid state. Only the third class keeps
   last-known-good output.
2. For automatic roots, treat a namespace with no non-local online target as
   a valid withdrawal of that managed proxy section. Do not fail the entire
   candidate because one namespace is intentionally offline.
3. For tertiary links, filter `state` case-insensitively before ordering and
   publication. Match the automatic-root semantics. Decide explicitly how
   unknown state values fail validation.
4. If a valid link object has no online targets, omit it from the keep set so
   the existing managed symlink is pruned. Do not count that as malformed.
5. If a namespace search succeeds authoritatively with zero links, prune all
   managed links under that namespace. Continue to skip pruning on missing
   base, search failure, parse failure, or rejected records that make the
   result incomplete.
6. Preserve foreign files/symlinks and the current atomic symlink swap.
7. Log withdrawals separately from rejected metadata so operators can
   distinguish intended convergence from an error.

## Verification

- Add transitions for online to offline, last target offline, offline back to
  online, link deletion, last-link deletion, namespace deletion, malformed
  target, and `ldbsearch` failure.
- Assert stale managed entries disappear only for authoritative state.
- Assert foreign files and non-managed symlinks are never removed.
- Extend the Windows DFS lab scenario to confirm clients stop receiving a
  withdrawn target and later receive it again after recovery.

## Completion criteria

- No offline target is emitted by either DFS implementation.
- Authoritative empty/deleted state removes stale managed referrals.
- Indeterminate state leaves the last-known-good configuration byte-identical.

## Rollback

Keep root-proxy and tertiary behavior in separate commits if practical. Before
deployment, save the generated managed `smb.conf` block and hosted symlink
inventory so either mechanism can be restored without touching foreign data.
