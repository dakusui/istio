#!/usr/bin/env bash
# generate.sh — regenerate ../.generated/ from jq++ sources in this directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../.generated"
mkdir -p "${OUT_DIR}"

jq++ "${SCRIPT_DIR}/daemonset.yaml++" | yq -y '.' > "${OUT_DIR}/daemonset.yaml"

echo "Generated: ${OUT_DIR}"
