#!/usr/bin/env bash
# generate.sh — regenerate ../.generated/ from jq++ sources in this directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../.generated"
mkdir -p "${OUT_DIR}"
mkdir -p "${OUT_DIR}/gateway-api"

# helloworld.yaml: Service + Deployment v1 + Deployment v2
{
  jq++ "${SCRIPT_DIR}/helloworld-service.yaml++"        | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/helloworld-deployment-v1.yaml++"  | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/helloworld-deployment-v2.yaml++"  | yq -y '.'
} > "${OUT_DIR}/helloworld.yaml"

# helloworld-dual-stack.yaml: DualStack Service + same two Deployments
{
  jq++ "${SCRIPT_DIR}/helloworld-service-dual-stack.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/helloworld-deployment-v1.yaml++"      | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/helloworld-deployment-v2.yaml++"      | yq -y '.'
} > "${OUT_DIR}/helloworld-dual-stack.yaml"

# helloworld-gateway.yaml: Istio Gateway + VirtualService
{
  jq++ "${SCRIPT_DIR}/helloworld-gw-istio.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/helloworld-vs.yaml++"        | yq -y '.'
} > "${OUT_DIR}/helloworld-gateway.yaml"

# gateway-api/helloworld-gateway.yaml: K8s Gateway + HTTPRoute (single backend)
{
  jq++ "${SCRIPT_DIR}/gateway-api/helloworld-gateway-gw.yaml++"       | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/gateway-api/helloworld-gateway-httproute.yaml++" | yq -y '.'
} > "${OUT_DIR}/gateway-api/helloworld-gateway.yaml"

# gateway-api/helloworld-route.yaml: weighted HTTPRoute
jq++ "${SCRIPT_DIR}/gateway-api/helloworld-route.yaml++" | yq -y '.' \
  > "${OUT_DIR}/gateway-api/helloworld-route.yaml"

# gateway-api/helloworld-versions.yaml: Service v1 + Service v2
{
  jq++ "${SCRIPT_DIR}/gateway-api/helloworld-versions-v1.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/gateway-api/helloworld-versions-v2.yaml++" | yq -y '.'
} > "${OUT_DIR}/gateway-api/helloworld-versions.yaml"

echo "Generated: ${OUT_DIR}"
