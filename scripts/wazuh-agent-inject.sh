#!/usr/bin/env bash
# Append one syslog line on a Wazuh agent container (dynamic log injection).
# Each run gets INJECT_RUN_ID in the log (and Wazuh full_log) for tracing → enriched-*.json / Postgres.
set -euo pipefail

AGENT="${WAZUH_AGENT_CONTAINER:-wazuh-agent-web}"
LOG_FILE="${WAZUH_AGENT_LOG_FILE:-/var/log/injection-test.log}"
SRCIP="${WAZUH_INJECT_SRCIP:-203.0.113.42}"
USER="${WAZUH_INJECT_USER:-root}"
MSG="${1:-Failed password for invalid user ${USER} from ${SRCIP} port 22 ssh2}"

# Unique per invocation unless parent demo exports one for the whole batch
if [ -z "${INJECT_RUN_ID:-}" ]; then
  INJECT_RUN_ID="inj-$(date -u +%Y%m%dT%H%M%SZ)-${RANDOM:-0}"
fi
export INJECT_RUN_ID
case "$MSG" in
  *INJECT_RUN_ID=*) ;;
  *) MSG="${MSG} | INJECT_RUN_ID=${INJECT_RUN_ID}" ;;
esac

docker exec "$AGENT" bash -c "
  TS=\$(date '+%b %e %H:%M:%S')
  HOST=\$(hostname 2>/dev/null || echo wazuh-agent)
  echo \"\${TS} \${HOST} sshd[\$\$]: ${MSG}\" >> \"${LOG_FILE}\"
  echo \"Appended to ${LOG_FILE} on ${AGENT} (INJECT_RUN_ID=${INJECT_RUN_ID}):\"
  tail -1 \"${LOG_FILE}\"
"
