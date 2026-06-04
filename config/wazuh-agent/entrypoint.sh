#!/bin/bash
set -euo pipefail

MANAGER="${WAZUH_MANAGER:-wazuh-manager}"
AGENT_NAME="${WAZUH_AGENT_NAME:-wazuh-agent-lab}"

install -d -m 0750 /var/ossec/etc /var/ossec/logs /var/log

if [[ -f /wazuh-config-mount/etc/ossec.conf ]]; then
  sed "s/WAZUH_MANAGER_PLACEHOLDER/${MANAGER}/g" \
    /wazuh-config-mount/etc/ossec.conf > /var/ossec/etc/ossec.conf
fi

touch /var/log/injection-test.log
chmod 644 /var/log/injection-test.log

if [[ ! -s /var/ossec/etc/client.keys ]]; then
  echo "Enrolling agent '${AGENT_NAME}' with manager '${MANAGER}'..."
  /var/ossec/bin/agent-auth -m "${MANAGER}" -A "${AGENT_NAME}" || true
fi

/var/ossec/bin/wazuh-control start

echo "Wazuh agent '${AGENT_NAME}' connected to ${MANAGER}"
exec tail -F /var/ossec/logs/ossec.log
