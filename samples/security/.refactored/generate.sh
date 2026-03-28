#!/usr/bin/env bash
# generate.sh — regenerate ../.generated/ from jq++ sources in this directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../.generated"
mkdir -p "${OUT_DIR}/psp"
mkdir -p "${OUT_DIR}/spire"
mkdir -p "${OUT_DIR}/spire-trust-domain-federation"

# psp/sidecar-psp.yaml: PodSecurityPolicy + ClusterRole + ClusterRoleBinding
{
  jq++ "${SCRIPT_DIR}/psp/pod-security-policy.yaml++"  | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/psp/cluster-role.yaml++"          | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/psp/cluster-role-binding.yaml++"  | yq -y '.'
} > "${OUT_DIR}/psp/sidecar-psp.yaml"

# spire/clusterspiffeid.yaml
jq++ "${SCRIPT_DIR}/spire/clusterspiffeid.yaml++" | yq -y '.' \
  > "${OUT_DIR}/spire/clusterspiffeid.yaml"

# spire/istio-spire-config.yaml
jq++ "${SCRIPT_DIR}/spire/istio-spire-config.yaml++" | yq -y '.' \
  > "${OUT_DIR}/spire/istio-spire-config.yaml"

# spire/curl-spire.yaml: ServiceAccount + Service + Deployment
{
  jq++ "${SCRIPT_DIR}/spire/curl-service-account.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/spire/curl-service.yaml++"         | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/spire/curl-deployment.yaml++"      | yq -y '.'
} > "${OUT_DIR}/spire/curl-spire.yaml"

# spire/sleep-spire.yaml: ServiceAccount + Service + Deployment
{
  jq++ "${SCRIPT_DIR}/spire/sleep-service-account.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/spire/sleep-service.yaml++"          | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/spire/sleep-deployment.yaml++"       | yq -y '.'
} > "${OUT_DIR}/spire/sleep-spire.yaml"

# spire/spire-quickstart.yaml — verbatim (26 documents, no structural repetition)
cat "${SCRIPT_DIR}/spire/spire-quickstart.yaml++" > "${OUT_DIR}/spire/spire-quickstart.yaml"

# spire-trust-domain-federation/ — Helm values files, verbatim (intentional layering)
cat "${SCRIPT_DIR}/spire-trust-domain-federation/spire-base.yaml++" \
  > "${OUT_DIR}/spire-trust-domain-federation/spire-base.yaml"
cat "${SCRIPT_DIR}/spire-trust-domain-federation/spire-east.yaml++" \
  > "${OUT_DIR}/spire-trust-domain-federation/spire-east.yaml"
cat "${SCRIPT_DIR}/spire-trust-domain-federation/spire-west.yaml++" \
  > "${OUT_DIR}/spire-trust-domain-federation/spire-west.yaml"
jq++ "${SCRIPT_DIR}/spire-trust-domain-federation/cluster-federated-trust-domain.yaml++" | yq -y '.' \
  > "${OUT_DIR}/spire-trust-domain-federation/cluster-federated-trust-domain.yaml"

echo "Generated: ${OUT_DIR}"
