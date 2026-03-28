#!/usr/bin/env bash
# generate.sh — regenerate ../.generated/ from jq++ sources in this directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../.generated"
mkdir -p "${OUT_DIR}"

# app.yaml: Service + Deployment
{
  jq++ "${SCRIPT_DIR}/app-service.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/app-deployment.yaml++" | yq -y '.'
} > "${OUT_DIR}/app.yaml"

# route.yaml: Gateway + VirtualService
{
  jq++ "${SCRIPT_DIR}/route-gateway.yaml++"        | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/route-virtualservice.yaml++" | yq -y '.'
} > "${OUT_DIR}/route.yaml"

echo "Generated: ${OUT_DIR}"
