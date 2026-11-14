#!/bin/bash
# secret-probe.sh - no secret this template passes reaches a log or a command line.
#
#   tests/secret-probe.sh plant           before the first start: a random value
#                                         for every secret-named variable
#   tests/secret-probe.sh check <label>   with the stack running: look for every
#                                         planted value, exit 1 on any
#   tests/secret-probe.sh selftest        prove check sees a value planted in a
#                                         log and on a command line
#   tests/secret-probe.sh during <label> <command...>
#                                         run a helper (an rcon client, a
#                                         backup) and watch the host's ps and
#                                         every container's command lines the
#                                         whole time: a value handed to a
#                                         helper as an argument lives only
#                                         while it runs
#
# WHAT COUNTS AS A SECRET. Every variable the compose file interpolates whose
# name has PASS, PWD, SECRET, TOKEN, KEY or CRED in it. plant gives each one a
# value of its own, random, and writes it into .env and into a values file
# (mode 600) that only this script reads.
#
# WHERE IT LOOKS, the places a value leaks to in practice:
#   - `docker compose logs --no-color` of every service, since it started
#     (what a user pastes into an issue);
#   - the game's own log files that the template knows (PROBE_GAME_LOGS),
#     which users paste too;
#   - the command line of every process in every container of the project,
#     read as root from /proc/*/cmdline (what `ps` shows on the host, and
#     what any process in the container can read);
#   - `ps` on the host running the stack.
# A match prints the variable's name and the place, never the value.
#
# VALUES NEVER ON A COMMAND LINE HERE EITHER. Each value is written to a file
# and searched with grep -F -f, and .env is edited by awk through its
# environment, so the probe itself cannot be the leak it reports.
#
# Settings (environment):
#   PROBE_PROJECT  the compose project            (required)
#   PROBE_COMPOSE  the compose file               (default: the one *-docker-compose.yml)
#   PROBE_ENV      the env file compose reads     (default: .env)
#   PROBE_VALUES   the values file                (default: $RUNNER_TEMP or /tmp, secret-probe.values)
#   PROBE_EXPECT   names that must be among the secret-named variables found;
#                  a refactor that hides one from the probe fails instead
#   PROBE_KEEP     names whose value in the env file is kept, not replaced:
#                  a real token from a repository secret, which the game must
#                  log on with. Kept values are probed like the others.
#   PROBE_GAME_LOGS  the game's own log files, as service:glob, separated by
#                  spaces (for example vein-server:/home/steam/vein/Vein/Saved/Logs/*.log)
#   PROBE_ARGV_OK  names the README says are visible on the game's command
#                  line, because the game reads them nowhere else (measured,
#                  optional, empty by default). On a command line in a
#                  container or in host ps their value is reported as
#                  documented, not as a failure.
#   PROBE_GAMELOG_OK  names the README says are in the game's own log, because
#                  the engine writes its command line there. In the game logs
#                  their value is reported as documented.
#   No exception covers `docker compose logs`. Every name in either list must
#   appear in README.md, or the probe is red.
#   PROBE_SELFTEST_SERVICE  the service whose process 1 the selftest writes its
#                  canary to (default: the first one listed). The selftest
#                  writes the canary to the standard output of process 1 of
#                  any container of the project that can be written to; which
#                  one, the workflow names. A process 1 that dropped root for
#                  another user is not dumpable, and nobody can open its
#                  /proc/1/fd/1.
#
# WHAT A LEAK PRINTS. The lines that hold a value, with every planted value
# replaced by its name, and whatever else in them points at a person or a
# machine replaced as well: a Steam ID in any of its forms (76561...,
# STEAM_x:y:z, [U:1:n] and its kin) by <id>, an IPv4 or IPv6 address by <ip>,
# before the line is cut short. A Real
# Server with a game server token is listed by Steam, and a stranger can join
# while CI runs; their id and address are not this log's to keep. The
# selftest proves it on a line that holds all of them.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
umask 077

mode="${1:-}"
PROJECT="${PROBE_PROJECT:?set PROBE_PROJECT to the compose project}"
COMPOSE="${PROBE_COMPOSE:-}"
if [ -z "$COMPOSE" ]; then for f in ./*-docker-compose.yml; do COMPOSE="$f"; break; done; fi
ENVF="${PROBE_ENV:-.env}"
VALUES="${PROBE_VALUES:-${RUNNER_TEMP:-/tmp}/secret-probe.values}"
KEEP=" ${PROBE_KEEP:-} "
ARGV_OK=" ${PROBE_ARGV_OK:-} "
GAMELOG_OK=" ${PROBE_GAMELOG_OK:-} "
[ -f "$COMPOSE" ] || { echo "secret-probe: no compose file ($COMPOSE)" >&2; exit 2; }

# Every variable the compose file interpolates, from Compose itself where it
# can say (config --variables) and from the text, ${NAME} and $NAME, either
# way; the secret-named ones.
names() {
  {
    docker compose -f "$COMPOSE" config --variables 2>/dev/null | awk 'NR > 1 { print $1 }'
    grep -oE '\$\{[A-Za-z_][A-Za-z0-9_]*|(^|[^$])\$[A-Za-z_][A-Za-z0-9_]*' "$COMPOSE" | sed -E 's/^[^$]*\$\{?//'
  } | grep -E '^[A-Za-z_][A-Za-z0-9_]*$' | sort -u | grep -E 'PASS|PWD|SECRET|TOKEN|KEY|CRED'
}

# set_env NAME (value in $V): every line for NAME, commented or not, replaced by one.
set_env() {
  touch "$ENVF"
  N="$1" V="$V" awk 'BEGIN { n = ENVIRON["N"] } $0 !~ "^#? *" n "=" { print } END { print n "=" ENVIRON["V"] }' "$ENVF" >"$ENVF.probe" \
    && cat "$ENVF.probe" >"$ENVF" && rm -f "$ENVF.probe"
}
get_env() {  # NAME -> the value in the env file, last one wins
  N="$1" awk 'BEGIN { n = ENVIRON["N"] } index($0, n "=") == 1 { v = substr($0, length(n) + 2) } END { print v }' "$ENVF"
}

# redact: Steam IDs and addresses out of a line that is about to be printed.
redact() {
  sed -E \
    -e 's/76561[0-9]{12}/<id>/g' \
    -e 's/STEAM_[0-5]:[01]:[0-9]+/<id>/g' \
    -e 's/\[[AUIMGPCgTLca]:[0-5]:[0-9]+(:[0-9]+)?\]/<id>/g' \
    -e 's/([0-9]{1,3}\.){3}[0-9]{1,3}/<ip>/g' \
    -e 's/([0-9A-Fa-f]{1,4}:){7}[0-9A-Fa-f]{1,4}/<ip>/g' \
    -e 's/([0-9A-Fa-f]{1,4}:)+:([0-9A-Fa-f]{1,4}(:[0-9A-Fa-f]{1,4})*)?/<ip>/g' \
    -e 's/::([0-9A-Fa-f]{1,4}(:[0-9A-Fa-f]{1,4})*)?/<ip>/g'
}
# excerpt VALUES-FILE SOURCE: lines on stdin, every value in the file replaced
# by its name, then redacted, then cut to 320 characters (in that order, so a
# cut never leaves half an address behind), each prefixed with its place.
excerpt() {
  awk -v vf="$1" '
    BEGIN { while ((getline l < vf) > 0) { t = index(l, "\t"); name[++k] = substr(l, 1, t - 1); val[k] = substr(l, t + 1) } }
    { for (i = 1; i <= k; i++) { while ((p = index($0, val[i])) > 0) $0 = substr($0, 1, p - 1) "<" name[i] ">" substr($0, p + length(val[i])) } print "  in " src ": " $0 }' src="$2" | redact | cut -c1-320
}

# found VALUE-FILE: the places this value appears; nothing when none.
found() {
  local f="$1" where=""
  grep -F -q -f "$f" "$WORK/logs" && where+=" compose-logs"
  grep -F -q -f "$f" "$WORK/cmdlines" && where+=" container-cmdline"
  grep -F -q -f "$f" "$WORK/hostps" && where+=" host-ps"
  grep -F -q -f "$f" "$WORK/gamelogs" && where+=" game-logs"
  printf '%s' "$where"
}

collect() {  # every place, into $WORK; fails closed: a place it cannot read is a failure
  docker compose -p "$PROJECT" -f "$COMPOSE" logs --no-color >"$WORK/logs" 2>&1 \
    || { echo "secret-probe: cannot read docker compose logs" >&2; return 1; }
  : >"$WORK/cmdlines"
  local cid unread=""
  for cid in $(docker compose -p "$PROJECT" -f "$COMPOSE" ps -q 2>/dev/null); do
    docker exec -u 0 "$cid" sh -c 'for p in /proc/[0-9]*; do [ -r "$p/cmdline" ] && tr "\0" " " <"$p/cmdline" && echo; done' \
      >>"$WORK/cmdlines" 2>/dev/null || unread+=" $(docker inspect -f '{{.Name}}' "$cid")"
  done
  ps -eo args >"$WORK/hostps" || { echo "secret-probe: cannot read the host's ps" >&2; return 1; }
  : >"$WORK/gamelogs"
  local spec svc glob gcid
  for spec in ${PROBE_GAME_LOGS:-}; do
    svc="${spec%%:*}"; glob="${spec#*:}"
    gcid="$(docker compose -p "$PROJECT" -f "$COMPOSE" ps -q "$svc" 2>/dev/null)"
    [ -n "$gcid" ] || { unread+=" $svc (game logs)"; continue; }
    # Fails, like any place it cannot read, when the glob matches no file.
    docker exec -u 0 "$gcid" sh -c 'n=0; for f in '"$glob"'; do [ -f "$f" ] || continue; n=1; cat "$f"; done; [ "$n" = 1 ]' >>"$WORK/gamelogs" 2>/dev/null \
      || unread+=" $svc (game logs: $glob)"
  done
  if [ -n "$unread" ]; then
    echo "secret-probe: cannot read the processes in:$unread" >&2
    return 1
  fi
  local f
  local places="logs cmdlines hostps"
  [ -n "${PROBE_GAME_LOGS:-}" ] && places+=" gamelogs"
  for f in $places; do
    [ -s "$WORK/$f" ] || { echo "secret-probe: nothing read from $f; a place with nothing in it proves nothing" >&2; return 1; }
  done
}

case "$mode" in
  plant)
    [ -L "$VALUES" ] && { echo "secret-probe: $VALUES is a symbolic link; refusing" >&2; exit 2; }
    rm -f "$VALUES" && : >"$VALUES" || exit 2
    found_names=" $(names | tr '\n' ' ') "
    for n in ${PROBE_EXPECT:-}; do
      [[ $found_names == *" $n "* ]] || { echo "secret-probe: $n is expected among the secret-named variables, and the compose file does not pass it" >&2; exit 2; }
    done
    planted=""; kept=""
    for n in $(names); do
      if [[ $KEEP == *" $n "* ]]; then
        V="$(get_env "$n")"
        [ -n "$V" ] || { echo "secret-probe: $n is to be kept, but $ENVF has no value for it" >&2; exit 2; }
        kept+=" $n"
      else
        V="p$(openssl rand -hex 10)"
        set_env "$n"
        # In GitHub Actions, the runner masks it in this job's log as well.
        [ "${GITHUB_ACTIONS:-}" = true ] && printf '::add-mask::%s\n' "$V"
        planted+=" $n"
      fi
      printf '%s\t%s\n' "$n" "$V" >>"$VALUES"
    done
    echo "secret-probe: planted${planted:- nothing}; kept${kept:- nothing}"
    ;;
  check)
    label="${2:-check}"
    [ -s "$VALUES" ] || { echo "secret-probe: no values file; run plant before the stack starts" >&2; exit 2; }
    WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
    collect || exit 1
    bad=0; n_all=0
    for n in $(echo "$ARGV_OK $GAMELOG_OK" | tr ' ' '\n' | sort -u); do
      grep -F -q "$n" README.md || { echo "::error::secret-probe ($label): $n is excepted as visible, but README.md does not name it"; bad=1; }
    done
    # shellcheck disable=SC2094  # the loop body only reads the values file
    while IFS=$'\t' read -r n v; do
      n_all=$((n_all + 1))
      printf '%s\n' "$v" >"$WORK/value"
      where="$(found "$WORK/value")"
      # What is left once every documented place is taken out is a leak.
      left="$where"
      [[ $ARGV_OK == *" $n "* ]] && { left="${left// container-cmdline/}"; left="${left// host-ps/}"; }
      [[ $GAMELOG_OK == *" $n "* ]] && left="${left// game-logs/}"
      if [ -n "$left" ]; then
        echo "::error::secret-probe ($label): the value of $n is in:$left"
        # The lines that hold it, every planted value in them replaced by its
        # name, so the line says what printed it and no value is shown.
        for src in logs gamelogs; do
          [[ $left == *" $([ "$src" = logs ] && echo compose-logs || echo game-logs)"* ]] || continue
          # shellcheck disable=SC2094  # excerpt only reads the values file
          grep -F -f "$WORK/value" "$WORK/$src" | head -3 | excerpt "$VALUES" "$src"
        done
        bad=1
      elif [ -n "$where" ]; then
        echo "secret-probe ($label): $n is only where the README says it is visible:$where"
      fi
    done <"$VALUES"
    [ "$bad" = 0 ] || exit 1
    if [ -n "${PROBE_GAME_LOGS:-}" ]; then gl="the game's logs ($(wc -l <"$WORK/gamelogs") lines)"; else gl="the game's logs (none configured: PROBE_GAME_LOGS is empty)"; fi
    echo "secret-probe ($label): $n_all values; none in docker compose logs ($(wc -l <"$WORK/logs") lines), and none outside what the README documents in $gl, the containers' command lines ($(wc -l <"$WORK/cmdlines") processes) or the host's ps"
    ;;
  during)
    label="${2:-during}"; shift 2 || { echo "usage: $0 during <label> <command...>" >&2; exit 2; }
    [ "$#" -gt 0 ] || { echo "usage: $0 during <label> <command...>" >&2; exit 2; }
    [ -s "$VALUES" ] || { echo "secret-probe: no values file; run plant before the stack starts" >&2; exit 2; }
    WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
    : >"$WORK/samples"
    cids="$(docker compose -p "$PROJECT" -f "$COMPOSE" ps -q 2>/dev/null)"
    # Sampling until the helper is done: the host's ps every tenth of a
    # second, each container's command lines as often as docker exec allows.
    (
      while [ ! -e "$WORK/done" ]; do
        ps -eo args >>"$WORK/samples"
        for c in $cids; do
          docker exec -u 0 "$c" sh -c 'for p in /proc/[0-9]*; do [ -r "$p/cmdline" ] && tr "\0" " " <"$p/cmdline" && echo; done' >>"$WORK/samples" 2>/dev/null &
        done
        sleep 0.1
      done
    ) &
    sampler=$!
    sleep 0.3
    rc=0; "$@" >"$WORK/out" 2>&1 || rc=$?
    sleep 0.3
    touch "$WORK/done"; wait "$sampler" 2>/dev/null; wait 2>/dev/null
    bad=0; n_all=0
    while IFS=$'\t' read -r n v; do
      n_all=$((n_all + 1))
      printf '%s\n' "$v" >"$WORK/value"
      if grep -F -q -f "$WORK/value" "$WORK/samples"; then
        echo "::error::secret-probe ($label): the value of $n was on a command line while the helper ran"
        bad=1
      fi
    done <"$VALUES"
    echo "secret-probe ($label): the helper exited $rc; $(wc -l <"$WORK/samples") process lines sampled while it ran; $([ "$bad" = 0 ] && echo "none of $n_all values among them")"
    [ "$bad" = 0 ] && [ "$rc" = 0 ]
    ;;
  selftest)
    # A canary, not a planted value: written to the log of a container of the
    # project (PROBE_SELFTEST_SERVICE, or the first one listed), held on the
    # command line of a process inside it (both from inside the container),
    # and on the command line of a process on the host. All three places
    # must find it. Then a line that leaked it, with Steam IDs and addresses
    # beside it, must print with none of them.
    WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
    svc=(); [ -n "${PROBE_SELFTEST_SERVICE:-}" ] && svc=("$PROBE_SELFTEST_SERVICE")
    cid="$(docker compose -p "$PROJECT" -f "$COMPOSE" ps -q "${svc[@]}" | head -1)"
    [ -n "$cid" ] || { echo "secret-probe: nothing is running" >&2; exit 2; }
    CANARY="c$(openssl rand -hex 10)"
    printf '%s\n' "$CANARY" >"$WORK/value"
    # As PID 1's own user: root in a container has no CAP_SYS_PTRACE, and
    # without it cannot open another user's /proc/1/fd/1.
    u1="$(docker exec "$cid" sh -c "awk '/^Uid:/ { print \$2 }' /proc/1/status")"
    # When process 1's own /proc/1/fd/1 cannot be opened (measured on a
    # process 1 started as uid 1000 with no capabilities: Permission denied
    # to uid 1000 itself), any process whose standard output or error is the
    # same pipe will do: the line reaches the same log.
    # shellcheck disable=SC2016  # expanded by the container's sh
    CANARY="$CANARY" docker exec -d -u "${u1:-0}" -e CANARY "$cid" sh -c 't=$(readlink /proc/1/fd/1)
      for f in /proc/1/fd/1 /proc/[0-9]*/fd/1 /proc/[0-9]*/fd/2; do
        [ "$(readlink "$f" 2>/dev/null)" = "$t" ] || continue
        { echo "secret-probe canary $CANARY" >"$f"; } 2>/dev/null && break
      done
      exec sh -c "sleep 20; :" canary "$CANARY"'
    bash -c 'sleep 20; :' canary "$(cat "$WORK/value")" &
    host=$!
    sleep 2
    collect || exit 1
    where="$(found "$WORK/value")"
    kill "$host" 2>/dev/null
    if [[ $where == *compose-logs* && $where == *container-cmdline* && $where == *host-ps* ]]; then
      echo "secret-probe selftest: a canary planted in all three places was found in:$where"
    else
      echo "::error::secret-probe selftest: the canary was found in:${where:- nowhere}; expected compose-logs, container-cmdline and host-ps"
      exit 1
    fi
    printf 'CANARY\t%s\n' "$(cat "$WORK/value")" >"$WORK/vf"
    # Steam IDs and addresses made here, out of the ranges real accounts and
    # hosts use (account 0, documentation networks), so this file names none.
    z12="$(printf '%012d' 0)"; z11="$(printf '%011d' 1)"
    out="$(printf 'joined: %s from %s and %s, %s, %s %s, at %s, %s and %s\n' "$(cat "$WORK/value")" "76561$z12" "765612$z11" \
      "STEAM_0:0:0" "[U:1:0]" "[U:1:0:1]" "203.0.113.7" "2001:db8:5::7" "::ffff:a00:1" | excerpt "$WORK/vf" selftest)"
    if grep -q -F -f "$WORK/value" <<<"$out" || grep -q -E '76561|STEAM_0|U:1:|203[.]0[.]113|2001:db8|ffff' <<<"$out" \
       || [[ $out != *"<CANARY>"* || $out != *"<id>"* || $out != *"<ip>"* ]]; then
      echo "::error::secret-probe selftest: a leaked line would print a value, a Steam ID or an address"
      exit 1
    fi
    echo "secret-probe selftest: a leaked line prints as:$out"
    ;;
  *)
    echo "usage: $0 plant | check <label> | selftest | during <label> <command...>" >&2
    exit 2
    ;;
esac
