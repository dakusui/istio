#!/usr/bin/env bash
# generate.sh — regenerate ../.generated/ from jq++ sources in this directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../.generated"
mkdir -p "${OUT_DIR}"

# Concatenate all 6 Config documents into one skaffold.yaml
{
  jq++ "${SCRIPT_DIR}/skaffold-istio-base.yaml++"  | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/skaffold-istiod.yaml++"      | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/skaffold-ingress.yaml++"     | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/skaffold-prometheus.yaml++"  | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/skaffold-kiali.yaml++"       | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/skaffold-bookinfo.yaml++"    | yq -y '.'
} > "${OUT_DIR}/skaffold.yaml"

echo "Generated: ${OUT_DIR}"
