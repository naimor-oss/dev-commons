# Session 08 — VFS partial-read semantics

## Decision (2026-10-08): closed without a code change

Plan step 1 was checked against the Samba source in Debian trixie
(4.22.11+dfsg-0+deb13u1; the pinned 4.22.10 package is no longer published
on sources.debian.org, and the read path did not change between them):

- `lib/util/sys_rw.c` `sys_pread_full()` returns `-1` when any later
  `pread` fails, discarding the bytes it already read; it stops early only
  at EOF (`ret == 0`).
- `source3/modules/vfs_default.c` uses `sys_pread_full()` for both the
  synchronous path (`vfswrap_pread`) and the thread-pool job behind
  `pread_send` (`vfs_pread_do`).
- `source3/smbd/smb2_aio.c` passes the `pread_recv` count straight to the
  client as the read length, so a partial count reaches the client as a
  short read with no error.

The module's current rule (error on any failed chunk) therefore matches
Samba's own default VFS. Returning partial progress instead would turn a
backend failure into a silent short read, which a record-oriented legacy
application could take as end of file. The owner chose to keep the
current behavior. No package rebuild, version bump, or proxy pin change
is needed.

One known, harmless difference remains: the module also stops at a short
(non-zero) chunk, while `sys_pread_full()` keeps reading. A CIFS backend
returns a short read only at EOF, so the result is the same. Both are
documented in `smbproxy-session-vfs/docs/SMB1-COMPATIBILITY.md`.

The original plan is kept below for the record.

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
