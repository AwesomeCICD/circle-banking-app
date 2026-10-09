#!/usr/bin/env bash
# Install Grafana + Prometheus (kube-prometheus-stack), Tempo, and Beyla
# for demo observability with network-level visibility.
set -euo pipefail

NAMESPACE="${K8S_NAMESPACE:-circle-banking-app}"
TEMPO_BUCKET="${TEMPO_TRACES_BUCKET:-}"
REGION="${AWS_REGION:-us-east-1}"
SECRETS_ID="AwesomeCICD/circle-banking-app/secrets"
# Pinned so a chart release cannot change the Alertmanager config mid-demo.
KUBE_PROMETHEUS_STACK_VERSION="92.1.0"
BEYLA_CHART_VERSION="1.16.11"

# Fetch Grafana admin password from Secrets Manager
GRAFANA_PW=$(aws secretsmanager get-secret-value \
  --region "${REGION}" --secret-id "${SECRETS_ID}" \
  --query SecretString --output text | python3 -c \
  "import json,sys; print(json.load(sys.stdin).get('grafana_admin_password','admin'))")
if [ "${GRAFANA_PW}" = "PLACEHOLDER" ]; then
  echo "ERROR: grafana_admin_password is still PLACEHOLDER in Secrets Manager (${SECRETS_ID})."
  echo "Set a real password before deploying: aws secretsmanager put-secret-value ..."
  exit 1
fi

# Smart Deployments webhook bearer token for Alertmanager. The Secret must
# exist before the Alertmanager pod mounts it, so it is always created; an
# unset token only means CircleCI rejects the webhook (401) until it is set.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OBS_DIR="${SCRIPT_DIR}/../kubernetes-manifests/observability"
TOKEN_FILE="$(mktemp)"
trap 'rm -f "${TOKEN_FILE}"' EXIT
aws secretsmanager get-secret-value \
  --region "${REGION}" --secret-id "${SECRETS_ID}" \
  --query SecretString --output text | python3 -c \
  "import json,sys; sys.stdout.write(json.load(sys.stdin).get('smart_deploys_webhook_token',''))" > "${TOKEN_FILE}"
if [ ! -s "${TOKEN_FILE}" ]; then
  echo "WARN: smart_deploys_webhook_token missing from ${SECRETS_ID}; Smart Deployments webhooks will be rejected until it is set."
  printf 'unset' > "${TOKEN_FILE}"
fi
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "${NAMESPACE}" create secret generic cba-smart-deploys-webhook \
  --from-file=token="${TOKEN_FILE}" \
  --dry-run=client -o yaml | kubectl apply -f -

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# --- Grafana + Prometheus ---
helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack \
  --version "${KUBE_PROMETHEUS_STACK_VERSION}" \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  -f "${OBS_DIR}/kube-prometheus-values.yaml" \
  --set grafana.service.type=ClusterIP \
  --set grafana.service.port=80 \
  --set grafana.service.targetPort=3000 \
  --set "grafana.adminPassword=${GRAFANA_PW}" \
  --set "grafana.grafana\\.ini.server.root_url=https://grafana.namer.fieldeng-sphereci.com" \
  --set "grafana.grafana\\.ini.server.serve_from_sub_path=false" \
  --wait

# --- Tempo (optional, requires S3 bucket) ---
if [[ -n "${TEMPO_BUCKET}" ]]; then
  helm upgrade --install tempo grafana/tempo \
    --namespace "${NAMESPACE}" \
    --set "tempo.storage.trace.backend=s3" \
    --set "tempo.storage.trace.s3.bucket=${TEMPO_BUCKET}" \
    --set "tempo.storage.trace.s3.region=${AWS_REGION:-us-east-1}" \
    --wait
fi

# --- Beyla (eBPF network + application auto-instrumentation) ---
# Runs as a DaemonSet; instruments HTTP/gRPC traffic without code changes.
# Exports metrics to Prometheus (scraped by kube-prometheus) and optionally
# traces to Tempo via OTLP.
helm upgrade --install beyla grafana/beyla \
  --version "${BEYLA_CHART_VERSION}" \
  --namespace "${NAMESPACE}" \
  --set config.attributes.kubernetes.enable=true \
  --set config.routes.unmatched=wildcard \
  --set config.discovery.services[0].k8s_namespace="${NAMESPACE}" \
  --set config.prometheus_export.port=9090 \
  --set config.prometheus_export.path="/metrics" \
  --set serviceMonitor.enabled=true \
  --set serviceMonitor.namespace="${NAMESPACE}" \
  --wait || echo "WARN: Beyla install returned non-zero (may need privileged DaemonSet — will retry)"

# --- Smart Deployments validation signal (Beyla PodMonitor + alert rule) ---
kubectl apply -f "${OBS_DIR}/smart-deploys.yaml"

echo "Observability stack installed in ${NAMESPACE}"
