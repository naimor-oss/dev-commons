# Session 05 — Safe state serialization and input validation

## Goal

Stop executing persisted configuration as shell code. Network-detected and
operator-supplied values must be parsed as data, validated centrally, and
rejected safely if malformed.

## Scope

- `appliance-core/lib/detect-net.sh` and both first-boot consumers
- Proxy share-state writers and readers in `smbproxy-sconfig.sh`,
  `smbproxy-share-worker`, `smbproxy-session-mount`, probe/version helpers,
  migration/update scripts, and tests

Credentials remain in their dedicated protected format and must never migrate
into general state.

## Plan

1. Choose one non-executable, dependency-appropriate format for each contract.
   Define allowed keys, encoding, duplicates, unknown keys, size limits, and
   malformed-record behavior before implementing it.
2. Replace direct `source` calls with one strict parser. The parser must never
   use `eval`, shell expansion, command substitution, or code generated from a
   value.
3. Migrate the core detection cache and both first-boot readers together.
   Preserve safe offline-cache behavior while treating DHCP/PTR data as
   untrusted input.
4. Migrate proxy share state atomically. Parse legacy files without sourcing
   them, accept only the documented safe legacy subset, and quarantine/reject
   unsafe or ambiguous files instead of guessing.
5. Add central validators for IPv4/backend host, backend username/domain,
   frontend local username, share name, SMB dialect, and absolute mount path.
   Constrain mount paths to the appliance-owned roots and reject control
   characters, traversal, shell syntax, and delimiter injection.
6. Make every consumer fail closed on missing, unknown, duplicate, malformed,
   or mismatched fields. Log field names, never credential values.
7. Update in-place migrations, source-export checks, and documentation.

## Verification

- Add round-trip tests for spaces and every supported punctuation character.
- Add injection fixtures containing quotes, substitutions, backticks,
  backslashes, tabs, newlines, duplicate keys, oversized values, and unknown
  fields; prove no fixture executes code or mutates unrelated files.
- Test upgrade from every currently supported legacy state version.
- Verify a corrupt state file withdraws its share and does not stop health
  processing for other shares.
- Run both appliance first-boot detection suites and all proxy helper, worker,
  session-mount, updater, and version-guard tests.

## Completion criteria

- Repository-wide search finds no direct sourcing of detection or share state.
- All persisted values pass a documented validator before use in paths,
  commands, `fstab`, credentials, or `smb.conf`.
- Migration is idempotent and never destroys the only legacy copy on failure.

## Dependencies and rollback

Run before Session 07 so the worker's fail-closed inventory uses the final
state parser. Keep a root-only backup of each migrated file and provide a
version-aware rollback; never convert back by sourcing untrusted data.
