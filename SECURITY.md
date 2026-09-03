# Security Policy

## Supported Versions

| Version                                        | Status             |
|------------------------------------------------|--------------------|
| Current `main` and the latest tagged release   | :white_check_mark: |
| Older tags without a recent rebuild            | :x:                |

Fixes land on `main` and ship as a new tag; older tags are not patched in place.

## Reporting a Vulnerability

Send reports to **v@valdemar.ai**. Encrypted email is preferred; the PGP public key is published at [heyvaldemar.com/security](https://heyvaldemar.com/security).

You can expect an acknowledgment within **7 days**. This project does not operate a bounty program; researchers who submit valid, responsibly disclosed reports receive public credit in the release notes and the changelog.

Please do not open public GitHub issues for security reports.

## Supply Chain Trust

Unlike most repositories in this fleet, this one ships its own image: `heyvaldemar/quake3-server` is built from the `Dockerfile` here by the "Publish Docker Image to Registry" workflow, tagged with the commit it was built from, and pinned by digest as the interpolation default in the compose file's `x-images` block. The publish workflow commits that pin after every build, so a plain `git pull` delivers the exact image CI built and booted. Deployment Verification rebuilds the image on every push and daily, scans it with Trivy, checks that the pin still matches the latest published build, and boots the stack. GitHub Actions are pinned by commit SHA.

## Credentials

`.env` is gitignored and `RCON_PASSWORD` fails fast at deploy time: the entrypoint refuses the `.env.example` placeholder and anything shorter than 16 characters.

## Known historical issue

Prior to PR #14 (merged 2026-04-23), `server.cfg` committed a hardcoded RCON password. The password remains in git history but is no longer referenced by any live code; the current entrypoint rejects that password. Anyone who deployed with the pre-rotation configuration should rotate their live server's RCON password. See PR #14 for details.
