# Security Policy

## Supported Versions

| Version                                                 | Status             |
|---------------------------------------------------------|--------------------|
| Current `latest` on Docker Hub + current `main` branch  | :white_check_mark: |
| Older tags                                              | :x:                |

A formal release / `v1-maintenance` split will be introduced alongside the upcoming non-root `v2.0` breaking release.

## Reporting a Vulnerability

Send reports to **v@valdemar.ai**. Encrypted email is preferred — the PGP public key is published at [heyvaldemar.com/security](https://heyvaldemar.com/security).

You can expect an acknowledgment within **7 days**. This project does not operate a bounty program; researchers who submit valid, responsibly disclosed reports receive public credit in the release notes and the changelog.

Please do not open public GitHub issues for security reports.

## Known historical issue

Prior to PR #14 (merged 2026-04-23), `server.cfg` committed a hardcoded RCON password. The password remains in git history but is no longer referenced by any live code; the current entrypoint rejects that password. Anyone who deployed with the pre-rotation configuration should rotate their live server's RCON password. See PR #14 for details.
