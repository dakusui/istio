#!/usr/bin/env bash
# generate.sh — regenerate ../.generated/ from jq++ sources in this directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../.generated"
mkdir -p "${OUT_DIR}"

# expose-istiod.yaml: Gateway + VirtualService
{
  jq++ "${SCRIPT_DIR}/expose-istiod-gateway.yaml++"  | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/expose-istiod-vs.yaml++"       | yq -y '.'
} > "${OUT_DIR}/expose-istiod.yaml"

# expose-istiod-https.yaml: Gateway + VirtualService + DestinationRule
{
  jq++ "${SCRIPT_DIR}/expose-istiod-https-gateway.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/expose-istiod-https-vs.yaml++"      | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/expose-istiod-https-dr.yaml++"      | yq -y '.'
} > "${OUT_DIR}/expose-istiod-https.yaml"

# expose-services.yaml: single Gateway
jq++ "${SCRIPT_DIR}/expose-services-gateway.yaml++" | yq -y '.' > "${OUT_DIR}/expose-services.yaml"

echo "Generated: ${OUT_DIR}"
