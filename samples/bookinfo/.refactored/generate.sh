#!/usr/bin/env bash
# generate.sh — regenerate ../.generated/ from jq++ sources in this directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../.generated"
S="${SCRIPT_DIR}"

mkdir -p "${OUT_DIR}/platform/kube" "${OUT_DIR}/networking" "${OUT_DIR}/gateway-api"

# platform/kube/bookinfo.yaml — 14 documents: Service+ServiceAccount+Deployment × 4 apps
# (reviews has 3 Deployment variants instead of 1)
{
  jq++ "${S}/platform/kube/details-service.yaml++"          | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/platform/kube/details-serviceaccount.yaml++"   | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/platform/kube/details-deployment-v1.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/platform/kube/ratings-service.yaml++"          | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/platform/kube/ratings-serviceaccount.yaml++"   | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/platform/kube/ratings-deployment-v1.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/platform/kube/reviews-service.yaml++"          | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/platform/kube/reviews-serviceaccount.yaml++"   | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/platform/kube/reviews-deployment-v1.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/platform/kube/reviews-deployment-v2.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/platform/kube/reviews-deployment-v3.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/platform/kube/productpage-service.yaml++"      | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/platform/kube/productpage-serviceaccount.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/platform/kube/productpage-deployment-v1.yaml++" | yq -y '.'
} > "${OUT_DIR}/platform/kube/bookinfo.yaml"

# networking/destination-rule-all.yaml — 4 DRs assembled directly from shared bases
{
  jq++ "${S}/shared/dr-productpage.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/shared/dr-reviews.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/shared/dr-ratings.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/shared/dr-details.yaml++"    | yq -y '.'
} > "${OUT_DIR}/networking/destination-rule-all.yaml"

# networking/destination-rule-all-mtls.yaml — 4 mtls variants extending shared DRs
{
  jq++ "${S}/networking/dr-productpage-mtls.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/networking/dr-reviews-mtls.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/networking/dr-ratings-mtls.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/networking/dr-details-mtls.yaml++"    | yq -y '.'
} > "${OUT_DIR}/networking/destination-rule-all-mtls.yaml"

# networking/virtual-service-all-v1.yaml — 4 VirtualServices
{
  jq++ "${S}/networking/vs-productpage-v1.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/networking/vs-reviews-v1.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/networking/vs-ratings-v1.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/networking/vs-details-v1.yaml++"    | yq -y '.'
} > "${OUT_DIR}/networking/virtual-service-all-v1.yaml"

# gateway-api/bookinfo-gateway.yaml — Gateway + HTTPRoute
{
  jq++ "${S}/gateway-api/bookinfo-gateway-gateway.yaml++"   | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/gateway-api/bookinfo-gateway-httproute.yaml++" | yq -y '.'
} > "${OUT_DIR}/gateway-api/bookinfo-gateway.yaml"

# gateway-api/route-all-v1.yaml — 4 HTTPRoutes
{
  jq++ "${S}/gateway-api/route-reviews-v1.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/gateway-api/route-productpage-v1.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/gateway-api/route-ratings-v1.yaml++"    | yq -y '.'
  printf -- "---\n"
  jq++ "${S}/gateway-api/route-details-v1.yaml++"    | yq -y '.'
} > "${OUT_DIR}/gateway-api/route-all-v1.yaml"

# gateway-api/route-reviews-*.yaml — single-document variant files
jq++ "${S}/gateway-api/route-reviews-v1.yaml++"    | yq -y '.' > "${OUT_DIR}/gateway-api/route-reviews-v1.yaml"
jq++ "${S}/gateway-api/route-reviews-v3.yaml++"    | yq -y '.' > "${OUT_DIR}/gateway-api/route-reviews-v3.yaml"
jq++ "${S}/gateway-api/route-reviews-50-v3.yaml++" | yq -y '.' > "${OUT_DIR}/gateway-api/route-reviews-50-v3.yaml"
jq++ "${S}/gateway-api/route-reviews-90-10.yaml++" | yq -y '.' > "${OUT_DIR}/gateway-api/route-reviews-90-10.yaml"

echo "Generated: ${OUT_DIR}"
