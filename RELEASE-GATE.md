# Release gate

The fixed list of checks that runs before any sibling-repo change is
considered "ready to ship to the production proxy / DC". Two phases:

1. **Preflight** (no VM, ~45 s). One command:

    ```bash
    dev-commons/bin/preflight.sh
    ```

    Chains: cross-repo `sanity-check.sh`, per-appliance `bash -n` on
    every entry-point script, **every** `tests/*.sh` and
    `tests/**/*.bats` in all seven siblings (discovered, not listed;
    opt-outs live in each repo's `tests/.preflight-skip` with a
    reason), design-contract guards, appliance-core compliance, and
    strict ShellCheck. Bails on first failure with the failing repo +
    step named. CI runs the same script with
    `PREFLIGHT_REQUIRE_TOOLS=1`, so a missing bats or ShellCheck fails
    instead of skipping.

2. **VM gate** (lab Hyper-V cluster, ~45–60 min total). Ten
    scenarios across two appliances, in order:

    | # | Repo | Scenario | Notes |
    | - | ---- | -------- | ----- |
    | 1 | `samba-addc-appliance` | `smoke-prepared-image` | freshly-rebuilt golden image is sane (`apt-helpers`, `detect-net` resolve correctly; firstboot marker not consumed) |
    | 2 | `samba-addc-appliance` | `provision-new` | full forest provision; covers `domain_provision_new` TUI/CLI, hardening, post-provision setup, TLS cert |
    | 3 | `samba-addc-appliance` | `dfs-namespace` | DFS-N convergence, sentinel guard, empty-result guard, scheduling unit ReadWritePaths matches runtime DFS_ROOT |
    | 4 | `smb-proxy-appliance` | `smoke-prepared-image` | proxy golden-image sanity |
    | 5 | `smb-proxy-appliance` | `join-domain` | AD join via WS2025-DC1, winbind reachable |
    | 6 | `smb-proxy-appliance` | `backend-mount` | session-managed CIFS mount with lock forwarding: `vers=1.0`, `cache=none`, `hard`, `nosharesock`, **no `nobrl`**, **numeric** uid=/gid= |
    | 7 | `smb-proxy-appliance` | `frontend-share` | full backend+frontend; `force user` is **username**, `valid users` is SID, /etc/passwd resolves to a real UID |
    | 8 | `smb-proxy-appliance` | `multi-share` | two shares from one backend with distinct creds + identities; `remove_share` per-share scoping |
    | 9 | `smb-proxy-appliance` | `collision-refused` | NEGATIVE: AD-colliding force-user → rc=9 + no orphan creds/fstab/smb.conf/state/passwd |
    | 10 | `smb-proxy-appliance` | `tps-lock-isolation` | **the production locking guarantee**: two SMB3 connections get distinct upstream SMB1 sessions and one Samba file identity (`fileid:algorithm = fsname`); overlapping locks conflict at the SMB1 backend; sessions are released on disconnect |

    Run order matters for #1→#3 and #4→#10 (each later scenario
    assumes earlier ones haven't broken the appliance state).
    Within those two streams the scenarios are independent.

## Force-user contract (the load-bearing one)

The proxy's force-user contract is the most-bent invariant in the
codebase. The release gate checks all three of its corners:

- **`force user = <username>` in `smb.conf`** (verified by
  `frontend-share` + `multi-share`). Samba resolves via
  `getpwnam()`; numeric UIDs do NOT work and are actively
  rejected by the verify step.
- **`uid=`/`gid=` in fstab cifs mount options stay numeric**
  (verified by `backend-mount`). Those are kernel cifs option
  values, not Samba `force user` resolution.
- **AD-name collision = REFUSAL with rc=9** (verified by
  `collision-refused`). `configure_share` calls
  `wbinfo --name-to-sid` BEFORE any persistent writes
  (creds, fstab, smb.conf, share-state, useradd) and exits
  rc=9 if the chosen name resolves in AD. The negative
  scenario also asserts no orphan state.

## Adversarial profiles

Two profiles, mutually exclusive:

- `lab/profiles/adversarial-positive.env` — weird-but-valid inputs
  (shop-flavor non-AD-colliding force-users `tubelaser`/`millhand`,
  single-word AD groups, `Old.Files$` share name with $-suffix +
  embedded dot). All standard scenarios run cleanly with this
  profile and EXPECT rc=0.
- `lab/profiles/adversarial-collision.env` — AD-colliding force-user
  (`Administrator`). Used by exactly one scenario:
  `collision-refused`. EXPECTS rc=9.

```bash
lab/run-scenario.sh frontend-share    --profile adversarial-positive
lab/run-scenario.sh multi-share       --profile adversarial-positive
lab/run-scenario.sh collision-refused --profile adversarial-collision
```

Do NOT cross-contaminate. The profiles encode opposite
expectations and a confused matrix yields confused failures.

## What's NOT in the gate

The "Important Tests To Add" section of
`smb-proxy-appliance/docs/LAB-TESTING.md` lists scenarios that
would be valuable but are not gating today (e.g.
`hardening-ws2025`, `firewall-apply`, `legacy-backend-down-recovery`,
`verify-from-ws2025`). The upgrade and lifecycle scenarios planned in
`audits/2026-10-07-dust-off.md` §3 (T-UPG-*, T-PROXY-*, T-DC-*) join
this list as they land. Scenarios are added here when they exist,
not before.

Most TUI flows are exercised by hand on the same `golden-image`
snapshot the scenarios use. The exception is the AD DC console
SSH-key entry, which `samba-addc-appliance/tests/run-tui-inputbox-harness.sh`
drives through real dialog/whiptail screens in a PTY; CI runs it in
a container.
