# Quake 3 Server (QuakeJS) on Docker Compose

[![Deployment Verification](https://github.com/heyvaldemar/quake3-server-docker-compose/actions/workflows/deployment-verification.yml/badge.svg?branch=main)](https://github.com/heyvaldemar/quake3-server-docker-compose/actions/workflows/deployment-verification.yml)
[![Publish Docker Image](https://github.com/heyvaldemar/quake3-server-docker-compose/actions/workflows/00-publish-docker-image.yml/badge.svg?branch=main)](https://github.com/heyvaldemar/quake3-server-docker-compose/actions/workflows/00-publish-docker-image.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This repository runs a dedicated Quake 3 Arena server with the QuakeJS web client in one container: players open the server's address in a browser and play, no client install. The image is built from this repository (Dockerfile, vendored QuakeJS, game assets baked in) and published to Docker Hub as [`heyvaldemar/quake3-server`](https://hub.docker.com/r/heyvaldemar/quake3-server).

📙 The complete installation guide is on my [website](https://www.heyvaldemar.com/install-quake3-server-using-docker-compose/).

## Getting started

```bash
# 1. Clone
git clone https://github.com/heyvaldemar/quake3-server-docker-compose
cd quake3-server-docker-compose

# 2. Configure: the RCON password is required, everything else has a default
cp .env.example .env
$EDITOR .env          # RCON_PASSWORD (generate one: openssl rand -base64 24 | tr -d '/+=' | head -c 32)
                      # QUAKE3_SERVER_IP_OR_HOSTNAME: the public address players use

# 3. Deploy
docker compose -f quake3-server-docker-compose.yml -p quake3-server up -d
```

Open `http://<your-server>/` in a browser to play. Native Quake 3 clients are not supported: QuakeJS speaks WebSocket on port 27960, not the original UDP protocol.

`server.cfg` next to the compose file is the game configuration (hostname, map rotation, bots, limits). It is bind-mounted into the container; the entrypoint injects `RCON_PASSWORD` into it at start, so the file itself never carries the password. Apply a change with:

```bash
docker compose -f quake3-server-docker-compose.yml -p quake3-server restart
```

### What success looks like

```bash
docker compose -f quake3-server-docker-compose.yml -p quake3-server logs | grep -E "Apache|Opening IP socket|InitGame|entered the game"
#  * Starting Apache httpd web server apache2
# Opening IP socket: 0.0.0.0:27960
# InitGame: \fs_cdn\127.0.0.1:80\...\mapname\q3dm1\sv_hostname\heyvaldemar.com - Quake 3 Server\...
# broadcast: print "Daemia^7 entered the game\n"     <- bots fill the server (bot_minplayers in server.cfg)
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1/
# 200
```

### Common first-deploy issues

- **Container exits immediately with `RCON_PASSWORD is still the .env.example placeholder`.** The entrypoint refuses the placeholder and anything shorter than 16 characters. Set a real value in `.env` and `up -d` again.
- **The page loads but the client cannot connect.** `QUAKE3_SERVER_IP_OR_HOSTNAME` must be the address players reach the server at (public IP or DNS name), not `0.0.0.0` and not the Docker-internal address; the web client is told to connect there.
- **Players outside your network cannot join.** Open 80/tcp (web client) and 27960/tcp (game traffic over WebSocket) in the firewall.

## Supply chain trust

Most repositories in this fleet pin an upstream image. This one ships its own: the image is built from the `Dockerfile` here by the [Publish Docker Image](https://github.com/heyvaldemar/quake3-server-docker-compose/actions/workflows/00-publish-docker-image.yml) workflow, pushed to Docker Hub tagged `latest` and with the commit it was built from, and pinned as `<commit-tag>@sha256:<digest>` in the compose `x-images` block. The publish workflow commits the new pin after every build, so `git pull` alone delivers the exact image CI built and booted. Earlier revisions deployed from a floating `latest`.

Two override levels exist per image. `<PREFIX>_IMAGE_VERSION` in `.env` swaps only the version of that image (Compose then pulls the tag, without a digest) and leaves every other pin as tested; `<PREFIX>_IMAGE_TAG` replaces the whole reference, digest included. The variable names are listed in `.env.example`. Nested defaults need Docker Compose v2.5 or newer (2022); v2.0 to v2.4 leave the inner `${...}` unexpanded and `docker compose up` fails with an invalid reference instead of deploying something unexpected.

Deployment Verification rebuilds the image from the checkout on every push and daily, scans the build with Trivy, and the daily `check-pin-freshness` job fails if the pin no longer matches the latest published build. GitHub Actions are pinned by commit SHA; Dependabot keeps those and the `ubuntu` base image fresh.

To run your own build instead, set `QUAKE3_SERVER_IMAGE_TAG` in `.env` (for example `docker build -t my/quake3-server .` and `QUAKE3_SERVER_IMAGE_TAG=my/quake3-server`).

## Production checklist

- [ ] **Generate `RCON_PASSWORD`** with `openssl rand -base64 24 | tr -d '/+=' | head -c 32`. Anyone with it can kick players, change maps and shut the server down.
- [ ] **Set `QUAKE3_SERVER_IP_OR_HOSTNAME`** to the public address; put a DNS name in front if players should not learn the IP.
- [ ] **Open 80/tcp and 27960/tcp** in the firewall; nothing else needs to be public. Put a TLS-terminating proxy in front of port 80 if the page should be served over HTTPS.
- [ ] **Keep `server.cfg` in your own git repository**: it is the whole server state worth keeping.
- [ ] **Rotate the RCON password** if you deployed before 2026-04-23: the pre-rotation value that was hardcoded in `server.cfg` remains in git history and is compromised. See [SECURITY.md](SECURITY.md).

## Unattended updates

Releases are the update channel: a tag is cut only after CI has built the image, booted the stack, and passed the smoke tests. `update.sh` moves a deployment to the newest tag and nothing else:

```bash
./update.sh --dry-run   # show what would be applied
./update.sh             # update within the current major and redeploy
```

Put it on a timer for hands-off minor/patch updates:

```bash
# crontab -e
17 5 * * *  /opt/quake3-server-docker-compose/update.sh >> /var/log/quake3-server-update.log 2>&1
```

The script refuses to cross a MAJOR template version on its own: majors are breaking by definition and their release notes exist to be read. After reading them, `./update.sh --allow-major` performs the jump. It also refuses to touch a checkout with local modifications: your customization belongs in `.env` and `server.cfg`, which updates never overwrite.

This is deliberately a host-side script and not a container in the stack: an in-stack updater needs the Docker socket (root on the host) and turns "someone pushed to a repo" into "someone deployed to your machine" with no operator in the loop. A cron job under your own user updates only to tagged, CI-verified states and leaves the trust boundary where it was.

## Resource limits

The service carries memory and CPU limits plus reservations as compose-level defaults, the same values CI boots the stack under. Override any of them in `.env` (the knobs and their defaults are listed in `.env.example`, e.g. `QUAKE3_SERVER_MEMORY_LIMIT=1g`) and the override survives every `git pull`. If the server is OOM-killed with many players and bots, `docker inspect <container> --format '{{.State.OOMKilled}}'` says so; raise `QUAKE3_SERVER_MEMORY_LIMIT` and recreate.

## Backups

The server is stateless. `server.cfg` and `.env` next to the compose file are the whole configuration; the game assets live inside the image and are rebuilt from this repository. Keep those two files in your own git repository (without the password: `.env` is gitignored here for that reason) and a rebuild of the host is `git clone`, restore `.env`, `up -d`.

## Container hardening

The container runs with `security_opt: no-new-privileges:true`, so a process cannot gain privileges through setuid binaries even if it escapes its initial capability set. It keeps the default capability set on purpose: the entrypoint starts Apache as root to bind port 80 and the dedicated server alongside it, and CI boots the stack under exactly these settings on every push, so what ships is what was tested.

## Testing

The [Deployment Verification](https://github.com/heyvaldemar/quake3-server-docker-compose/actions/workflows/deployment-verification.yml?query=branch%3Amain) workflow runs on every push, pull request, and every day at 06:00 UTC: ShellCheck, hadolint and actionlint; a build of the image from the checkout; a Trivy scan of that build; a deploy job that boots the stack with an ephemeral RCON password and requires the web client to answer 200 and the game port to listen; and, on the daily run, the pin freshness check against Docker Hub.

---

## About the maintainer

<div align="center">

**Maintained by [Vladimir Mikhalev](https://github.com/heyvaldemar)** · Docker Captain · IBM Champion · AWS Community Builder

[YouTube](https://www.youtube.com/channel/UCf85kQ0u1sYTTTyKVpxrlyQ?sub_confirmation=1) · [Blog](https://heyvaldemar.com) · [LinkedIn](https://www.linkedin.com/in/heyvaldemar/)

</div>
