# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **CI looks for the rcon password everywhere it could leak to.** `tests/secret-probe.sh` gives `RCON_PASSWORD` a value of its own and fails on it in `docker compose logs`, on any command line in the container or in the host's `ps`, after the first start, while an rcon client runs and after a restart; it names the variable and the place, never the value. It found nothing ([run 43620383525](https://github.com/heyvaldemar/quake3-server-docker-compose/actions/runs/43620383525)).
- **A stop is measured.** `tests/clean-stop.sh` times `docker compose stop`: 10 seconds of Docker's default 10-second grace period, exit 137, Docker's SIGKILL. node, process 1, does not act on SIGTERM, so every stop waits the ten seconds. Quake III keeps no world to save; the README says so.

## [1.6.3] - 2026-11-08

### Security

- **A password this repository published is refused at start.** Two RCON passwords are in this repository's history for anyone to read: the one hardcoded in `server.cfg` until 2026-04-23, and the one committed on 2026-09-03 and shipped in v1.3.0 through v1.6.0. Since v1.6.2 lets client packets reach the server, a `server.cfg` kept from those releases, or an `RCON_PASSWORD` copied from one, would hand rcon to anyone. The entrypoint now hashes every `rconpassword` the rendered configs set and refuses to start on either value, with an error that says how to fix it. Only their SHA-256 is in the image, and the value is never printed. CI plants v1.6.0's `server.cfg`, and the same value as `RCON_PASSWORD`, requires the refusal with the value in no log line, and requires rcon to answer the password from `.env` and refuse a wrong one.

### Fixed

- **A compose file older than v1.6.1 stops with a reason instead of restarting forever.** Up to v1.6.0 the compose file mounted `server.cfg` itself; the entrypoint since v1.6.1 renders a fresh `server.cfg` and could not remove a mount point, so an image from v1.6.1 on, started by an old compose file, died on "Device or resource busy" and restarted in a loop. It now says the compose file is older than v1.6.1 and that the repository must be updated with the image. CI starts v1.6.0's compose file on this image and requires that error.
- **The v1.6.1 entry and SECURITY.md said more than happened.** They said every server on v1.3.0 through v1.6.0 answered rcon to the published password; none answered rcon at all, because no client packet reached the server before v1.6.2. SECURITY.md also said the entrypoint rejected the password hardcoded until 2026-04-23, and nothing did until this release. Both texts keep the original words, struck out, with the correction and its date; so do the v1.6.1 release notes.

### Upgrading

- **Update the repository together with the image:** `./update.sh` (or `git pull`), then `docker compose up -d`. A compose file from v1.0.0 to v1.6.0 cannot start an image from v1.6.1 on: until this release it restarted forever on "Device or resource busy", now it stops and says why. That is the safe direction, since nothing runs on a config the image cannot render, but the server is down until the repository is updated.
- **If `.env` sets `QUAKE3_SERVER_IMAGE_TAG=heyvaldemar/quake3-server:latest`**, remove that line. v1.0.0's `.env.example` set it uncommented, and with it every pull moves the image while the compose file stays where it was; since `latest` became the v1.6.1 build on 2026-11-08, such a host stops at start as above. Without the line, the compose file's pin applies: the image this release was tested with.
- **If the server refuses to start with "an rconpassword this repository once published"**, put `seta rconpassword "%RCON_PASSWORD%"` back in `server.cfg` and set a new `RCON_PASSWORD` in `.env`.
## [1.6.2] - 2026-11-08

### Fixed

- **Players can join again; in every release up to v1.6.1 nobody could.** Dependabot moved the `ws` library in `quakejs/package.json` from 0.4 to 8 before v1.0.0, and ws 8 passes a boolean `isBinary` to its message event where ws 0.4 passed a `flags` object. The engine's socket layer (`include/ioq3ded/ioq3ded.fixed.js`) tested `flags.binary`, which is undefined on a boolean, and dropped every packet a client sent as a text frame: connection requests included. The bots played on and the log looked busy. Measured on the image v1.6.1 shipped: Quake 3's `getstatus`, sent through the game's WebSocket, gets no answer; with the one line corrected, `statusResponse`. Text frames are still dropped.
- **The health check asks the game, not the WebSocket proxy.** It accepted the 101 of a WebSocket handshake, which the ws library answers before any game code runs, so it called the deaf server above healthy for every release. `/healthcheck.js`, built into the image and named by the compose file, sends `getstatus` through the players' WebSocket and is healthy only on a `statusResponse`, which only a running game loop writes. It never reads the log: in QuakeJS the intermission after the fraglimit ends only when a human is ready, bots never are, and an empty server can stand silent on the scoreboard for hours. CI now requires the health check to pass on that scoreboard (fraglimit 1 with the shipped bots, then 90 seconds with no log line), and runs it against the image v1.6.1 shipped, where the old check passes and this one must fail.
## [1.6.1] - 2026-11-08

### Security

- **`RCON_PASSWORD` is the password the server uses again.** From v1.3.0 through v1.6.0, `server.cfg` carried a literal RCON password where the `%RCON_PASSWORD%` placeholder belonged: the entrypoint rewrote the bind-mounted `server.cfg` in place at every start, so the password of one run ended up in a working copy and was committed with it on 2026-09-03 (5afa1fb). With the placeholder gone, `RCON_PASSWORD` from `.env` was silently ignored~~, and every server on those releases, and the image built from them, answered rcon to the password published in this repository~~. *Corrected 2026-11-08: the struck-out claim was wrong. Up to v1.6.2 no packet a client sent reached the server (see 1.6.2), so no server on those releases answered rcon at all; measured on the images v1.3.0, v1.6.0 and v1.6.1 shipped, rcon with that password got no answer. The one way it works is v1.6.2 started with a `server.cfg` kept from those releases, and v1.6.3 refuses to start on it.* The placeholder is back; the compose file mounts `server.cfg` read-only as a template, and the entrypoint renders it into the config the server reads inside the container (mode 600), so the checkout's file never changes; a template without the placeholder gets a loud warning at start. CI now checks that the server's config carries `RCON_PASSWORD` and that the checkout's `server.cfg` still carries the placeholder after a start. **Upgrade if you run any of those releases.**
- **The RCON password is no longer on a command line.** The entrypoint substituted it with `sed "s|%RCON_PASSWORD%|<password>|g"`, putting it in `sed`'s arguments, which every user on the host reads with `ps`. `awk` now takes it from its environment and splices it in by position, so `|`, `&` and `\` in a password are no longer read as syntax either. CI reads every command line on the runner and in the container and requires the password on none.

### Added

- **CI fails on an anonymous volume.** A `VOLUME` an image declares and no mount covers becomes an anonymous volume: never backed up, and replaced by an empty one on `down`/`up`. The deployment verification now inspects every container it starts and fails on one, unless `.github/anonymous-volumes` lists it with the reason. GLPI's data lived in exactly such a volume from 2026-08-31 to 2026-10-11.

### Changed

- **The freshness check has its own workflow, Pin Freshness.** It ran inside Deployment Verification, whose badge is the one at the top of this README. Across the fleet, nine red runs in ten were a pin one version behind - which the fleet's triage moves within the day - and a reader cannot tell that from a stack that does not boot. The badge now says whether the stack boots. The job itself is unchanged.

### Fixed

- **`update.sh` no longer stops without a word when a release adds a variable and no compose file requires one.** The search for `${VAR:?}` came back empty, and under `pipefail` that empty result ended the script with status 1 right after it listed the new variables.
- **`update.sh` stops on a `.env` it cannot read, before the checkout.** It used to fall through: every new required variable read as "not set", or, with none, the tree moved to the new tag and `docker compose up` failed on the permission. Now it names the file, its owner and mode, and changes nothing.

## [1.6.0] - 2026-09-22

### Added

- **`QUAKE3_SERVER_TIMEZONE`: the game gets the household clock too.** Every timestamp this server writes — a ban, a join, the crash it leaves behind — is read next to a log line from somewhere else, and two clocks turn that into arithmetic. Six of this fleet's eleven game templates already carried the setting and this one did not. It defaults to UTC, which is now a choice rather than an accident, and the image carries the whole tz database so any zone name works. Measured against the pinned image: unset gives `UTC`, set gives the zone asked for.

## [1.5.1] - 2026-09-07

### Changed

- **`update.sh` names any new required variable before it moves.** An update can add a required variable; `docker compose up` used to stop on it after the checkout, with the tree already on the new tag. The script now lists the variables that appeared in `.env.example` since your version and refuses, before anything has moved, when a required one is not in your `.env`. Names only, never values.

connect to
  27960 also still succeeds, because the kernel accepts into the listen backlog
  of a stopped process. Both would report a healthy container with a dead game.
  QuakeJS speaks WebSocket, so the check completes a handshake and requires
  `101 Switching Protocols`, which only node can answer. Verified in both
  directions against a running stack: healthy while the game is up, unhealthy
  within three intervals of node being stopped, healthy again when it resumes.

### Changed

- **The memory limit now says why it is what it is.** Given no limit this
  server settles around 840 MB with bots playing, which makes the shipped
  512 MB default look wrong. Measured, it is not: held to 512m the process runs
  at 470 to 490 MB and is not OOM-killed, because the engine sizes its heap to
  the cgroup it finds itself in. The note exists so nobody raises the limit on
  the strength of an unconstrained reading, the way this was nearly changed.

## [1.4.0] - 2026-09-03

### Added

- **Per-image version overrides.** Every pin in the `x-images` block is
  now `${<PREFIX>_IMAGE_TAG:-repo:${<PREFIX>_IMAGE_VERSION:-tag@sha256:digest}}`.
  Set `<PREFIX>_IMAGE_VERSION` in `.env` to run a different version of one
  image while every other pin stays as tested (Compose pulls that tag
  without a digest), or `<PREFIX>_IMAGE_TAG` to replace the whole
  reference as before. A deployment that sets neither is unchanged. The
  freshness job, the Trivy matrix and the fleet digest automation resolve
  the nested default before reading a pin. Needs Docker Compose v2.5 or
  newer (2022): v2.0 to v2.4 leave the inner `${...}` unexpanded and
  `docker compose up` fails with an invalid reference instead of
  deploying something unexpected.

## [1.3.0] - 2026-09-03

### Added

- **The image is pinned by digest, as the compose default.** The
  `x-images` block now carries `heyvaldemar/quake3-server:<commit>@sha256:<digest>`
  and the publish workflow commits the new pin after every build, so
  `git pull` delivers the exact image CI built and booted. Earlier
  revisions pulled a floating `latest` (`.env.example` set it), which
  meant a fresh install could get an image no run had tested.
- **The publish workflow runs only when the image changes** (Dockerfile,
  entrypoint, `server.cfg`, the vendored QuakeJS and assets), instead of
  rebuilding and re-tagging `latest` on every documentation commit.
- **Trivy scan** of the freshly built image in Deployment Verification,
  with SARIF uploaded to the Security tab.
- **Daily `check-pin-freshness` job**: fails when the pinned tag
  re-resolves to a different digest or when the pin no longer matches
  the latest published build.

### Changed

- README rewritten to the fleet layout: getting started, what success
  looks like, first-deploy issues, supply chain trust, production
  checklist, unattended updates, resource limits, backups, hardening,
  testing.
- `update.sh` and CI use the compose project name `quake3-server`, the
  name the README has always used, instead of `quake3`.
- SECURITY.md describes how this repository's own image is built,
  pinned and scanned.

### Security

- **Container hardening.** The service runs with
  `security_opt: no-new-privileges:true`: no privilege escalation via
  setuid binaries even if a process escapes its initial capability set.
  The container keeps the default capability set on purpose (the
  entrypoint runs Apache and the dedicated server as root to bind
  port 80). CI boots the stack under these settings on every push.

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

- **`update.sh`**: unattended updates to the newest tagged release,
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
  on every start, so every fresh container failed with "Failed to
  download and parse manifest". The assets were already vendored under
  `/var/www/html/assets`; `fs_cdn` now points at the container's own
  Apache.
- **`+set dedicated 1` reached the engine for the first time**: the old
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
- `LICENSE`: canonical MIT license text at repo root.
- `SECURITY.md`: vulnerability disclosure policy, supported versions, and a
  callout for the pre-PR-#14 RCON password rotation advisory.
- `CHANGELOG.md`: this file, Keep-a-Changelog format.
- `.hadolint.yaml`: Dockerfile lint configuration, matching the standard used
  across the maintainer's other public repositories.
- `.dockerignore`: keeps repo metadata (`.git`, `.github`, docs) out of the
  Docker build context.

### Changed
- Dependabot groups minor/patch `github-actions` and `docker` ecosystem bumps
  into a single PR each week; major bumps continue to open individual PRs.

### Removed
- `.github/FUNDING.yml`: sponsor discovery moves to heyvaldemar.com.

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

[Unreleased]: https://github.com/heyvaldemar/quake3-server-docker-compose/compare/v1.6.3...HEAD
[1.6.3]: https://github.com/heyvaldemar/quake3-server-docker-compose/compare/v1.6.2...v1.6.3
[1.6.2]: https://github.com/heyvaldemar/quake3-server-docker-compose/compare/v1.6.1...v1.6.2
[1.6.1]: https://github.com/heyvaldemar/quake3-server-docker-compose/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/heyvaldemar/quake3-server-docker-compose/compare/v1.5.1...v1.6.0
[1.5.1]: https://github.com/heyvaldemar/quake3-server-docker-compose/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/heyvaldemar/quake3-server-docker-compose/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/heyvaldemar/quake3-server-docker-compose/compare/v1.3.0...v1.4.0

[Unreleased]: https://github.com/heyvaldemar/quake3-server-docker-compose/compare/v1.4.0...HEAD
[1.3.0]: https://github.com/heyvaldemar/quake3-server-docker-compose/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/heyvaldemar/quake3-server-docker-compose/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/heyvaldemar/quake3-server-docker-compose/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/heyvaldemar/quake3-server-docker-compose/releases/tag/v1.0.0
