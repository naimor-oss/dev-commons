# Session 08 — VFS partial-read semantics

## Goal

Preserve bytes successfully transferred by the 16 KiB sequential-read shim
when a later chunk fails. Synchronous and asynchronous reads must follow the
same partial-progress behavior without weakening the SMB1 compatibility or
serialization design.

## Scope

- `smbproxy-session-vfs/src/vfs_smbproxy_session.c`
- VFS source/behavior tests and package version
- The pinned VFS release/hash/version in `smb-proxy-appliance`

## Plan

1. Confirm Samba's expected `pread` and async receive semantics against the
   exact accepted Samba source revision used by the appliance.
2. In the synchronous path, return `done` when a later chunk fails after
   positive progress; return `-1` only when no bytes were transferred.
3. Give the asynchronous state machine the identical rule. Return the prior
   successful byte count with a successful AIO state when progress exists;
   preserve the underlying error only for zero-progress failure.
4. Preserve short-read/EOF behavior, 16 KiB maximum chunk size, per-tree queue
   serialization, and offset overflow safety.
5. Add an executable behavior harness or Samba integration test; do not rely
   only on grep-based source contracts for this semantic change.
6. Bump the VFS package version, rebuild against the exact accepted Samba
   package, update source hashes and proxy pins, and exercise the runtime guard.
7. Deploy to the lab first, then qualify large reads and a controlled injected
   later-chunk error before considering production.

## Verification

- Cover zero-length, one chunk, multi-chunk, short first chunk, EOF, first
  chunk error, and later chunk error in both sync and async paths.
- Assert concurrent async requests remain serialized per tree.
- Run `scripts/check.sh`, package/repository contracts, exact-version checks,
  and proxy VFS contract/update tests.
- Re-run the 5.7 MB read/hash case and verify no `ENOMEM`, signature, reconnect,
  or resource errors.

## Completion criteria

- Later failure returns the exact positive byte count already transferred.
- First failure still reports the original error.
- Package metadata, source hash, appliance pin, and installed runtime guard all
  identify the same release and Samba revision.

## Rollback

Retain the previous package in the appliance repository and document the exact
downgrade command. Rollback must also restore the matching proxy source hash
and package-version expectation.
