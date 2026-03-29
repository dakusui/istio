#!/usr/bin/env bash
# generate.sh — regenerate ../.generated/ from jq++ sources in this directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../.generated"
mkdir -p "${OUT_DIR}"

# liveness-http-same-port.yaml: Service + Deployment
{
  jq++ "${SCRIPT_DIR}/liveness-http-same-port-service.yaml++"     | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/liveness-http-same-port-deployment.yaml++"  | yq -y '.'
} > "${OUT_DIR}/liveness-http-same-port.yaml"

# liveness-command.yaml: Service + Deployment
{
  jq++ "${SCRIPT_DIR}/liveness-command-service.yaml++"     | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/liveness-command-deployment.yaml++"  | yq -y '.'
} > "${OUT_DIR}/liveness-command.yaml"

echo "Generated: ${OUT_DIR}"
