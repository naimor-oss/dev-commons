# 0003 — Root suites run locally, and preflight asks for their result

**Status**: accepted
**Date**: 2026-10-29

## Context

The root integration suites (`tests/root/*.sh`) run as root against
real system paths, so each needs a disposable Debian 13 container. The
shared `preflight` workflow pulled that image on every run of every
sibling, anonymously, from GitHub's hosted runners. Those share IP
addresses, and each registry refused in turn: Docker Hub's rate limit,
then ECR Public's data limit. A fallback across three registries
worked, but kept the download on every run.

## Decision

- The suites run on a machine with Docker, through `bin/root-tests.sh`,
  where the image is pulled once and cached. `preflight` doesn't run
  them.
- A pull request whose change a root suite exercises states a passing
  run in its description: `root integration suites run: N, failed: 0`.
  A change counts when its repo has root suites, or a root suite uses
  the repo as a sibling (`../<repo>`), and it touches anything but
  documentation.
- `preflight` fails such a pull request without that line
  (`bin/root-suite-gate.sh`). The description is read when the job
  runs, so adding the line and re-running the job clears it.

## Consequences

- `preflight` no longer downloads an image, so registry limits can't
  fail it.
- The line is the author's statement, not proof: the run happens off
  GitHub, and nothing ties it to the pull request's last commit. A
  push after the run needs a new run and an updated line.
- An environment without Docker can't produce the line, so its pull
  requests wait for someone who has Docker.
