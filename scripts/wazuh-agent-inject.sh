#!/usr/bin/env bash
# Append one syslog line on a Wazuh agent container (dynamic log injection).
set -euo pipefail

AGENT="${WAZUH_AGENT_CONTAINER:-wazuh-agent-web}"
LOG_FILE="${WAZUH_AGENT_LOG_FILE:-/var/log/injection-test.log}"
SRCIP="${WAZUH_INJECT_SRCIP:-203.0.113.42}"
USER="${WAZUH_INJECT_USER:-root}"
MSG="${1:-Failed password for invalid user ${USER} from ${SRCIP} port 22 ssh2}"

docker exec "$AGENT" bash -c "
  TS=\$(date '+%b %e %H:%M:%S')
  HOST=\$(hostname 2>/dev/null || echo wazuh-agent)
  echo \"\${TS} \${HOST} sshd[\$\$]: ${MSG}\" >> \"${LOG_FILE}\"
  echo \"Appended to ${LOG_FILE} on ${AGENT}:\"
  tail -1 \"${LOG_FILE}\"
"
