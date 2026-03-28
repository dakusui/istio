#!/usr/bin/env bash
# generate.sh — regenerate ../.generated/ from jq++ sources in this directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../.generated"
mkdir -p "${OUT_DIR}"

# aptget.yaml: single ServiceEntry
jq++ "${SCRIPT_DIR}/aptget.yaml++" | yq -y '.' > "${OUT_DIR}/aptget.yaml"

# github.yaml: github-https + github-tcp
{
  jq++ "${SCRIPT_DIR}/github-https.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/github-tcp.yaml++"   | yq -y '.'
} > "${OUT_DIR}/github.yaml"

# pypi.yaml: three HTTPS ServiceEntries
{
  jq++ "${SCRIPT_DIR}/pypi-python-https.yaml++"      | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/pypi-pypi-https.yaml++"        | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/pypi-pythonhosted-https.yaml++" | yq -y '.'
} > "${OUT_DIR}/pypi.yaml"

echo "Generated: ${OUT_DIR}"
