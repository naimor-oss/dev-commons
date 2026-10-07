# Session 02 — Proxy share lifecycle serialization

## Goal

Make add, reconfigure, connect, disconnect, withdraw, and remove operations a
single coherent per-share lifecycle. No new VFS tree may enter after withdrawal
starts, and existing legacy sessions must never silently continue against old
credentials or a different backend after reconfiguration reports success.

## Scope

- `smb-proxy-appliance/smbproxy-sconfig.sh`
- `smb-proxy-appliance/smbproxy-session-mount`
- The VFS integration contract and proxy lifecycle tests

Do not change the hard-mount, `nosharesock`, VUID/CNUM/PID, or `fileid`
coherency design.

## Plan

1. Write down a per-share state machine: `published`, `withdrawing`,
   `draining`, `unpublished`, and `publishing`. Define legal transitions and
   recovery after interruption.
2. Define and document lock ordering relative to the worker and `smb.conf`
   locks. Use a per-share lifecycle lock plus a durable/runtime withdrawal
   marker so the code never holds an exclusive lock while waiting for a VFS
   disconnect that needs the same lock.
3. Make VFS connect acquire the lifecycle lock, reject any withdrawn/draining
   share, load a consistent state/credential generation, and record that
   generation with the session.
4. For removal: mark withdrawn, replace the frontend with the offline path or
   remove its section, validate and reload, then close trees, wait for verified
   disconnect, clean sessions, unmount modern backends, and finally remove
   state and credentials.
5. For legacy reconfiguration: withdraw and drain before changing backend,
   identity, profile, credentials, locking, or offline mode. A safe no-drain
   path may be retained only for fields proven not to affect an active tree.
6. Treat failed close, drain, cleanup, and modern unmount as operation failures.
   Leave recoverable state and clear operator guidance instead of claiming the
   share was removed.
7. Add startup recovery for a transition interrupted after withdrawal but
   before final cleanup or republish.

## Verification

- Add deterministic concurrency tests that pause removal after cleanup and
  attempt a new VFS connect; it must fail.
- Reconfigure a legacy share with an active client and verify the operation
  drains/rejects rather than producing simultaneous old/new backend sessions.
- Kill the configurator at every state transition and verify rerun recovery.
- Verify modern unmount failure preserves enough configuration to retry.
- Re-run `.TPS` multi-user lock isolation and exact one-upstream-session-per-
  downstream-tree tests.

## Completion criteria

- Every lifecycle transition has one owner, explicit lock ordering, and an
  interruption recovery path.
- Removal cannot return success while a matching frontend tree or backend
  mount remains.
- Reconfiguration cannot leave active trees on two configuration generations.

## Dependencies and rollback

Complete this before Session 06. Keep schema/state-machine introduction and
behavior changes reviewable, with a migration that older share state can load.
Rollback must restore the prior scripts and remove only new empty transition
markers; never force-unmount a live hard SMB1 session.
