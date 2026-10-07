# Session 07 — Fail-closed proxy worker inventory

## Goal

Ensure that a missing, unreadable, truncated, or invalid share-state record can
never cause the health worker to re-enable a previously withdrawn share or
silently publish the offline placeholder as an empty share.

## Scope

- `smb-proxy-appliance/smbproxy-share-worker`
- Managed share markers emitted by `smbproxy-sconfig.sh`
- Worker and compliance tests

## Dependency

Run after Session 05 so inventory parsing and malformed-state behavior use the
final non-executable state format.

## Plan

1. Add an unambiguous persistent marker identifying sections owned by the
   proxy configurator. Do not infer ownership from a transient health marker
   or accidentally manage operator-authored shares.
2. Build inventory from both managed `smb.conf` sections and valid share-state
   records. Classify each managed section as healthy, offline, missing state,
   invalid state, or orphan state.
3. For missing/invalid state, render the section withdrawn with a local safe
   path and `available = no`. Never remove an existing withdrawal merely
   because the state inventory omitted the section.
4. Continue processing other shares after one parse failure. Record a bounded
   health error that names the affected share and reason.
5. Restore availability only after a valid state record, independent backend
   reachability confirmation, required mount recovery, and successful
   `testparm`/reload.
6. Define reconciliation for an orphan state record with no managed section;
   it must not create a frontend implicitly.

## Verification

- Add tests for deleting the state of an offline and an online share,
  truncation, unknown version, duplicate key, unreadable state, empty state
  directory, orphan state, and an unrelated operator share.
- Assert the generated candidate retains a safe path and `available = no` for
  every invalid managed share.
- Assert a failure in one share does not delay or corrupt another share.
- Re-run the direct fail-fast timing and recovery tests.

## Completion criteria

- Absence or corruption of management metadata always withdraws access.
- Only a complete verified recovery removes the health withdrawal.
- Operator-authored `smb.conf` sections remain byte-stable.

## Rollback

The new persistent ownership marker must be backward-compatible during one
upgrade cycle. Rollback must leave withdrawn sections withdrawn rather than
stripping markers it no longer understands.
