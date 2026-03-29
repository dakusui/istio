#!/usr/bin/env bash
# generate.sh — regenerate ../.generated/ from jq++ sources in this directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../.generated"
mkdir -p "${OUT_DIR}/application" "${OUT_DIR}/istio"

# top-level
jq++ "${SCRIPT_DIR}/meta-application.yaml++" | yq -y '.' > "${OUT_DIR}/meta-application.yaml"

# application/namespace.yaml (single doc)
jq++ "${SCRIPT_DIR}/application/namespace.yaml++" | yq -y '.' > "${OUT_DIR}/application/namespace.yaml"

# application/bookinfo-versions.yaml (6 versioned Services)
{
  jq++ "${SCRIPT_DIR}/application/bookinfo-versions-reviews-v1.yaml++"     | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/application/bookinfo-versions-reviews-v2.yaml++"     | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/application/bookinfo-versions-reviews-v3.yaml++"     | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/application/bookinfo-versions-productpage-v1.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/application/bookinfo-versions-ratings-v1.yaml++"     | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/application/bookinfo-versions-details-v1.yaml++"     | yq -y '.'
} > "${OUT_DIR}/application/bookinfo-versions.yaml"

# application/ingress-gateway.yaml (Gateway + HTTPRoute)
{
  jq++ "${SCRIPT_DIR}/application/ingress-gateway-gateway.yaml++"   | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/application/ingress-gateway-httproute.yaml++" | yq -y '.'
} > "${OUT_DIR}/application/ingress-gateway.yaml"

# application/details-waypoint.yaml (single doc)
jq++ "${SCRIPT_DIR}/application/details-waypoint.yaml++" | yq -y '.' > "${OUT_DIR}/application/details-waypoint.yaml"

# application/productpage.yaml (Service + ServiceAccount + Deployment)
{
  jq++ "${SCRIPT_DIR}/application/productpage-service.yaml++"        | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/application/productpage-serviceaccount.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/application/productpage-deployment.yaml++"     | yq -y '.'
} > "${OUT_DIR}/application/productpage.yaml"

# application/application.yaml (single doc)
jq++ "${SCRIPT_DIR}/application/application.yaml++" | yq -y '.' > "${OUT_DIR}/application/application.yaml"

# application/details.yaml (Service + ServiceAccount + Deployment)
{
  jq++ "${SCRIPT_DIR}/application/details-service.yaml++"        | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/application/details-serviceaccount.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/application/details-deployment.yaml++"     | yq -y '.'
} > "${OUT_DIR}/application/details.yaml"

# application/reviews.yaml (Service + ServiceAccount + 3 Deployments)
{
  jq++ "${SCRIPT_DIR}/application/reviews-service.yaml++"          | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/application/reviews-serviceaccount.yaml++"   | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/application/reviews-deployment-v1.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/application/reviews-deployment-v2.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/application/reviews-deployment-v3.yaml++"    | yq -y '.'
} > "${OUT_DIR}/application/reviews.yaml"

# application/route-reviews-90-10.yaml (single doc)
jq++ "${SCRIPT_DIR}/application/route-reviews-90-10.yaml++" | yq -y '.' > "${OUT_DIR}/application/route-reviews-90-10.yaml"

# application/ratings.yaml (Service + ServiceAccount + Deployment)
{
  jq++ "${SCRIPT_DIR}/application/ratings-service.yaml++"        | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/application/ratings-serviceaccount.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/application/ratings-deployment.yaml++"     | yq -y '.'
} > "${OUT_DIR}/application/ratings.yaml"

# application/reviews-waypoint.yaml (single doc)
jq++ "${SCRIPT_DIR}/application/reviews-waypoint.yaml++" | yq -y '.' > "${OUT_DIR}/application/reviews-waypoint.yaml"

# istio/cni.yaml
jq++ "${SCRIPT_DIR}/istio/cni.yaml++"                | yq -y '.' > "${OUT_DIR}/istio/cni.yaml"

# istio/extras.yaml
jq++ "${SCRIPT_DIR}/istio/extras.yaml++"             | yq -y '.' > "${OUT_DIR}/istio/extras.yaml"

# istio/control-plane-appset.yaml
jq++ "${SCRIPT_DIR}/istio/control-plane-appset.yaml++" | yq -y '.' > "${OUT_DIR}/istio/control-plane-appset.yaml"

# istio/tags.yaml
jq++ "${SCRIPT_DIR}/istio/tags.yaml++"               | yq -y '.' > "${OUT_DIR}/istio/tags.yaml"

# istio/ztunnel.yaml
jq++ "${SCRIPT_DIR}/istio/ztunnel.yaml++"            | yq -y '.' > "${OUT_DIR}/istio/ztunnel.yaml"

echo "Generated: ${OUT_DIR}"
