#!/bin/sh
#
# Configure and start the QuakeJS server and client.
#
# - Substitutes the %RCON_PASSWORD% placeholder in every server.cfg that was
#   copied/mounted into the container with the value of $RCON_PASSWORD.
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

# Inject the RCON password into every server.cfg the image ships (baseq3,
# cpma). If the host volume-mounts its own server.cfg via docker-compose,
# that file is rewritten here too so compose users never have to edit the
# config.
for cfg in /quakejs/base/baseq3/server.cfg /quakejs/base/cpma/server.cfg; do
  if [ -f "$cfg" ]; then
    sed -i "s|%RCON_PASSWORD%|${RCON_PASSWORD}|g" "$cfg"
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
cd /quakejs
exec node build/ioq3ded.js +set fs_game baseq3 set dedicated 1 +exec server.cfg
