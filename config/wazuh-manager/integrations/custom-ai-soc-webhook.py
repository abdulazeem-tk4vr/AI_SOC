#!/var/ossec/framework/python/bin/python3
# Wazuh custom integration: POST alert JSON to AI-SOC wazuh-integration webhook.
# Invoked by wazuh-integratord: custom-ai-soc-webhook.py <alert.json> <api_key> <hook_url> ...

import json
import os
import sys
from datetime import datetime, timezone

try:
    import requests
except ModuleNotFoundError:
    print("No module 'requests' found.")
    sys.exit(1)

PWD = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
LOG_FILE = os.path.join(PWD, "logs", "integrations.log")
DEFAULT_HOOK = "http://wazuh-integration:8002/webhook"
MIN_LEVEL = int(os.environ.get("AI_SOC_WEBHOOK_MIN_LEVEL", "5"))


def _log(message: str) -> None:
    with open(LOG_FILE, "a", encoding="utf-8") as handle:
        handle.write(f"{datetime.now(timezone.utc).isoformat()} {message}\n")


def main() -> None:
    if len(sys.argv) < 2:
        _log("custom-ai-soc-webhook ERROR missing alert file argument")
        sys.exit(2)

    alert_path = sys.argv[1]
    hook_url = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] else DEFAULT_HOOK

    if not os.path.isfile(alert_path):
        _log(f"custom-ai-soc-webhook ERROR alert file not found: {alert_path}")
        sys.exit(3)

    with open(alert_path, encoding="utf-8") as handle:
        alert = json.load(handle)

    rule_level = int(alert.get("rule", {}).get("level", 0))
    if rule_level < MIN_LEVEL:
        sys.exit(0)

    try:
        response = requests.post(hook_url, json=alert, timeout=600)
    except requests.RequestException as exc:
        _log(f"custom-ai-soc-webhook FAIL {hook_url} error={exc}")
        sys.exit(1)

    if response.status_code == 200:
        _log(f"custom-ai-soc-webhook OK HTTP={response.status_code}")
        sys.exit(0)

    _log(f"custom-ai-soc-webhook FAIL HTTP={response.status_code} body={response.text[:200]}")
    sys.exit(1)


if __name__ == "__main__":
    main()
