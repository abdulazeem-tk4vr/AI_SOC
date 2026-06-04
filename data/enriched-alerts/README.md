# Enriched alerts (E2E)

`wazuh-integration` writes one JSON per webhook after triage/RAG/correlate:

`enriched-<alert_id>-<timestamp>.json`

**How to generate these files (agent inject → webhook → LLM):**  
[docs/WAZUH_AGENT_TO_ENRICHMENT.md](../../docs/WAZUH_AGENT_TO_ENRICHMENT.md)
