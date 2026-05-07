# Pre-Publish Checklist

Run this before pushing any sibling repo to a public remote (today:
the planned `naimor-oss` GitHub org — see
[`decisions/0001-github-org-naimor-oss.md`](decisions/0001-github-org-naimor-oss.md)).

The checklist is intentionally short and biased toward "stop and
think" rather than mechanized scanning. A linter would catch the
mechanical patterns and miss the judgment calls.

## Per-repo gates

### 1. Credentials and secrets in tracked content

Search the working tree for credential-shaped patterns:

```bash
cd <repo>
git grep -nE 'pass(word)?\s*[:=]|credential|secret|api[_-]?key|token' \
    -- ':!*.example' ':!*.md.example' \
    | grep -vE 'example|placeholder|REPLACE|YOUR|FIXME|<.+>' \
    | less
```

Any literal-looking credential is a stop. Required actions:

1. **Rotate the credential** in production (it's already in
   working memory, the working tree, and your `git log`; assume
   compromise).
2. Replace the literal value with a placeholder
   (`<rotate-this-on-publish>`, `<see-internal-vault>`, etc.).
3. If the credential is in a deeply historical commit, decide
   whether the rotated-and-replaced state is enough (usually yes)
   or whether to rewrite history with BFG/`git filter-repo` (rare;
   only if the cred would still be sensitive after rotation).

**Known instance** (resolved 2026-05-01):
`smb-proxy-appliance/docs/sketch-smb1-smb3-proxy.sh` previously
contained a real legacy-backend password for the example backend
user. The production credential was rotated 2026-05-01 and the
literal value in the file replaced with the placeholder
`<ROTATED-2026-05-01-see-internal-vault>`. Git history retains the
old literal but it is operationally neutered. No further action
needed before publishing the proxy repo on this account.

### 2. Workplace-identifying content

The org name (`naimor-oss`) and domain (`oss.naimorinc.com`) make
workplace identity intentional. But check that internal hostnames,
private IPs, employee names/emails, and use-case-specific share
or user names haven't drifted in where they aren't useful.

```bash
git grep -nE 'naimor|naimorinc' -- ':!*.md' ':!docs/sketch*'
git grep -nE '\b(192\.168|10\.|172\.(1[6-9]|2[0-9]|3[01]))' \
    -- ':!docs/sketch*' ':!lab/'
```

Lab IPs (`10.10.10.0/24`) and intentional examples are fine — they're
disposable. Production IPs showing up outside `docs/sketch*` and
`lab/` warrant a look.

Sample names in tests and examples should be generic
(`Engineering`, `engineering_user`, `Sample`, etc.), not
workplace-internal share names.

### 3. Operator-facing surface check

Per `STYLE.md` §15 (builder/operator boundary), text that ends up
in front of an operator should read as boring system administration.
Spot-check:

- Appliance MOTD / `/etc/update-motd.d/*`
- `<name>-init` console wizard text
- Any `printf` or `echo` in the appliance scripts that reaches a
  login session

Words that flag bespoke nature ("custom", "in-house", "tailored",
"appliance" used unnecessarily) should be softened on operator
surfaces, kept as-is on builder surfaces.

### 4. License and attribution

Each repo gets a `LICENSE` file before publishing. Default choice
is decided per repo at publish time; if nothing else, `MIT` for
permissive or `AGPL-3.0` for the appliance images that touch
network services. Add a `NOTICE` if any third-party content is
embedded.

### 5. README sanity

The repo's `README.md` should make sense to a stranger landing on
the GitHub project page:

- One-paragraph purpose at the top
- "Where do I start?" table
- Sibling layout if relevant
- License clearly visible
- Any required external setup (Hyper-V, qemu-img, etc.) called out

### 6. CI / Pages / Issues setup

After the first push:

- Issues enabled (if accepting community input)
- GitHub Pages disabled per-repo (the org's `oss.naimorinc.com`
  Pages is the consolidated face)
- No CI yet; add only when there's something worth running in CI
- Topics / description set so the repo shows up sensibly on the
  org's repo grid

## Org-level gates (one-time, before first repo lands)

Before pushing the first sibling to `naimor-oss`:

- Org created on GitHub with name `naimor-oss`
- DNS for `oss.naimorinc.com` configured per GitHub Pages docs
  (CNAME → `naimor-oss.github.io`)
- A landing site lives at `oss.naimorinc.com` — either
  `naimor-oss/.github` profile README or `naimor-oss/oss-site`
  Pages repo. One-page; lists the projects, frames the org's
  scope, links into the per-repo READMEs.
- Org-level security: 2FA required for all members, dependabot
  alerts on by default

## Per-publish log

Each first-push event gets a one-line entry below so the timeline
is recoverable.

| Date | Repo | Pushed by | Notes |
| --- | --- | --- | --- |
| 2026-05-07 | `naimor-oss/.github` | hooman | Org profile repo. First push to the new `naimor-oss` org. |
| 2026-05-07 | `naimor-oss/dev-commons` | hooman | First push. |
| 2026-05-07 | `naimor-oss/lab-kit` | hooman | First push. Also: pre-existing `hooman/lab-kit` (pushed 2026-05-02 with pre-generalization history) was deleted before this push. |
| 2026-05-07 | `naimor-oss/lab-router` | hooman | First push. Pre-existing `hooman/lab-router` deleted before this push. |
| 2026-05-07 | `naimor-oss/samba-addc-appliance` | hooman | First push. Pre-existing `hooman/samba-addc-appliance` deleted before this push. |
| 2026-05-07 | `naimor-oss/smb-proxy-appliance` | hooman | First push. |
