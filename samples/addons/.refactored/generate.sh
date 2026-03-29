#!/usr/bin/env bash
# generate.sh — regenerate ../.generated/ from jq++ sources in this directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../.generated"
mkdir -p "${OUT_DIR}/extras"

R="${SCRIPT_DIR}"

# ---- grafana.yaml ----
{
  jq++ "${R}/grafana-serviceaccount.yaml++"   | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/grafana-configmap.yaml++"        | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/grafana-service.yaml++"          | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/grafana-deployment.yaml++"       | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/grafana-dashboards-istio.yaml++"          | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/grafana-dashboards-istio-services.yaml++" | yq -y '.'
} > "${OUT_DIR}/grafana.yaml"

# ---- jaeger.yaml ----
{
  jq++ "${R}/jaeger-deployment.yaml++"       | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/jaeger-service-tracing.yaml++"  | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/jaeger-configmap.yaml++"        | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/jaeger-service-zipkin.yaml++"   | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/jaeger-service-collector.yaml++" | yq -y '.'
} > "${OUT_DIR}/jaeger.yaml"

# ---- kiali.yaml ----
{
  jq++ "${R}/kiali-serviceaccount.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/kiali-configmap.yaml++"         | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/kiali-clusterrole.yaml++"       | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/kiali-clusterrolebinding.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/kiali-service.yaml++"           | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/kiali-deployment.yaml++"        | yq -y '.'
} > "${OUT_DIR}/kiali.yaml"

# ---- loki.yaml ----
{
  jq++ "${R}/loki-serviceaccount.yaml++"         | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/loki-configmap.yaml++"              | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/loki-runtime-configmap.yaml++"      | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/loki-clusterrole.yaml++"            | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/loki-clusterrolebinding.yaml++"     | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/loki-service-memberlist.yaml++"     | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/loki-service-headless.yaml++"       | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/loki-service.yaml++"                | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/loki-statefulset.yaml++"            | yq -y '.'
} > "${OUT_DIR}/loki.yaml"

# ---- prometheus.yaml ----
{
  jq++ "${R}/prometheus-serviceaccount.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/prometheus-configmap.yaml++"         | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/prometheus-clusterrole.yaml++"       | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/prometheus-clusterrolebinding.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/prometheus-service.yaml++"           | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/prometheus-deployment.yaml++"        | yq -y '.'
} > "${OUT_DIR}/prometheus.yaml"

# ---- extras/prometheus-operator.yaml ----
{
  jq++ "${R}/extras/prometheus-operator-podmonitor.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/extras/prometheus-operator-servicemonitor.yaml++" | yq -y '.'
} > "${OUT_DIR}/extras/prometheus-operator.yaml"

# ---- extras/skywalking.yaml ----
{
  jq++ "${R}/extras/skywalking-oap-deployment.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/extras/skywalking-oap-service-tracing.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/extras/skywalking-oap-service.yaml++"       | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/extras/skywalking-ui-deployment.yaml++"     | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/extras/skywalking-ui-service-tracing.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/extras/skywalking-ui-service.yaml++"        | yq -y '.'
} > "${OUT_DIR}/extras/skywalking.yaml"

# ---- extras/zipkin.yaml ----
{
  jq++ "${R}/extras/zipkin-deployment.yaml++"       | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/extras/zipkin-service-tracing.yaml++"  | yq -y '.'
  printf -- "---\n"
  jq++ "${R}/extras/zipkin-service.yaml++"          | yq -y '.'
} > "${OUT_DIR}/extras/zipkin.yaml"

echo "Generated: ${OUT_DIR}"
