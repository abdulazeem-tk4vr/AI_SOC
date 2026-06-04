# Wazuh agent 4.8.x — matches ai-soc wazuh-manager image (official wazuh-agent image is 4.13+ only)
ARG WAZUH_VERSION=4.8.2
FROM ubuntu:22.04

ARG WAZUH_VERSION
ENV DEBIAN_FRONTEND=noninteractive \
    WAZUH_VERSION=${WAZUH_VERSION}

# ca-certificates must be installed before curl can fetch HTTPS GPG key (otherwise gpg: no valid OpenPGP data)
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gnupg apt-transport-https \
    && curl -fSL https://packages.wazuh.com/key/GPG-KEY-WAZUH -o /tmp/wazuh-gpg.key \
    && gpg --dearmor -o /usr/share/keyrings/wazuh.gpg /tmp/wazuh-gpg.key \
    && chmod 644 /usr/share/keyrings/wazuh.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
        > /etc/apt/sources.list.d/wazuh.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends "wazuh-agent=${WAZUH_VERSION}-1" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/wazuh-gpg.key

COPY ossec.conf /wazuh-config-mount/etc/ossec.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/var/ossec/etc", "/var/log"]

ENTRYPOINT ["/entrypoint.sh"]
