#!/usr/bin/env bash
# generate.sh — regenerate ../.generated/ from jq++ sources in this directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../.generated"
mkdir -p "${OUT_DIR}"

# ext-authz.yaml: Service + Deployment
{
  jq++ "${SCRIPT_DIR}/ext-authz-service.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/ext-authz-deployment.yaml++" | yq -y '.'
  printf -- "---\n"
} > "${OUT_DIR}/ext-authz.yaml"

# local-ext-authz.yaml: 2 ServiceEntries + Deployment + Service + ServiceAccount
{
  jq++ "${SCRIPT_DIR}/local-ext-authz-service-entry-http.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/local-ext-authz-service-entry-grpc.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/local-ext-authz-deployment.yaml++"         | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/local-ext-authz-service.yaml++"            | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/local-ext-authz-serviceaccount.yaml++"     | yq -y '.'
  printf -- "---\n"
} > "${OUT_DIR}/local-ext-authz.yaml"

echo "Generated: ${OUT_DIR}"
