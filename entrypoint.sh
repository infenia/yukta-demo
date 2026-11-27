#!/usr/bin/env bash
# Start Yukta on loopback, seed the examples with the ADMIN key, then put nginx in front with the
# OPERATOR key. Everything is in memory: every restart (Render free plan sleeps) is a fresh demo.
set -euo pipefail

# Fresh keys per start unless given; neither ever leaves the container.
export ADMIN_KEY="${ADMIN_KEY:-$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')}"
export OPERATOR_KEY="${OPERATOR_KEY:-$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')}"

export YUKTA_API_KEYS_0_NAME=seed YUKTA_API_KEYS_0_KEY="$ADMIN_KEY" YUKTA_API_KEYS_0_ROLE=ADMIN
export YUKTA_API_KEYS_1_NAME=demo YUKTA_API_KEYS_1_KEY="$OPERATOR_KEY" YUKTA_API_KEYS_1_ROLE=OPERATOR
# Only what the standalone examples use. No HTTP_REQUEST / FILE_READ: this is on the open internet.
export YUKTA_PLUGINS_ENABLED="${YUKTA_PLUGINS_ENABLED:-PROCESS_EXECUTOR,FILE_WRITE,NOTIFY_TERMINAL}"
export YUKTA_PROCESS_ALLOWED_COMMANDS="${YUKTA_PROCESS_ALLOWED_COMMANDS:-sh,echo,shuf}"

# Every visitor shares the one OPERATOR key, so the per-key limit is off; nginx limits per client IP.
setpriv --reuid=nginx --regid=nginx --init-groups /app/yukta -Dyukta.rate-limit-per-minute=0 &

for _ in $(seq 120); do
  curl -fsS -o /dev/null http://127.0.0.1:9858/actuator/health && break
  sleep 1
done

# run.sh applies each session (and its supervisor) and leaves a few runs in the history.
# A failing example must not keep the demo down.
YUKTA_URL=http://127.0.0.1:9858 YUKTA_API_KEY="$ADMIN_KEY" /opt/examples/run-all.sh 1 || echo "seed: some examples failed" >&2

envsubst '${PORT} ${OPERATOR_KEY}' </etc/nginx/templates/yukta.conf.template >/etc/nginx/conf.d/yukta.conf
nginx -g 'daemon off;' &

# Either process dying ends the container, so Render restarts it instead of serving 502s.
wait -n
exit 1
