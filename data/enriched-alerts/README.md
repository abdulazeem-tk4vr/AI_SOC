# Enriched alerts (E2E)

`wazuh-integration` writes one JSON per webhook after triage/RAG/correlate:

`enriched-<wazuh_alert_id>-<timestamp>.json` (Wazuh-assigned id, e.g. `1780594515.57222`)

Injection demos tag logs with `INJECT_RUN_ID=inj-...` in `full_log` — grep Postgres `raw_alert_json` or manager `alerts.json` to map a run to those ids.

**How to generate these files (agent inject → webhook → LLM):**  
[docs/WAZUH_AGENT_TO_ENRICHMENT.md](../../docs/WAZUH_AGENT_TO_ENRICHMENT.md)
