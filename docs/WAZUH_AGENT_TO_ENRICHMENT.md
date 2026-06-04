# Wazuh Agent → Enriched Alerts (End-to-End Lab)

Step-by-step guide to run the full AI-SOC path in Docker:

**Wazuh agent log inject → manager rule → custom integration → `wazuh-integration` webhook → LLM triage → `data/enriched-alerts/`**

This matches the configuration shipped in this repository (`custom-ai-soc-webhook` + lab agents). For integration internals and troubleshooting, see [WAZUH_INTEGRATION_GUIDE.md](WAZUH_INTEGRATION_GUIDE.md).

---

## What you will see when it works

| Stage | Where to look | Success signal |
|--------|----------------|----------------|
| Agent ingests log | Agent container | Line appended to `/var/log/injection-test.log` |
| Manager fires rule | Wazuh Dashboard → Discover | Alert on `wazuh-alerts-*` (e.g. rule **5710**, level **5**) |
| Integrator POSTs webhook | Manager `integrations.log` | `custom-ai-soc-webhook OK HTTP=200` |
| AI enrichment | Host `data/enriched-alerts/` | New `enriched-<alert_id>-<timestamp>.json` |
| Service trace | `docker logs wazuh-integration` | `webhook_alert_received` → `enriched_alert_persisted` |

---

## Architecture (lab stack)

```text
wazuh-agent-web / wazuh-agent-app
        │  (sshd-style syslog → /var/log/injection-test.log)
        ▼
   wazuh-manager  (analysisd + rules, e.g. 5710 level 5)
        │  wazuh-integratord
        │  /var/ossec/integrations/custom-ai-soc-webhook
        │       └─► custom-ai-soc-webhook.py (Wazuh framework Python)
        ▼
   wazuh-integration:8002/webhook  (Docker network: ai-soc-siem-backend)
        ├─► alert-triage (LLM)
        ├─► correlation-engine
        └─► data/enriched-alerts/*.json
```

**Repo files (already wired in compose):**

| File | Role |
|------|------|
| `config/wazuh-manager/ossec.conf` | `<integration>` block, level **5** for lab SSH injects |
| `config/wazuh-manager/integrations/custom-ai-soc-webhook` | Shell launcher (same pattern as `slack` / `shuffle`) |
| `config/wazuh-manager/integrations/custom-ai-soc-webhook.py` | POSTs alert JSON to the webhook |
| `docker-compose/phase1-siem-core-windows.yml` | Mounts integration + `ossec.conf` on `wazuh-manager` |
| `docker-compose/wazuh-agents.yml` | `wazuh-agent-web`, `wazuh-agent-app` |
| `docker-compose/ai-services.yml` | `wazuh-integration` on shared `siem-backend` network |

---

## Prerequisites

1. **Docker Desktop** running (Windows/macOS/Linux).
2. **`.env`** in `main/AI_SOC/` with at least:
   - `OLLAMA_BASE_URL` — reachable LLM endpoint (e.g. RunPod proxy).
   - `MIN_SEVERITY=5` — lab threshold (SSH rule 5710 is level 5).
   - `INDEXER_PASSWORD=admin` — matches default Wazuh dashboard login in this lab.
3. **Git Bash** (Windows) or bash (Linux/macOS) for inject scripts.
4. **Line endings:** integration scripts must be LF. From repo root:
   ```bash
   sed -i 's/\r$//' config/wazuh-manager/integrations/custom-ai-soc-webhook \
     config/wazuh-manager/integrations/custom-ai-soc-webhook.py
   ```
   (`.gitattributes` in that folder enforces LF on checkout.)

---

## Step 1 — Deploy the stack

### Windows (PowerShell)

From `main/AI_SOC`:

```powershell
.\deploy-ai-soc.ps1
```

This brings up SIEM (including agents when the deploy script includes them), AI services, and monitoring.

### Linux / macOS or manual compose

```bash
cd main/AI_SOC

# SIEM + dashboard + manager + agents
docker compose -p ai-soc-siem \
  -f docker-compose/phase1-siem-core-windows.yml \
  -f docker-compose/wazuh-agents.yml \
  up -d --build

# AI pipeline (webhook consumer)
docker compose -p ai-soc-ai -f docker-compose/ai-services.yml up -d
```

Wait until core containers are healthy:

```bash
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "wazuh|integration|triage"
```

Expected names: `wazuh-indexer`, `wazuh-manager`, `wazuh-dashboard`, `wazuh-agent-web`, `wazuh-agent-app`, `wazuh-integration`, `alert-triage`, `rag-service`.

---

## Step 2 — Verify the custom integration

Integration is **not** edited inside the running container for normal use; it is mounted from the repo. After any config change, recreate the manager:

```bash
docker compose -p ai-soc-siem \
  -f docker-compose/phase1-siem-core-windows.yml \
  up -d wazuh-manager --force-recreate
```

Wait ~60s, then check:

```bash
# Integrator enabled (no "File not found" / "Not currently supported")
docker exec wazuh-manager grep integratord /var/ossec/logs/ossec.log | tail -5

# Both launcher and Python script present
docker exec wazuh-manager ls -la /var/ossec/integrations/custom-ai-soc-webhook*

# Config block
docker exec wazuh-manager grep -A5 "AI-SOC" /var/ossec/etc/ossec.conf
```

You want a line like:

```text
Enabling integration for: 'custom-ai-soc-webhook'.
```

**Smoke-test the script** (uses Wazuh framework Python with `requests`):

```bash
docker exec wazuh-manager bash -c '
  echo "{\"rule\":{\"level\":5},\"id\":\"doc-test\",\"timestamp\":\"2026-06-04T00:00:00Z\"}" > /tmp/t.json
  /var/ossec/integrations/custom-ai-soc-webhook /tmp/t.json "" "http://wazuh-integration:8002/webhook"
  tail -1 /var/ossec/logs/integrations.log
'
```

Expect: `custom-ai-soc-webhook OK HTTP=200`.

---

## Step 3 — Confirm agents are connected

**Dashboard:** `https://localhost:443` — login **`admin` / `admin`** (lab default).

**Endpoints:** Agents Summary should show **web-server-01** and **app-server-02** as active.

**CLI:**

```bash
docker exec wazuh-manager /var/ossec/bin/agent_control -l
```

---

## Step 4 — Inject a test log (agent → manager)

Default agent: `wazuh-agent-web` (`web-server-01`).

```bash
cd main/AI_SOC

bash ./scripts/wazuh-agent-inject.sh \
  "Failed password for invalid user root from 203.0.113.201 port 22 ssh2"
```

Repeat 2–3 times if you want multiple enriched files. The agent appends syslog lines to `/var/log/injection-test.log` (configured in `config/wazuh-agent/ossec.conf`).

**Optional — full demo script** (inject + wait + show alerts/logs):

```bash
INJECT_TARGET=agent bash ./scripts/wazuh-injection-demo.sh
```

**Optional — inject on manager only** (bypasses agents):

```bash
INJECT_TARGET=manager bash ./scripts/wazuh-injection-demo.sh
```

---

## Step 5 — Wait and verify enrichment

Allow **20–40 seconds** for analysis, integrator, and LLM triage.

### 5a — Integrator log (manager)

```bash
docker exec wazuh-manager tail -10 /var/ossec/logs/integrations.log
```

Success:

```text
2026-06-04T17:35:27.589133+00:00 custom-ai-soc-webhook OK HTTP=200
```

### 5b — Enriched JSON (host)

```bash
ls -lt main/AI_SOC/data/enriched-alerts/*.json | head -5
```

Files are named: `enriched-<alert_id>-<UTC timestamp>.json`.

### 5c — Integration service logs

```bash
docker logs wazuh-integration --since 5m 2>&1 | tail -30
```

Look for: `webhook_alert_received`, `alert_triage_analysis_complete`, `enriched_alert_persisted`.

### 5d — Raw alerts in Wazuh (optional)

```bash
docker exec wazuh-manager tail -20 /var/ossec/logs/alerts/alerts.json \
  | grep -E "5710|203.0.113.201" || true
```

**Discover:** index pattern `wazuh-alerts-*` should show the same SSH events (independent of enrichment).

---

## Step 6 — Understand outputs

Each enriched file is the webhook response from `wazuh-integration` (triage + correlation metadata). Example fields:

- `alert_id`, `rule_level`, `rule_description`
- `ai_analysis` — severity, summary, `is_true_positive`, IOCs
- `incident_id` — from correlation-engine when applicable

See [data/enriched-alerts/README.md](../data/enriched-alerts/README.md) for the filename convention.

---

## Configuration reference (lab vs production)

| Setting | Lab (this guide) | Production suggestion |
|---------|------------------|------------------------|
| `ossec.conf` `<level>` | `5` | `7` or higher |
| `.env` `MIN_SEVERITY` | `5` | `7` |
| `custom-ai-soc-webhook.py` `AI_SOC_WEBHOOK_MIN_LEVEL` | default `5` | `7` |
| Integration name | `custom-ai-soc-webhook` | unchanged |

Raise all three together so manager, integrator script, and `wazuh-integration` stay aligned.

---

## Troubleshooting

### No lines in `integrations.log` after inject

1. Confirm integrator enabled: `grep integratord /var/ossec/logs/ossec.log` — must **not** show `Invalid integration` or `File not found`.
2. Integration **name** in `ossec.conf` must be `custom-ai-soc-webhook` (no `.py`), with files:
   - `/var/ossec/integrations/custom-ai-soc-webhook`
   - `/var/ossec/integrations/custom-ai-soc-webhook.py`
3. Alert level must be ≥ integration `<level>` and script `MIN_LEVEL` (lab: **5** for rule 5710).
4. Recreate manager after changing mounted files.

### `No module 'requests' found`

The integrator must use **Wazuh framework Python**, not system `python3`. Ensure the **shell launcher** exists and `ossec.conf` names `custom-ai-soc-webhook`, not only the `.py` file.

### `cannot execute: required file not found` (Windows)

CRLF on integration scripts. Run the `sed` command in Prerequisites and recreate `wazuh-manager`.

### Discover empty but manager has alerts

Often `INDEXER_PASSWORD` mismatch. Lab dashboard uses **`admin`/`admin`**; set `INDEXER_PASSWORD=admin` in `.env` and recreate `wazuh-manager`.

### `wazuh-integration` health check 401 to Wazuh API

`API_PASSWORD` in `.env` may not match the Wazuh API user. This affects **API health checks**, not the webhook POST path if integrator logs show `HTTP=200`.

### `wazuh-integration` not reachable from manager

Both stacks must share `siem-backend` (`SIEM_BACKEND_NETWORK=ai-soc-siem-backend`). Test:

```bash
docker exec wazuh-manager curl -sf http://wazuh-integration:8002/health
```

---

## Quick command checklist

```bash
# 1. Deploy (see Step 1)
# 2. Recreate manager after integration changes
docker compose -p ai-soc-siem -f docker-compose/phase1-siem-core-windows.yml up -d wazuh-manager --force-recreate

# 3. Inject
bash ./scripts/wazuh-agent-inject.sh "Failed password for invalid user root from 203.0.113.201 port 22 ssh2"

# 4. Verify
sleep 35
docker exec wazuh-manager tail -5 /var/ossec/logs/integrations.log
ls -lt data/enriched-alerts/
docker logs wazuh-integration --since 3m 2>&1 | tail -20
```

---

## Related documentation

- [WAZUH_INTEGRATION_GUIDE.md](WAZUH_INTEGRATION_GUIDE.md) — integration options, network, API details
- [PIPELINE_FLOW.md](../PIPELINE_FLOW.md) — full pipeline step numbers
- [deployment/docker.md](deployment/docker.md) — compose stacks and networks
- [deployment/runpod-ollama.md](deployment/runpod-ollama.md) — external LLM URL for `.env`
