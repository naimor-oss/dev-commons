# Release gate

The fixed list of checks that runs before any sibling-repo change is
considered "ready to ship to the production proxy / DC". Two phases:

1. **Preflight** (no VM, ~30 s). One command:

    ```bash
    dev-commons/bin/preflight.sh
    ```

    Chains: cross-repo `sanity-check.sh`, per-appliance `bash -n` on
    every entry-point script, `appliance-core` bats unit tests
    (182 cases), `smb-proxy` unit-helpers (96 cases). Bails on first
    failure with the failing repo + step named.

2. **VM gate** (lab Hyper-V cluster, ~30–45 min total). Nine
    scenarios across two appliances, in order:

    | # | Repo | Scenario | Notes |
    | - | ---- | -------- | ----- |
    | 1 | `samba-addc-appliance` | `smoke-prepared-image` | freshly-rebuilt golden image is sane (`apt-helpers`, `detect-net` resolve correctly; firstboot marker not consumed) |
    | 2 | `samba-addc-appliance` | `provision-new` | full forest provision; covers `domain_provision_new` TUI/CLI, hardening, post-provision setup, TLS cert |
    | 3 | `samba-addc-appliance` | `dfs-namespace` | DFS-N convergence, sentinel guard, empty-result guard, scheduling unit ReadWritePaths matches runtime DFS_ROOT |
    | 4 | `smb-proxy-appliance` | `smoke-prepared-image` | proxy golden-image sanity |
    | 5 | `smb-proxy-appliance` | `join-domain` | AD join via WS2025-DC1, winbind reachable |
    | 6 | `smb-proxy-appliance` | `backend-mount` | cifs mount with locking-correct options (vers=1.0, nobrl, cache=none, serverino, **numeric** uid=/gid=) |
    | 7 | `smb-proxy-appliance` | `frontend-share` | full backend+frontend; `force user` is **username**, `valid users` is SID, /etc/passwd resolves to a real UID |
    | 8 | `smb-proxy-appliance` | `multi-share` | two shares from one backend with distinct creds + identities; `remove_share` per-share scoping |
    | 9 | `smb-proxy-appliance` | `collision-refused` | NEGATIVE: AD-colliding force-user → rc=9 + no orphan creds/fstab/smb.conf/state/passwd |

    Run order matters for #1→#3 and #4→#9 (each later scenario
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
would be valuable but are not gating today (e.g. `tps-lock-isolation`,
`hardening-ws2025`, `firewall-apply`, `legacy-backend-down-recovery`,
`verify-from-ws2025`). When those land they get added here,
not before.

UI / TUI flows are not in the gate. The TUI is exercised by hand
on the same `golden-image` snapshot the scenarios use; an automated
TUI scenario would need `expect`-style I/O and is not worth the
maintenance cost for a single-operator shop.
