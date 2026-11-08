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
umask 077
for cfg in /quakejs/base/baseq3/server.cfg /quakejs/base/cpma/server.cfg; do
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
