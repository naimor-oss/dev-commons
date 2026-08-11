# Session 06 — Transactional proxy configuration application

## Goal

Make proxy configure and remove operations return success only when persistent
state, mounts, generated Samba configuration, and the live `smbd` process all
agree. Failed apply steps must preserve or restore a usable prior generation.

## Scope

- `smb-proxy-appliance/smbproxy-sconfig.sh`
- Configuration transaction helpers and regression tests

## Dependency

Complete Session 02 first. This session builds rollback and status propagation
on the lifecycle state machine instead of inventing a second transition model.

## Plan

1. Enumerate every mutation in configure/remove: directories, local identity,
   credentials, `fstab`, mount state, share state, `smb.conf`, daemon reload,
   and queued manifest handling. Classify reversible preparation versus final
   commit.
2. Build candidates in private temporary files on the destination filesystem.
   Run validators, `testparm`, identity resolution, and mount prerequisites
   before publishing any candidate.
3. Snapshot or atomically detach the previous generation needed for rollback.
   Publish files in a documented order compatible with the Session 02
   withdrawal marker.
4. Check `daemon-reload`, mount/unmount, `smbd` reload, fallback restart, and
   post-reload health explicitly. Preserve the first meaningful error code.
5. If live apply fails, restore the previous file generation and reload it.
   If rollback also fails, leave the share withdrawn, retain both generations,
   return nonzero, and print exact recovery commands.
6. Delay irreversible removal of credentials, share state, and queued history
   until the frontend is withdrawn and cleanup is proven complete.
7. Ensure secrets are cleared on every return path.

## Verification

- Use fake `systemctl`, `testparm`, mount, unmount, and filesystem operations
  to inject failure at every step and assert the returned status and final
  generation.
- Test reload failure followed by successful restart, both failing, rollback
  reload failing, inactive pre-join `smbd`, and interrupted removal.
- Verify the command never reports success with an orphan mount, missing
  credentials, stale live section, or unapplied candidate.
- Run end-to-end add/edit/remove on the lab proxy with active and inactive
  clients.

## Completion criteria

- Every external command that determines correctness has checked status.
- Success implies live and persistent configuration generation match.
- Failure leaves either the old working generation or an explicitly withdrawn,
  recoverable share.

## Rollback

Keep prior-generation files until post-apply verification passes. Document a
single recovery command that restores them and reloads Samba without deleting
backend or queued user data.
