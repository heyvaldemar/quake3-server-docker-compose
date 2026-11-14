# Quake 3 Server (QuakeJS) on Docker Compose

[![Deployment Verification](https://github.com/heyvaldemar/quake3-server-docker-compose/actions/workflows/deployment-verification.yml/badge.svg?branch=main)](https://github.com/heyvaldemar/quake3-server-docker-compose/actions/workflows/deployment-verification.yml)
[![Publish Docker Image](https://github.com/heyvaldemar/quake3-server-docker-compose/actions/workflows/00-publish-docker-image.yml/badge.svg?branch=main)](https://github.com/heyvaldemar/quake3-server-docker-compose/actions/workflows/00-publish-docker-image.yml)
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/14887/badge)](https://www.bestpractices.dev/projects/14887)
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

**Up to v1.6.1 nobody could join.** Dependabot moved the `ws` library from 0.4 to 8 before the first release, and ws 8 changed the arguments of its message event: the engine's socket layer read every packet a client sent as text and dropped it. The bots played on, the log looked busy, and the health check, which accepted a WebSocket handshake, said healthy, because the ws library answers the handshake before any game code runs. From v1.6.2 the engine reads binary packets again, and the health check asks the game itself: it sends Quake 3's `getstatus` through the same WebSocket players use and is healthy only on a `statusResponse`. CI shows the difference on the image v1.6.1 shipped: the old check passes, the new one fails.

**An empty server can stand on the scoreboard for hours, and that is fine.** In QuakeJS (retail 1.32 game code) the intermission after the fraglimit ends only when a human is ready, and bots never are, so a server with only bots stays on the scoreboard and its log goes quiet. Nothing here judges health by the log; CI holds the server on that silent scoreboard and requires the health check to stay green.

`server.cfg` next to the compose file is the game configuration (hostname, map rotation, bots, limits). It is mounted read-only into the container as a template; at every start the entrypoint renders it, with `RCON_PASSWORD` in place of the `%RCON_PASSWORD%` placeholder, into the config the server reads inside the container, so this file never carries the password. Keep the placeholder line: without it the entrypoint warns that `RCON_PASSWORD` is not applied. Apply a change with:

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
- **Container exits with `sets an rconpassword this repository once published`.** Your `server.cfg`, or `RCON_PASSWORD`, carries one of the two passwords that are in this repository's history, which anyone can read. Put `seta rconpassword "%RCON_PASSWORD%"` back in `server.cfg`, set a new `RCON_PASSWORD` in `.env`, and `up -d` again.
- **Container exits with `is mounted from the host, so this compose file is older than v1.6.1`.** The image was updated without the repository. Run `./update.sh` (or `git pull`), then `docker compose up -d`; if `.env` sets `QUAKE3_SERVER_IMAGE_TAG=heyvaldemar/quake3-server:latest`, remove that line so the compose file's pin applies.
- **The page loads but the client cannot connect.** `QUAKE3_SERVER_IP_OR_HOSTNAME` must be the address players reach the server at (public IP or DNS name), not `0.0.0.0` and not the Docker-internal address; the web client is told to connect there.
- **Players outside your network cannot join.** Open 80/tcp (web client) and 27960/tcp (game traffic over WebSocket) in the firewall.

## Supply chain trust

Most repositories in this fleet pin an upstream image. This one ships its own: the image is built from the `Dockerfile` here by the [Publish Docker Image](https://github.com/heyvaldemar/quake3-server-docker-compose/actions/workflows/00-publish-docker-image.yml) workflow, pushed to Docker Hub tagged `latest` and with the commit it was built from, and pinned as `<commit-tag>@sha256:<digest>` in the compose `x-images` block. The publish workflow commits the new pin after every build, so `git pull` alone delivers the exact image CI built and booted. Earlier revisions deployed from a floating `latest`.

Two override levels exist per image. `<PREFIX>_IMAGE_VERSION` in `.env` swaps only the version of that image (Compose then pulls the tag, without a digest) and leaves every other pin as tested; `<PREFIX>_IMAGE_TAG` replaces the whole reference, digest included. The variable names are listed in `.env.example`. Nested defaults need Docker Compose v2.5 or newer (2022); v2.0 to v2.4 leave the inner `${...}` unexpanded and `docker compose up` fails with an invalid reference instead of deploying something unexpected.

Deployment Verification rebuilds the image from the checkout on every push and daily and scans the build with Trivy; the daily `check-pin-freshness` job, in its own Pin Freshness workflow, fails if the pin no longer matches the latest published build. GitHub Actions are pinned by commit SHA; Dependabot keeps those and the `ubuntu` base image fresh.

To run your own build instead, set `QUAKE3_SERVER_IMAGE_TAG` in `.env` (for example `docker build -t my/quake3-server .` and `QUAKE3_SERVER_IMAGE_TAG=my/quake3-server`).

### Verify what you deploy

Every release from v1.6.0 on carries three files made on GitHub's runner with a short-lived identity and no stored key: `quake3-server-docker-compose-<tag>.tar.gz`, a `git archive` of exactly the tree the tag points at; `quake3-server-docker-compose-<tag>.tar.gz.sigstore.json`, a keyless [Sigstore](https://www.sigstore.dev/) signature over it; and `quake3-server-docker-compose-<tag>.intoto.jsonl`, [SLSA](https://slsa.dev/) build provenance from the SLSA generator. To check them with nothing from this repository trusted:

```bash
cosign verify-blob quake3-server-docker-compose-<tag>.tar.gz \
  --bundle quake3-server-docker-compose-<tag>.tar.gz.sigstore.json \
  --certificate-identity-regexp '^https://github.com/heyvaldemar/quake3-server-docker-compose/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

slsa-verifier verify-artifact quake3-server-docker-compose-<tag>.tar.gz \
  --provenance-path quake3-server-docker-compose-<tag>.intoto.jsonl \
  --source-uri github.com/heyvaldemar/quake3-server-docker-compose
```

Add `--source-tag <tag>` for a release published after 24 September 2026, which is signed by the run that published it. The five releases before that date were signed by a run started by hand on `main`, so their provenance names the branch, not the tag; the archive is still the tag's tree, and the signature still belongs to this repository's workflow. The workflow that makes them is [`release-assets.yml`](.github/workflows/release-assets.yml).

## Production checklist

- [ ] **Generate `RCON_PASSWORD`** with `openssl rand -base64 24 | tr -d '/+=' | head -c 32`. Anyone with it can kick players, change maps and shut the server down.
- [ ] **Set `QUAKE3_SERVER_IP_OR_HOSTNAME`** to the public address; put a DNS name in front if players should not learn the IP.
- [ ] **Open 80/tcp and 27960/tcp** in the firewall; nothing else needs to be public. Put a TLS-terminating proxy in front of port 80 if the page should be served over HTTPS.
- [ ] **Keep `server.cfg` in your own git repository**: it is the whole server state worth keeping.
- [ ] **Rotate the RCON password** if you deployed before 2026-04-23: the pre-rotation value that was hardcoded in `server.cfg` remains in git history and is compromised. See [SECURITY.md](SECURITY.md).
- [ ] **Upgrade if you run v1.3.0 to v1.6.0.** In those releases `server.cfg` carried a literal RCON password where the placeholder belonged, so `RCON_PASSWORD` from `.env` was ignored. No packet a client sent reached those servers (see the 1.6.2 changelog), so nothing answered rcon on them; but a `server.cfg` kept from them would give that password rcon on a release that works, and from v1.6.3 the server refuses to start on it. Update the repository together with the image. See [SECURITY.md](SECURITY.md).

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

The [Deployment Verification](https://github.com/heyvaldemar/quake3-server-docker-compose/actions/workflows/deployment-verification.yml?query=branch%3Amain) workflow runs on every push, pull request, and every day at 06:00 UTC: ShellCheck, hadolint and actionlint; a build of the image from the checkout; a Trivy scan of that build; a deploy job that boots the stack with an ephemeral RCON password and requires the web client to answer 200, the game port to listen, and the game to answer `getstatus` through its WebSocket, also on the scoreboard after a fraglimit of 1, with the log silent for 90 seconds; a plant that runs the new health check against the image v1.6.1 shipped, which it must call unhealthy while the old check calls it healthy; and, on the daily run, the pin freshness check against Docker Hub.


`tests/secret-probe.sh` gives `RCON_PASSWORD` a value of its own and looks for it in `docker compose logs`, on every command line in the container and in the host's `ps`, after the first start, while an rcon client runs and after a restart, naming the place, never the value; it finds nothing. `tests/clean-stop.sh` times a `docker compose stop` and fails if Docker had to send SIGKILL. Up to v1.6.4 node was process 1 and did not act on SIGTERM, so every stop waited Docker's ten seconds and was killed; Docker's init is process 1 now and hands SIGTERM on. A Quake III server keeps no world, so nothing was lost, only the wait.

---

## About the maintainer

<div align="center">

**Maintained by [Vladimir Mikhalev](https://github.com/heyvaldemar)** · Docker Captain · CNCF Ambassador · IBM Champion · AWS Community Builder

[YouTube](https://www.youtube.com/channel/UCf85kQ0u1sYTTTyKVpxrlyQ?sub_confirmation=1) · [Blog](https://heyvaldemar.com) · [LinkedIn](https://www.linkedin.com/in/heyvaldemar/)

</div>
