#!/usr/bin/env bash
# generate.sh — regenerate ../.generated/ from jq++ sources in this directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../.generated"
mkdir -p "${OUT_DIR}/gateway-api"

# tcp-echo-services.yaml: Service + Deployment-v1 + Deployment-v2
{
  jq++ "${SCRIPT_DIR}/service-default.yaml++"  | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/deployment-v1.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/deployment-v2.yaml++"    | yq -y '.'
} > "${OUT_DIR}/tcp-echo-services.yaml"

# tcp-echo.yaml: Service + Deployment (hello)
{
  jq++ "${SCRIPT_DIR}/service-default.yaml++"             | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/shared/deployment-hello.yaml++"     | yq -y '.'
} > "${OUT_DIR}/tcp-echo.yaml"

# tcp-echo-ipv6.yaml: Service (IPv6 SingleStack) + Deployment (hello)
{
  jq++ "${SCRIPT_DIR}/service-ipv6.yaml++"                | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/shared/deployment-hello.yaml++"     | yq -y '.'
} > "${OUT_DIR}/tcp-echo-ipv6.yaml"

# tcp-echo-ipv4.yaml: Service (IPv4 SingleStack) + Deployment (hello)
{
  jq++ "${SCRIPT_DIR}/service-ipv4.yaml++"                | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/shared/deployment-hello.yaml++"     | yq -y '.'
} > "${OUT_DIR}/tcp-echo-ipv4.yaml"

# tcp-echo-dual-stack.yaml: Service (RequireDualStack) + Deployment (hello)
{
  jq++ "${SCRIPT_DIR}/service-dual-stack.yaml++"          | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/shared/deployment-hello.yaml++"     | yq -y '.'
} > "${OUT_DIR}/tcp-echo-dual-stack.yaml"

# tcp-echo-all-v1.yaml: Gateway + DestinationRule + VirtualService (all v1)
{
  jq++ "${SCRIPT_DIR}/istio-gateway.yaml++"               | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/destination-rule.yaml++"            | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/virtualservice-all-v1.yaml++"       | yq -y '.'
} > "${OUT_DIR}/tcp-echo-all-v1.yaml"

# tcp-echo-20-v2.yaml: VirtualService (80/20 split)
jq++ "${SCRIPT_DIR}/virtualservice-20-v2.yaml++" | yq -y '.' > "${OUT_DIR}/tcp-echo-20-v2.yaml"

# gateway-api/tcp-echo-all-v1.yaml: Gateway + Service-v1 + Service-v2 + TCPRoute (all v1)
{
  jq++ "${SCRIPT_DIR}/gateway-api/gateway.yaml++"         | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/gateway-api/service-v1.yaml++"      | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/gateway-api/service-v2.yaml++"      | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/gateway-api/tcproute-all-v1.yaml++" | yq -y '.'
} > "${OUT_DIR}/gateway-api/tcp-echo-all-v1.yaml"

# gateway-api/tcp-echo-20-v2.yaml: TCPRoute (80/20 split)
jq++ "${SCRIPT_DIR}/gateway-api/tcproute-20-v2.yaml++" | yq -y '.' \
  > "${OUT_DIR}/gateway-api/tcp-echo-20-v2.yaml"

echo "Generated: ${OUT_DIR}"
