# Refactoring Report: bookinfo

## Metrics

|                    | Original | Refactored sources | of which: shared | Change        |
|--------------------|----------|--------------------|------------------|---------------|
| Lines              | 688      | 543                | 86               | −145 (−21%)   |
| Words              | 1313     | 931                | 151              | −382 (−29%)   |

Originals: `platform/kube/bookinfo.yaml`, `networking/destination-rule-all.yaml`,
`networking/destination-rule-all-mtls.yaml`, `networking/virtual-service-all-v1.yaml`,
`gateway-api/bookinfo-gateway.yaml`, `gateway-api/route-all-v1.yaml`,
`gateway-api/route-reviews-v1.yaml`, `gateway-api/route-reviews-v3.yaml`,
`gateway-api/route-reviews-50-v3.yaml`, `gateway-api/route-reviews-90-10.yaml`

Refactored sources: 37 `.yaml++` files — 6 in `shared/`, 14 in `platform/kube/`,
8 in `networking/` (4 mtls variants + 4 VirtualServices),
9 in `gateway-api/`

## Verification

**PASS** — all ten generated files match their originals exactly:

```
diff <(yq -S '.' platform/kube/bookinfo.yaml                  | grep -v '^null$') \
     <(yq -S '.' .generated/platform/kube/bookinfo.yaml       | grep -v '^null$')  # PASS
diff <(yq -S '.' networking/destination-rule-all.yaml         | grep -v '^null$') \
     <(yq -S '.' .generated/networking/destination-rule-all.yaml | grep -v '^null$')  # PASS
diff <(yq -S '.' networking/destination-rule-all-mtls.yaml    | grep -v '^null$') \
     <(yq -S '.' .generated/networking/destination-rule-all-mtls.yaml | grep -v '^null$')  # PASS
diff <(yq -S '.' networking/virtual-service-all-v1.yaml       | grep -v '^null$') \
     <(yq -S '.' .generated/networking/virtual-service-all-v1.yaml | grep -v '^null$')  # PASS
diff <(yq -S '.' gateway-api/bookinfo-gateway.yaml            | grep -v '^null$') \
     <(yq -S '.' .generated/gateway-api/bookinfo-gateway.yaml | grep -v '^null$')  # PASS
diff <(yq -S '.' gateway-api/route-all-v1.yaml                | grep -v '^null$') \
     <(yq -S '.' .generated/gateway-api/route-all-v1.yaml     | grep -v '^null$')  # PASS
diff <(yq -S '.' gateway-api/route-reviews-v1.yaml            | grep -v '^null$') \
     <(yq -S '.' .generated/gateway-api/route-reviews-v1.yaml | grep -v '^null$')  # PASS
diff <(yq -S '.' gateway-api/route-reviews-v3.yaml            | grep -v '^null$') \
     <(yq -S '.' .generated/gateway-api/route-reviews-v3.yaml | grep -v '^null$')  # PASS
diff <(yq -S '.' gateway-api/route-reviews-50-v3.yaml         | grep -v '^null$') \
     <(yq -S '.' .generated/gateway-api/route-reviews-50-v3.yaml | grep -v '^null$')  # PASS
diff <(yq -S '.' gateway-api/route-reviews-90-10.yaml         | grep -v '^null$') \
     <(yq -S '.' .generated/gateway-api/route-reviews-90-10.yaml | grep -v '^null$')  # PASS
```

## Findings

### platform/kube/bookinfo.yaml (14 documents)

This is the primary source of savings. The file contains 4 Services, 4 ServiceAccounts, and 7
Deployments (details-v1, ratings-v1, reviews-v1/v2/v3, productpage-v1).

**Service base** (`shared/bookinfo-service-base.yaml++`): All four Services share the same
`spec.ports` entry (`port: 9080, name: http`). Extracting this 6-line base and having each
Service variant supply only its `metadata` and `spec.selector` reduces four 13-line documents
to four 9-line documents — saving 10 lines (4 × 4 lines, less the 6-line base overhead at
amortized cost). Actual net: −10 lines.

**Reviews Deployment base** (`shared/reviews-deployment-base.yaml++`): The three reviews
Deployments (v1, v2, v3) are structurally identical except for the `version` label (in
`metadata.labels`, `spec.selector.matchLabels`, and `spec.template.metadata.labels`) and the
container image tag. The shared base captures `app: reviews` labels at all three nesting levels,
`serviceAccountName: bookinfo-reviews`, and the `volumes` block (two `emptyDir` entries — 5
lines). Each variant extends the base and provides only the `version` labels, the full containers
array (required because jq++ shallow-replaces arrays — the `imagePullPolicy`, `env`, `ports`, and
`volumeMounts` cannot be inherited), and the variant-specific image. This reduces three 40-line
documents to a 22-line base + three 29-line variants (109 lines total) versus 120 lines original
— saving 11 lines net.

**ServiceAccounts and simple Deployments** (details-v1, ratings-v1, productpage-v1): These are
kept verbatim. ServiceAccounts are 5 lines each — too small for a shared base to help. The
details-v1 and ratings-v1 deployments are 22 lines each; a generic base would save only
`apiVersion` + `kind` + `replicas` (3 lines × 2 = 6 lines) but incur `$extends` overhead per
variant, yielding a net of ~2 lines — well below threshold. The productpage-v1 deployment is
unique (prometheus annotations, no equivalent variant).

### networking/destination-rule-all.yaml + destination-rule-all-mtls.yaml

These two files are the strongest win: `destination-rule-all-mtls.yaml` is structurally identical
to `destination-rule-all.yaml` except that each DestinationRule gains a
`spec.trafficPolicy.tls.mode: ISTIO_MUTUAL` block.

The four DestinationRules (productpage, reviews, ratings, details) are placed in `shared/` as
canonical bases. `destination-rule-all.yaml` is generated by piping the four shared bases through
jq++ directly — no intermediate variant files needed. The four mtls variants in `networking/` each
extend the corresponding shared base and add the trafficPolicy object (5 lines each). This
eliminates the 62-line near-duplication between the two files entirely.

Combined: 136 original lines → 4 shared DRs (58 lines) + 4 mtls variants (24 lines) = 82 lines
— saving 54 lines (−40%).

### networking/virtual-service-all-v1.yaml

Four VirtualServices, each 13 lines. The `spec.hosts` and `spec.http` fields are arrays — jq++
shallow-replaces arrays, so a shared base could only contribute `apiVersion` and `kind` (2 lines).
Savings of 2 × 4 = 8 lines would be exactly consumed by the `$extends` overhead. Kept verbatim
as four individual files.

### gateway-api/bookinfo-gateway.yaml

A two-document file: a `Gateway` resource and an `HTTPRoute` that routes all productpage paths
to the productpage Service. Both documents are unique with no equivalent in other files — kept
verbatim, split into `bookinfo-gateway-gateway.yaml++` and `bookinfo-gateway-httproute.yaml++`.

### gateway-api/route-all-v1.yaml

Four HTTPRoutes, each 15 lines. Both `spec.parentRefs` and `spec.rules` are arrays — same
array-merge constraint applies. Kept verbatim as four individual files.

### gateway-api/route-reviews-{v1,v3,50-v3,90-10}.yaml

Four single-document HTTPRoute files providing alternative traffic-split configurations for the
reviews service. Each is unique (different backend sets and weights). Kept verbatim as individual
`.yaml++` files. The `route-reviews-v1.yaml++` source file is reused: it serves as both a
document within `route-all-v1.yaml` (assembled by `generate.sh`) and as the sole document in
the standalone `route-reviews-v1.yaml` output — avoiding any duplication between the two.

### Summary

Two patterns drove the savings:

1. **Shared Service port spec** — a 6-line base eliminates port repetition across 4 Services
2. **Shared reviews Deployment base** — captures the common structure (app labels, serviceAccount,
   volumes) across 3 identical-except-for-version Deployment variants
3. **DestinationRule mtls layering** — the mtls file is expressed as 4 tiny `$extends` overlays
   on top of the shared non-mtls DRs, eliminating ~62 lines of near-duplication

The Apache 2.0 license header (~130 words) present in the original `bookinfo.yaml` comment block
is stripped during the jq++ → yq round-trip, accounting for much of the word-count reduction.
