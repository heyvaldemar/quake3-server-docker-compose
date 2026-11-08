# Security Policy

## Supported versions

| Version                                        | Status             |
|------------------------------------------------|--------------------|
| Current `main` and the latest tagged release   | :white_check_mark: |
| Older tags without a recent rebuild            | :x:                |

Fixes land on `main` and ship as a new tag; older tags are not patched in place.

## Reporting a vulnerability

Report privately through GitHub: **Security → Report a vulnerability** on this repository (private vulnerability reporting is enabled). Email to v@valdemar.ai also works. The process is described at [heyvaldemar.com/security](https://heyvaldemar.com/security/).

You can expect an acknowledgment within 7 days. This project does not operate a bounty program; researchers who submit valid, responsibly disclosed reports receive public credit in the release notes and the changelog.

Please do not open public GitHub issues for security reports.

## Supply chain trust

Unlike most repositories in this fleet, this one ships its own image: `heyvaldemar/quake3-server` is built from the `Dockerfile` here by the "Publish Docker Image to Registry" workflow, tagged with the commit it was built from, and pinned by digest as the interpolation default in the compose file's `x-images` block. The publish workflow commits that pin after every build, so a plain `git pull` delivers the exact image CI built and booted. Deployment Verification rebuilds the image on every push and daily, scans it with Trivy and boots the stack; Pin Freshness checks daily that the pin still matches the latest published build. GitHub Actions are pinned by commit SHA.

## Credentials

`.env` is gitignored and `RCON_PASSWORD` fails fast at deploy time: the entrypoint refuses the `.env.example` placeholder and anything shorter than 16 characters.

## Known historical issue

Published advisory: [GHSA-v4wv-cfw6-w3gj](https://github.com/heyvaldemar/quake3-server-docker-compose/security/advisories/GHSA-v4wv-cfw6-w3gj) (2026-11-08, low). It covers both values below and the fix in v1.6.3.

Prior to PR #14 (merged 2026-04-23), `server.cfg` committed a hardcoded RCON password. The password remains in git history but is no longer referenced by any live code; ~~the current entrypoint rejects that password~~. *Corrected 2026-11-08: nothing rejected it until v1.6.3, whose entrypoint refuses to start on it.* Anyone who deployed with the pre-rotation configuration should rotate their live server's RCON password. See PR #14 for details.

From 2026-09-03 (commit 5afa1fb, released in v1.3.0 through v1.6.0), `server.cfg` again carried a literal RCON password where the `%RCON_PASSWORD%` placeholder belonged. The entrypoint rewrote the bind-mounted `server.cfg` in place at every start, so the password of one run ended up in a working copy and was committed with it. With the placeholder gone, `RCON_PASSWORD` from `.env` was silently ignored~~, and every server on those releases answered rcon to the password published in this repository~~. *Corrected 2026-11-08: the struck-out claim was wrong. Up to v1.6.2 no packet a client sent reached the server (see the 1.6.2 changelog), so no server on those releases answered rcon at all; measured on the images v1.3.0, v1.6.0 and v1.6.1 shipped, rcon with that password got no answer. The one way it works is v1.6.2 started with a `server.cfg` kept from those releases, and v1.6.3 refuses to start on it.* The release after them restores the placeholder, mounts `server.cfg` read-only as a template that the entrypoint renders inside the container, warns when a template has no placeholder, and CI checks that the server's config carries `RCON_PASSWORD` and that the checkout's file is untouched. Upgrade; the password in `.env` takes effect on the first start.

From v1.6.3 the entrypoint refuses to start when any `rconpassword` the rendered `server.cfg` sets is one of these two published values. Only their SHA-256 is in the image, and the value is never printed; CI plants v1.6.0's `server.cfg`, and the same value as `RCON_PASSWORD`, and requires the refusal.
