# Refactoring Report — ambient-argo

## Metrics

| | Original | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 659 | 585 | 47 | −74 (−11%) |
| Words | 1146 | 972 | 76 | −174 (−15%) |

Counts cover `.yaml`/`.json` originals (excluding `tag-chart/`) vs `.yaml++` refactored sources (excluding `generate.sh`).

## Verification

**PASS** — all 17 generated files match their originals semantically (verified with `yq -S '.'` diff, filtering `null` documents from trailing `---` separators).

## Findings

### Patterns identified and addressed

**1. `bookinfo-versions.yaml` — 6 identical versioned Service shapes**

All six Services (reviews-v1/v2/v3, productpage-v1, ratings-v1, details-v1) were structurally identical: `apiVersion: v1`, `kind: Service`, port 9080/http, differing only in `metadata.name` and `spec.selector` (app + version). A single 6-line `shared/bookinfo-service-base.yaml++` covers the shared structure; each variant is an 8-line file that extends it and adds only `metadata.name` and `spec.selector`. The same base also serves the main bookinfo Services in `details.yaml`, `ratings.yaml`, `reviews.yaml`, and `productpage.yaml`.

**2. `reviews.yaml` — three nearly-identical Deployments**

The three reviews Deployments (v1/v2/v3) were 40 lines each and identical except for the version label in `metadata`, `spec.selector.matchLabels`, `spec.template.metadata.labels`, and the image tag. A 17-line `shared/reviews-deployment-base.yaml++` captures the shared skeleton (app label, replicas, selector, serviceAccountName, containers placeholder). Each variant extends it and overrides only the version-specific fields plus the full `containers`/`volumes` arrays (arrays are shallow-replaced in jq++, so they are always provided in full by the variant). This reduces each variant from 40 lines to 34 lines, saving 18 lines net across the three (after the 17-line base).

**3. `details-waypoint.yaml` and `reviews-waypoint.yaml` — identical waypoint Gateways**

Both are `istio-waypoint` Gateways with an identical `HBONE` mesh listener on port 15008, differing only in `metadata.name` and the `istio.io/rev` label value (`stable` vs `rapid`). A single 8-line `shared/waypoint-gateway-base.yaml++` captures this; each variant is 6 lines.

**4. ArgoCD Application files in `istio/` — shared deployment boilerplate**

`cni.yaml`, `extras.yaml`, `tags.yaml`, and `ztunnel.yaml` all share: `apiVersion/kind`, `metadata.namespace: argocd`, `metadata.finalizers`, `spec.project: default`, `spec.destination.name: ambient-cluster`, and `spec.syncPolicy.automated + syncOptions`. A 16-line `shared/argocd-app-ambient-cluster-base.yaml++` factors this out. Each variant extends it and adds only the destination namespace and source(s). `cni.yaml` went from 33 to 22 lines, `extras.yaml` from 24 to 13 lines, `ztunnel.yaml` from 25 to 14 lines, `tags.yaml` from 32 to 22 lines.

`meta-application.yaml` and `application/application.yaml` were not extended from the base: `meta-application.yaml` targets `in-cluster` (not `ambient-cluster`) and lacks `metadata.namespace: argocd`; `application.yaml` has a different namespace destination and no `syncOptions`.

`istio/control-plane-appset.yaml` is an `ApplicationSet`, not an `Application`, so it is a plain pass-through.

### Limitations

- **Comments stripped**: the inline comment on `istiodservice: "1-18-5"` in `tags.yaml` (`# This can be removed once ztunnel is on 1.20`) is lost in the jq++ → yq round-trip. This is a known limitation of YAML comment stripping.
- **Array merging**: jq++ shallow-replaces arrays, so `containers` and `volumes` in reviews deployments must be fully specified in each variant file, limiting the savings within those blocks.
- **`tag-chart/`**: The Helm chart files (`Chart.yaml`, `values.yaml`, and Go template files under `templates/`) were excluded — Go template syntax is not compatible with jq++ processing.
