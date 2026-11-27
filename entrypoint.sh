#!/usr/bin/env bash
# Start Yukta on loopback, seed the examples with the ADMIN key, then put nginx in front with the
# OPERATOR key. Everything is in memory: every restart (Render free plan sleeps) is a fresh demo.
set -euo pipefail

# Fresh keys per start unless given; neither ever leaves the container.
export ADMIN_KEY="${ADMIN_KEY:-$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')}"
export OPERATOR_KEY="${OPERATOR_KEY:-$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')}"

export YUKTA_API_KEYS_0_NAME=seed YUKTA_API_KEYS_0_KEY="$ADMIN_KEY" YUKTA_API_KEYS_0_ROLE=ADMIN YUKTA_API_KEYS_0_SESSIONS_0='*'
export YUKTA_API_KEYS_1_NAME=demo YUKTA_API_KEYS_1_KEY="$OPERATOR_KEY" YUKTA_API_KEYS_1_ROLE=OPERATOR YUKTA_API_KEYS_1_SESSIONS_0='*'
# Only what the standalone examples use. No HTTP_REQUEST / FILE_READ: this is on the open internet.
export YUKTA_PLUGINS_ENABLED="${YUKTA_PLUGINS_ENABLED:-PROCESS_EXECUTOR,FILE_WRITE,NOTIFY_TERMINAL}"
export YUKTA_PROCESS_ALLOWED_COMMANDS="${YUKTA_PROCESS_ALLOWED_COMMANDS:-sh,echo,shuf}"

# Every visitor shares the one OPERATOR key, so the per-key limit is off; nginx limits per client IP.
setpriv --reuid=nginx --regid=nginx --init-groups /app/yukta -Dyukta.rate-limit-per-minute=0 &
yukta_pid=$!

for _ in $(seq 120); do
  curl -fs -o /dev/null http://127.0.0.1:9858/actuator/health && break
  kill -0 "$yukta_pid" 2>/dev/null || exit 1
  sleep 1
done

# run.sh applies each session (and its supervisor) and leaves a few runs in the history.
# As the server user, so the files it writes under /tmp stay writable. A failing example must not
# keep the demo down.
YUKTA_URL=http://127.0.0.1:9858 YUKTA_API_KEY="$ADMIN_KEY" setpriv --reuid=nginx --regid=nginx --init-groups /opt/examples/run-all.sh 1 || echo "seed: some examples failed" >&2
# 09 is a walkthrough without run.sh: apply its (internal) session, then the supervisor that runs it.
(cd /opt/examples/1-standalone/09-supervisor-workflow && source ../../lib/common.sh \
  && YUKTA_URL=http://127.0.0.1:9858 YUKTA_API_KEY="$ADMIN_KEY" \
  && apply_session session.json && apply_supervisor supervisor.json) || echo "seed: example 09 failed" >&2

envsubst '${PORT} ${OPERATOR_KEY}' </etc/nginx/templates/yukta.conf.template >/etc/nginx/conf.d/yukta.conf
nginx -g 'daemon off;' &

# Either process dying ends the container, so Render restarts it instead of serving 502s.
wait -n
exit 1
