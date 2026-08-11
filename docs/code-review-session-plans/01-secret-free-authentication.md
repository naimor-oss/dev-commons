# Session 01 — Secret-free authentication arguments

## Goal

Remove domain and Administrator passwords from process argument vectors on
both appliances. A local unprivileged process must not be able to recover a
secret from `/proc/<pid>/cmdline`, `ps`, logs, or temporary filenames while a
provision, join, DNS, SYSVOL, password-reset, or domain-leave operation runs.

## Scope

- `samba-addc-appliance/samba-sconfig.sh`
- `smb-proxy-appliance/smbproxy-sconfig.sh`
- Authentication tests and operator documentation in those repositories

Inventory every use of `--adminpass`, `--password`, `--newpassword`, and
`-U user%password`. Do not limit the change to the examples cited by the
review.

## Plan

1. On a matching Debian/Samba appliance, inspect the installed commands'
   supported authentication mechanisms. Prefer an existing Kerberos cache,
   stdin, or a root-only authentication file; do not assume flags that the
   installed Samba revision does not support.
2. Introduce one narrowly scoped authentication helper per repository. It
   should acquire credentials without echo, create an isolated root-only
   Kerberos cache or file when required, invoke the command, and remove the
   credential material on success, error, signal, and cancellation.
3. Convert AD join, DNS registration, KCC, SYSVOL bootstrap, password reset,
   and proxy domain leave to the safe mechanism.
4. Treat initial forest provisioning separately because no Kerberos service
   exists yet. If the installed CLI has no non-argv input, use a small audited
   wrapper around the supported Samba Python API or another documented
   descriptor-based interface. Do not call a shell with the password embedded.
5. Ensure debugging, error paths, `set -x`, `tee`, and journal output never
   print the secret. Clear shell variables as soon as the operation completes.
6. Document the authentication lifetime and the expected cleanup artifacts.

## Verification

- Add fake-command tests that record argv and environment keys while accepting
  a secret through the chosen protected channel. Assert that a distinctive
  test secret is absent from argv, stdout, stderr, logs, and persistent files.
- On a lab appliance, sample `/proc/*/cmdline` continuously during every
  converted operation and assert the test password never appears.
- Exercise success, bad password, command failure, cancellation, and signal
  cleanup.
- Confirm join/provision, PTR registration, SYSVOL seed, password reset, and
  leave behavior still work against the lab domain.

## Completion criteria

- Repository-wide search finds no password-bearing command argument.
- Credential artifacts are mode `0600` or stronger and do not survive the
  operation.
- Existing domain workflows and their failure messages remain functional.

## Rollback

Keep this as an isolated commit in each appliance repository. Roll back the
code and documentation together; do not retain a partially converted mixture
of safe and argv-based authentication paths.
