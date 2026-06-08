#!/usr/bin/env bash
# Install Grafana + Prometheus (kube-prometheus-stack) and Tempo for demo observability.
set -euo pipefail

NAMESPACE="${K8S_NAMESPACE:-bankcorp}"
TEMPO_BUCKET="${TEMPO_TRACES_BUCKET:-}"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --set grafana.service.type=ClusterIP \
  --set grafana.service.port=80 \
  --set grafana.service.targetPort=3000 \
  --wait

if [[ -n "${TEMPO_BUCKET}" ]]; then
  helm upgrade --install tempo grafana/tempo \
    --namespace "${NAMESPACE}" \
    --set "tempo.storage.trace.backend=s3" \
    --set "tempo.storage.trace.s3.bucket=${TEMPO_BUCKET}" \
    --set "tempo.storage.trace.s3.region=${AWS_REGION:-us-east-1}" \
    --wait
fi

echo "Observability stack installed in ${NAMESPACE}"
