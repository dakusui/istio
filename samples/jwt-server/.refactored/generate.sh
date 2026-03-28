#!/usr/bin/env bash
# generate.sh — regenerate ../.generated/ from jq++ sources in this directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../.generated"
mkdir -p "${OUT_DIR}"

# jwt-server.yaml: Service + Secret + Deployment
{
  jq++ "${SCRIPT_DIR}/jwt-server-service.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/jwt-server-secret.yaml++"     | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/jwt-server-deployment.yaml++" | yq -y '.'
} > "${OUT_DIR}/jwt-server.yaml"

echo "Generated: ${OUT_DIR}"
