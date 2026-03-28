#!/usr/bin/env bash
# generate.sh — regenerate ../.generated/ from jq++ sources in this directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../.generated"
mkdir -p "${OUT_DIR}" "${OUT_DIR}/loki" "${OUT_DIR}/tracing"

# otel.yaml: ConfigMap + Service + Deployment
{
  jq++ "${SCRIPT_DIR}/otel-configmap.yaml++"  | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/otel-service.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/otel-deployment.yaml++" | yq -y '.'
} > "${OUT_DIR}/otel.yaml"

# loki/otel.yaml: ConfigMap + Service + Deployment
{
  jq++ "${SCRIPT_DIR}/loki/otel-configmap.yaml++"  | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/loki/otel-service.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/loki/otel-deployment.yaml++" | yq -y '.'
} > "${OUT_DIR}/loki/otel.yaml"

# loki/iop.yaml: single IstioOperator
jq++ "${SCRIPT_DIR}/loki/iop.yaml++" | yq -y '.' > "${OUT_DIR}/loki/iop.yaml"

# loki/telemetry.yaml: single Telemetry
jq++ "${SCRIPT_DIR}/loki/telemetry.yaml++" | yq -y '.' > "${OUT_DIR}/loki/telemetry.yaml"

# tracing/telemetry.yaml: single Telemetry
jq++ "${SCRIPT_DIR}/tracing/telemetry.yaml++" | yq -y '.' > "${OUT_DIR}/tracing/telemetry.yaml"

echo "Generated: ${OUT_DIR}"
