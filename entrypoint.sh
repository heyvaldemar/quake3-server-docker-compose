#!/bin/sh
#
# Configure and start the QuakeJS server and client.
#
# - Renders RCON_PASSWORD into the %RCON_PASSWORD% placeholder of each
#   server.cfg, inside the container: baseq3 from the template the compose
#   file mounts read-only (this repository's server.cfg), cpma from the copy
#   built into the image.
# - Points the QuakeJS web client at the current server's hostname.
# - Starts Apache (serves the web client on :80) and node ioq3ded
#   (the dedicated Quake 3 server on :27960) under the entrypoint PID.
set -eu

# Required secret: RCON password. Must be set via env; no sensible default.
: "${RCON_PASSWORD:?RCON_PASSWORD env var must be set; generate with: openssl rand -base64 24 | tr -d '/+=' | head -c 32}"

# Reject the .env.example placeholder value so a user who cp'd the example
# file but forgot to edit it fails fast rather than shipping a predictable
# password to every public Quake 3 client scanner on the internet.
case "${RCON_PASSWORD}" in
  change_me*)
    echo "ERROR: RCON_PASSWORD is still the .env.example placeholder value." >&2
    echo "       Generate a real one: openssl rand -base64 24 | tr -d '/+=' | head -c 32" >&2
    echo "       Then set it in .env (compose) or as a container env var." >&2
    exit 1
    ;;
esac

# Enforce a minimum length as a basic brute-force floor. 16 chars of the
# alphabet in .env.example's generator ≈ 95 bits of entropy.
if [ "${#RCON_PASSWORD}" -lt 16 ]; then
  echo "ERROR: RCON_PASSWORD must be at least 16 characters (current length: ${#RCON_PASSWORD})." >&2
  echo "       Generate a strong value: openssl rand -base64 24 | tr -d '/+=' | head -c 32" >&2
  exit 1
fi

# Render the RCON password into each server.cfg, inside the container.
#
# NEVER BACK INTO A MOUNTED FILE. This used to rewrite server.cfg in place, and
# the compose file mounted this repository's server.cfg there: every start
# wrote the password into the checkout's tracked file, and one was committed on
# 2026-09-03. The placeholder was gone from then on, RCON_PASSWORD was ignored,
# and every deployment ran with the password in git. baseq3 now renders from
# server.cfg.template (the repository's file, mounted read-only) when it is
# there, and cpma, like a container started without compose, from the copy
# built into the image, kept as .template on the first start.
#
# THE PASSWORD IS READ FROM THE ENVIRONMENT, NOT PASSED AS AN ARGUMENT.
# `sed "s|%RCON_PASSWORD%|<password>|g"` put it in sed's arguments, which every
# user on the host reads with ps. awk takes it from ENVIRON and splices it in
# by position, so nothing in the value (|, &, \) is read as syntax either.
#
# A COMPOSE FILE FROM BEFORE v1.6.1 MOUNTS server.cfg ITSELF. That file is
# then the mount point, the `rm` below fails with "Device or resource busy",
# and the container restarts forever. Say what it is instead: the image was
# updated without the repository.
umask 077
for cfg in /quakejs/base/baseq3/server.cfg /quakejs/base/cpma/server.cfg; do
  if awk -v p="$cfg" '$5 == p { found = 1 } END { exit !found }' /proc/self/mountinfo; then
    echo "ERROR: $cfg is mounted from the host, so this compose file is older than v1.6.1." >&2
    echo "       From v1.6.1 the compose file mounts server.cfg read-only as server.cfg.template." >&2
    echo "       Update the repository together with the image: ./update.sh (or git pull), then docker compose up -d." >&2
    exit 1
  fi
  [ -f "$cfg.template" ] || { [ -f "$cfg" ] && cp "$cfg" "$cfg.template"; } || continue
  if ! grep -q '%RCON_PASSWORD%' "$cfg.template"; then
    echo "WARNING: $cfg.template has no %RCON_PASSWORD% placeholder, so RCON_PASSWORD is NOT applied:" >&2
    echo "         rcon answers to whatever rconpassword that file sets. Put the placeholder back:" >&2
    echo "         seta rconpassword \"%RCON_PASSWORD%\"" >&2
  fi
  rm -f "$cfg"   # created anew, so the umask above makes it 600, not the image's 644
  awk '{ out = ""; s = $0
         while ((i = index(s, "%RCON_PASSWORD%")) > 0) { out = out substr(s, 1, i - 1) ENVIRON["RCON_PASSWORD"]; s = substr(s, i + 15) }
         print out s }' "$cfg.template" > "$cfg"
done
umask 022

# A PASSWORD THIS REPOSITORY PUBLISHED IS REFUSED, wherever it comes from.
# Two were: the one hardcoded in server.cfg until 2026-04-23, and the one
# committed on 2026-09-03 and released in v1.3.0 through v1.6.0. Both are in
# git history for anyone to read. A server.cfg kept from those releases, or an
# RCON_PASSWORD copied from one, would hand rcon to anyone; so every
# rconpassword the rendered configs set is hashed and compared, and a match
# stops the start. Only the SHA-256 of each value is here, and the value
# itself is never printed: read from the file by awk, hashed through a pipe.
PUBLISHED_RCON_SHA256="
e57002538a21164d17ff2bc9b3a312d21675ab6d26ea63554912b11ffd58a581
1ec1784f9a2d02d71a2c69c4fa7a074075c2efa7da0f0afac2420f68cfcd42f4
"
for cfg in /quakejs/base/baseq3/server.cfg /quakejs/base/cpma/server.cfg; do
  [ -f "$cfg" ] || continue
  # Every value an rconpassword command sets, as Quake 3 reads it: commands
  # split at ";", "//" starts a comment, a quoted value runs to its closing
  # quote and a bare one to the first blank; seta/set/sets/setu, any case.
  if ! awk '{
        sub(/\r$/, "")
        n = split($0, part, ";")
        for (k = 1; k <= n; k++) {
          s = part[k]; sub(/^[ \t]+/, "", s)
          if (substr(s, 1, 2) == "//") break
          low = tolower(s)
          if (low ~ /^set[asu]?[ \t]+rconpassword([ \t]|$)/) sub(/^[A-Za-z]+[ \t]+[A-Za-z]+[ \t]*/, "", s)
          else if (low ~ /^rconpassword([ \t]|$)/) sub(/^[A-Za-z]+[ \t]*/, "", s)
          else continue
          if (substr(s, 1, 1) == "\"") { s = substr(s, 2); i = index(s, "\""); if (i) s = substr(s, 1, i - 1) }
          else sub(/[ \t].*$/, "", s)
          print s
        }
      }' "$cfg" | while IFS= read -r v; do
        h=$(printf '%s' "$v" | sha256sum | cut -c1-64)
        case "$PUBLISHED_RCON_SHA256" in *"$h"*) exit 1 ;; esac
      done; then
    echo "ERROR: $cfg sets an rconpassword this repository once published, so anyone can use rcon on this server." >&2
    echo "       Refusing to start. Put the placeholder back in server.cfg:" >&2
    echo "         seta rconpassword \"%RCON_PASSWORD%\"" >&2
    echo "       and set RCON_PASSWORD in .env to a new value (openssl rand -base64 24 | tr -d '/+=' | head -c 32)." >&2
    echo "       See SECURITY.md." >&2
    exit 1
  fi
done

# Update the QuakeJS web client to use the current server's hostname so
# browser-based clients connect to the same machine that served the page.
cd /var/www/html
sed -i "s/'quakejs:/window.location.hostname + ':/g" index.html

# Start Apache (serves /var/www/html on :80). Backgrounded via init.d.
/etc/init.d/apache2 start

# Start the QuakeJS dedicated server. `exec` replaces the shell so node
# becomes PID 1 and receives SIGTERM/SIGINT directly.
# fs_cdn points at the Apache in this same container: the game assets are
# vendored into the image and served under /assets, because the public
# content.quakejs.com CDN is dead (http 301s to an https endpoint that
# answers 526). Also: `+set dedicated 1` — the old command line was
# missing the `+`, so the dedicated flag never reached the engine.
cd /quakejs
exec node build/ioq3ded.js +set fs_game baseq3 +set fs_cdn "127.0.0.1:80" +set dedicated 1 +exec server.cfg
