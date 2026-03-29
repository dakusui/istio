#!/usr/bin/env bash
# generate.sh — regenerate ../.generated/ from jq++ sources in this directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../.generated"
mkdir -p "${OUT_DIR}"

jq++ "${SCRIPT_DIR}/custom-bootstrap.yaml++" | yq -y '.' > "${OUT_DIR}/custom-bootstrap.yaml"
jq++ "${SCRIPT_DIR}/example-app.yaml++"      | yq -y '.' > "${OUT_DIR}/example-app.yaml"

echo "Generated: ${OUT_DIR}"
