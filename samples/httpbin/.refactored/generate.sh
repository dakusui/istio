#!/usr/bin/env bash
# generate.sh — regenerate ../.generated/ from jq++ sources in this directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../.generated"
mkdir -p "${OUT_DIR}" "${OUT_DIR}/gateway-api" "${OUT_DIR}/sample-client"

# httpbin.yaml: ServiceAccount + Service (ClusterIP) + Deployment (with serviceAccountName)
{
  jq++ "${SCRIPT_DIR}/httpbin-serviceaccount.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/httpbin-service.yaml++"        | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/httpbin-deployment.yaml++"     | yq -y '.'
} > "${OUT_DIR}/httpbin.yaml"

# httpbin-gateway.yaml: Gateway + VirtualService
{
  jq++ "${SCRIPT_DIR}/httpbin-gateway-gateway.yaml++"       | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/httpbin-gateway-virtualservice.yaml++" | yq -y '.'
} > "${OUT_DIR}/httpbin-gateway.yaml"

# httpbin-nodeport.yaml: Service (NodePort) + Deployment (no serviceAccountName)
{
  jq++ "${SCRIPT_DIR}/httpbin-nodeport-service.yaml++"     | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/httpbin-nodeport-deployment.yaml++"  | yq -y '.'
} > "${OUT_DIR}/httpbin-nodeport.yaml"

# gateway-api/httpbin-gateway.yaml: Gateway (gateway.networking.k8s.io) + HTTPRoute
{
  jq++ "${SCRIPT_DIR}/gateway-api/httpbin-gateway-gateway.yaml++"   | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/gateway-api/httpbin-gateway-httproute.yaml++" | yq -y '.'
} > "${OUT_DIR}/gateway-api/httpbin-gateway.yaml"

# sample-client/fortio-deploy.yaml: Service + Deployment
{
  jq++ "${SCRIPT_DIR}/sample-client/fortio-deploy-service.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/sample-client/fortio-deploy-deployment.yaml++" | yq -y '.'
} > "${OUT_DIR}/sample-client/fortio-deploy.yaml"

echo "Generated: ${OUT_DIR}"
