#!/usr/bin/env bash
# Provision Beyla dashboards into Grafana via the HTTP API.
# Idempotent — uses overwrite:true so re-runs update existing dashboards.
set -euo pipefail

NAMESPACE="${K8S_NAMESPACE:-circle-banking-app}"
REGION="${AWS_REGION:-us-east-1}"
SECRETS_ID="AwesomeCICD/circle-banking-app/secrets"
GRAFANA_LOCAL="http://localhost:3000"

DASHBOARD_IDS=(
  "19923"   # Beyla RED Metrics (19077 was removed from grafana.com)
)

PROMETHEUS_DS_UID="prometheus"

echo "==> Fetching Grafana admin password from Secrets Manager"
GRAFANA_PW=$(aws secretsmanager get-secret-value \
  --region "${REGION}" --secret-id "${SECRETS_ID}" \
  --query SecretString --output text | python3 -c \
  "import json,sys; print(json.load(sys.stdin).get('grafana_admin_password','admin'))")

echo "==> Starting kubectl port-forward to Grafana"
kubectl port-forward svc/kube-prometheus-grafana -n "${NAMESPACE}" 3000:80 &
PF_PID=$!
trap 'kill ${PF_PID} 2>/dev/null || true' EXIT

echo "==> Waiting for Grafana to be reachable"
for i in $(seq 1 30); do
  if curl -sf "${GRAFANA_LOCAL}/api/health" >/dev/null 2>&1; then
    echo "    Grafana is ready"
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "ERROR: Grafana did not become reachable within 30s"
    exit 1
  fi
  sleep 1
done

for DASH_ID in "${DASHBOARD_IDS[@]}"; do
  echo "==> Importing dashboard ${DASH_ID} from grafana.com"

  DASH_JSON=$(curl -sS -f "https://grafana.com/api/dashboards/${DASH_ID}/revisions/latest/download") || {
    echo "    ✗ Failed to download dashboard ${DASH_ID} from grafana.com (check ID is still published)"
    exit 1
  }

  PAYLOAD=$(cat <<ENDJSON
{
  "dashboard": ${DASH_JSON},
  "overwrite": true,
  "inputs": [
    {
      "name": "DS_PROMETHEUS",
      "type": "datasource",
      "pluginId": "prometheus",
      "value": "${PROMETHEUS_DS_UID}"
    }
  ]
}
ENDJSON
)

  HTTP_CODE=$(curl -s -o /tmp/grafana-import-response.json -w "%{http_code}" \
    -X POST "${GRAFANA_LOCAL}/api/dashboards/import" \
    -H "Content-Type: application/json" \
    -u "admin:${GRAFANA_PW}" \
    -d "${PAYLOAD}")

  if [ "${HTTP_CODE}" -ge 200 ] && [ "${HTTP_CODE}" -lt 300 ]; then
    SLUG=$(python3 -c "import json; print(json.load(open('/tmp/grafana-import-response.json')).get('slug','unknown'))" 2>/dev/null || echo "unknown")
    echo "    ✓ Dashboard ${DASH_ID} imported (slug: ${SLUG}, HTTP ${HTTP_CODE})"
  else
    echo "    ✗ Dashboard ${DASH_ID} import failed (HTTP ${HTTP_CODE})"
    cat /tmp/grafana-import-response.json 2>/dev/null || true
    exit 1
  fi
done

echo "==> All Beyla dashboards provisioned successfully"
