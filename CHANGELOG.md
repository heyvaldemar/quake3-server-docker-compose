# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_(no unreleased changes yet)_

## [1.3.0] - 2026-09-03

### Security

- **Container hardening.** Every service runs with
  `security_opt: no-new-privileges:true` (no privilege escalation via
  setuid binaries even if a process escapes its initial capability
  set). Infrastructure containers (the reverse proxy, databases,
  caches, backups) drop every Linux capability and add back only what
  their entrypoints need (bind :80/:443, chown a data directory, drop to
  the service user). Application containers keep the default capability
  set: upstream images assume it, and a wrong guess there is a boot loop
  in production, not a hardening win. CI boots the stack under these
  settings on every push.

## [1.2.0] - 2026-09-02

### Added

- **Resource limits on every service, as `.env`-overridable defaults.**
  Each service now carries memory and CPU limits plus reservations
  (`<SERVICE>_MEMORY_LIMIT`, `_CPU_LIMIT`, `_MEMORY_RESERVATION`,
  `_CPU_RESERVATION`, defaults listed in `.env.example`). Set any of
  them in `.env` and the override survives every `git pull`. The
  defaults are what CI boots the stack under, so they are known to be
  enough for a fresh install; raise a limit if a service is OOM-killed
  under your real load (`docker inspect` shows `OOMKilled=true`).

## [1.1.0] - 2026-09-02

### Added

- **`update.sh`** — unattended updates to the newest tagged release,
  and nothing else: a tag is cut only after CI has booted the pinned
  images and passed the smoke tests, so "update to the latest tag" means
  "update to a combination a machine has already run". It refuses to
  cross a major version on its own (`--allow-major` after reading the
  notes), refuses a checkout with local modifications, and supports
  `--dry-run`. Put it on a cron timer for hands-off minor/patch updates.

## [1.0.0] - 2026-09-01

### Fixed (the server could no longer start at all)

- **Game assets now come from inside the image.** The public
  content.quakejs.com CDN is dead (http 301s to an https endpoint that
  answers 526), and the dedicated server downloaded its paks from there
  on every start — so every fresh container failed with "Failed to
  download and parse manifest". The assets were already vendored under
  `/var/www/html/assets`; `fs_cdn` now points at the container's own
  Apache.
- **`+set dedicated 1` reached the engine for the first time** — the old
  command line was missing the `+` on `set dedicated 1`.
- **RCON substitution works with the compose bind mount**: `sed -i`
  replaces files by rename, which fails on a bind-mounted single file
  ("Device or resource busy") and, under `set -e`, put the container in
  a restart loop. The placeholder substitution now overwrites file
  contents in place.
- **The npm dependency builds again**: the original `inolen/quakejs-files`
  repository and npm package are gone; the build installs the surviving
  fork's tarball.
- Dockerfile lint findings (`--no-install-recommends`, `pipefail`); a
  removed input on `docker/setup-buildx-action` v4 in the publish
  workflow.

### Added

- **Deployment Verification workflow**: shellcheck + hadolint +
  actionlint, then a job that builds the image from the checkout, boots
  the compose stack, and requires the QuakeJS web client to answer and
  the game port to be reachable.

### Added (pre-1.0, unreleased)
- `LICENSE` — canonical MIT license text at repo root.
- `SECURITY.md` — vulnerability disclosure policy, supported versions, and a
  callout for the pre-PR-#14 RCON password rotation advisory.
- `CHANGELOG.md` — this file, Keep-a-Changelog format.
- `.hadolint.yaml` — Dockerfile lint configuration, matching the standard used
  across the maintainer's other public repositories.
- `.dockerignore` — keeps repo metadata (`.git`, `.github`, docs) out of the
  Docker build context.

### Changed
- Dependabot groups minor/patch `github-actions` and `docker` ecosystem bumps
  into a single PR each week; major bumps continue to open individual PRs.

### Removed
- `.github/FUNDING.yml` — sponsor discovery moves to heyvaldemar.com.

### Security
- RCON password rotated out of `server.cfg` in PR #14 (merged 2026-04-23).
  `server.cfg` now contains a `%RCON_PASSWORD%` placeholder that is
  substituted at container startup from the `RCON_PASSWORD` env var.
  `entrypoint.sh` rejects unset, empty, `change_me_*` placeholder, and
  sub-16-character values. The old committed password remains in git history
  but is no longer usable against any server running the current image.

## Project history prior to this changelog

Earlier commits did not follow Keep-a-Changelog. Highlights:

- **2024 (initial commit):** QuakeJS-based Docker image for Quake 3 dedicated
  server with Apache-served web client on port 80 and native server on 27960.
- **2024–2025:** iterative Dockerfile fixes (HTTPS git URL for dead npm
  dependency, Node.js 22 via NodeSource, timezone env, apt hardening).
- **2026-04:** beginning of the supply-chain hardening track aligned with
  [heyvaldemar/aws-kubectl-docker](https://github.com/heyvaldemar/aws-kubectl-docker).

[Unreleased]: https://github.com/heyvaldemar/quake3-server-docker-compose/commits/main

[Unreleased]: https://github.com/heyvaldemar/quake3-server-docker-compose/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/heyvaldemar/quake3-server-docker-compose/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/heyvaldemar/quake3-server-docker-compose/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/heyvaldemar/quake3-server-docker-compose/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/heyvaldemar/quake3-server-docker-compose/releases/tag/v1.0.0
