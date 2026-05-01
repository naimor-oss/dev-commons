# Pre-Publish Checklist

Run this before pushing any sibling repo to a public remote (today:
the planned `NaimorOSS` GitHub org — see
[`decisions/0001-github-org-naimoross.md`](decisions/0001-github-org-naimoross.md)).

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

**Known instance**: `smb-proxy-appliance/docs/sketch-smb1-smb3-proxy.sh`
contains a real WS2008 backend password (`pfuser`). Must be rotated
+ replaced before that repo is published. Tracked here so it
doesn't get forgotten.

### 2. Workplace-identifying content

The org name (`NaimorOSS`) and domain (`oss.naimorinc.com`) make
workplace identity intentional. But check that internal hostnames,
private IPs, employee names/emails, and similar haven't drifted in
where they aren't useful.

```bash
git grep -nE 'naimor|naimorinc' -- ':!*.md' ':!docs/sketch*'
git grep -nE '\b(192\.168|10\.|172\.(1[6-9]|2[0-9]|3[01]))' \
    -- ':!docs/sketch*' ':!lab/'
```

Lab IPs (`10.10.10.0/24`) and intentional examples are fine — they're
disposable. Production IPs (`192.168.0.x`, `172.29.137.x`) showing
up outside `docs/sketch*` and `lab/` warrant a look.

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

Before pushing the first sibling to `NaimorOSS`:

- Org created on GitHub with name `NaimorOSS`
- DNS for `oss.naimorinc.com` configured per GitHub Pages docs
  (CNAME → `naimoross.github.io`)
- A landing site lives at `oss.naimorinc.com` — either
  `NaimorOSS/.github` profile README or `NaimorOSS/oss-site`
  Pages repo. One-page; lists the projects, frames the org's
  scope, links into the per-repo READMEs.
- Org-level security: 2FA required for all members, dependabot
  alerts on by default

## Per-publish log

Each first-push event gets a one-line entry below so the timeline
is recoverable.

| Date | Repo | Pushed by | Notes |
| --- | --- | --- | --- |
| _none yet_ | | | |
