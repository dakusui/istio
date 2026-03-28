#!/usr/bin/env bash
# generate.sh — regenerate ../.generated/ from jq++ sources in this directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../.generated"
mkdir -p "${OUT_DIR}"

# rate-limit-service.yaml: Service(redis) + Deployment(redis) + Service(ratelimit) + Deployment(ratelimit)
{
  jq++ "${SCRIPT_DIR}/redis-service.yaml++"       | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/redis-deployment.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/ratelimit-service.yaml++"   | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/ratelimit-deployment.yaml++" | yq -y '.'
} > "${OUT_DIR}/rate-limit-service.yaml"

# local-rate-limit-service.yaml: single EnvoyFilter document
jq++ "${SCRIPT_DIR}/local-rate-limit-service.yaml++" | yq -y '.' \
  > "${OUT_DIR}/local-rate-limit-service.yaml"

echo "Generated: ${OUT_DIR}"
