# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
