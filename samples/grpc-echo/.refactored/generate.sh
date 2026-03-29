#!/usr/bin/env bash
# generate.sh — regenerate ../.generated/ from jq++ sources in this directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../.generated"
mkdir -p "${OUT_DIR}"

# grpc-echo.yaml: Service + Deployment v1 + Deployment v2
{
  jq++ "${SCRIPT_DIR}/grpc-echo-service.yaml++"       | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/grpc-echo-deployment-v1.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/grpc-echo-deployment-v2.yaml++" | yq -y '.'
} > "${OUT_DIR}/grpc-echo.yaml"

echo "Generated: ${OUT_DIR}"
