#!/usr/bin/env bash
# generate.sh — regenerate ../.generated/ from jq++ sources in this directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../.generated"
mkdir -p "${OUT_DIR}"

{
  jq++ "${SCRIPT_DIR}/sleep-serviceaccount.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/sleep-service.yaml++"        | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/sleep-deployment.yaml++"     | yq -y '.'
} > "${OUT_DIR}/sleep.yaml"

echo "Generated: ${OUT_DIR}"
