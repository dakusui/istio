# Refactoring Report: bookinfo

## Metrics

| | Generated (baseline) | Refactored sources | of which: shared | Change |
|---|---|---|------------------|---|
| Lines | 2431 | 1392 | 266              | −1039 (−43%) |
| Words | 4135 | 2377 | 504              | −1758 (−43%) |

"Refactored sources" is leaf files + shared bases combined. The shared column is
a subset of that total, not an addition to it.

### Breakdown by subfolder

Leaf-file counts only; shared bases (266 lines / 504 words) serve all subfolders
and are not apportioned here.

#### Lines

| Subfolder | Generated | Refactored | Δ |
|---|---|---|---|
| gateway-api | 164 | 92 | −72 (−44%) |
| networking | 615 | 373 | −242 (−39%) |
| platform/kube | 1572 | 589 | −983 (−63%) |
| policy | 80 | 72 | −8 (−10%) |
| **shared** | — | **266** | — |
| **Total** | **2431** | **1392** | **−1039 (−43%)** |

#### Words

| Subfolder | Generated | Refactored | Δ |
|---|---|---|---|
| gateway-api | 303 | 163 | −140 (−46%) |
| networking | 1035 | 617 | −418 (−40%) |
| platform/kube | 2671 | 981 | −1690 (−63%) |
| policy | 126 | 112 | −14 (−11%) |
| **shared** | — | **504** | — |
| **Total** | **4135** | **2377** | **−1758 (−43%)** |

## Verification

PASS — 48/48 files match.

## Findings

The bookinfo sample spans four subdirectories (`platform/kube`, `networking`,
`gateway-api`, `policy`) and 48 output files covering six microservices across
multiple configuration variants. The refactoring reduced source volume by 43%
through 20 shared base files and one custom jq function library.

### platform/kube — Deployment and Service boilerplate

The dominant pattern is the repetition of ServiceAccount → Service → Deployment
triples for each microservice (details, ratings, reviews-v1/v2/v3, productpage).
Three shared bases — `service-account-base`, `service-base`, and
`simple-deployment-base` — capture the common structure. Individual variant
files supply only the differentiating fields: app label, image tag, and port.

The largest files show the biggest savings:
- `bookinfo.yaml`: 294 lines → 87 lines (−70%).
- `bookinfo-dualstack.yaml`: 310 lines → 107 lines (−65%).
- `bookinfo-psa.yaml`: 330 lines → 93 lines (−72%), using dedicated
  `psa-simple-deployment-base` and `psa-reviews-deployment-base` that bake in
  Pod Security Admission security contexts.

Reviews deployments use `reviews-deployment-base` (and its PSA counterpart)
because they carry an additional `env: []` placeholder for the `DO_NOT_ENCRYPT`
environment variable.

The ratings-v2 mysql variants are an extreme case: both `bookinfo-ratings-v2-mysql-vm.yaml++`
and `bookinfo-ratings-v2-mysql.yaml++` shrank from 36 lines to 4 lines — they
are pure `$extends` with a single `_app` override.

**serviceAccountName pattern:** All five service deployments follow
`serviceAccountName: bookinfo-{_app}`. A single `bookinfo-svcaccount-base.yaml++`
uses `eval:string:"bookinfo-" + refexpr("._app")` to derive the name, removing
an explicit 4-line block from 18 deployment documents across `bookinfo.yaml++`,
`bookinfo-dualstack.yaml++`, and `bookinfo-psa.yaml++`.

Private `_app` and `_port` holders drive `eval:string:refexpr(...)` expressions
in the bases, keeping derived values (container name, image suffix, Service
selector, etc.) consistent without repeating the literal string.

### networking — VirtualService and DestinationRule patterns

This subfolder contains 21 output files covering routing, traffic management,
fault injection, and egress. The refactoring reduced it from 615 to 373 leaf-file
lines (−39%), with three new shared bases introduced specifically for this area.

**DestinationRule bases** (`destination-rule-base`, `destination-rule-mtls-base`):
Used by `destination-rule-all.yaml++` and `destination-rule-all-mtls.yaml++` to
share the apiVersion / kind / host / trafficPolicy structure. The custom jq
function `versioned_subset(p)` (defined in `shared/subsets.jq`) reduces each
subset entry from 3 lines to 1:
```
# before                        # after
- name: v2-mysql                - "eval:object:subsets::versioned_subset(\"v2-mysql\")"
  labels:
    version: v2-mysql
```
All 22 entries across the two DestinationRule files follow the pattern
`name == labels.version`, so all are collapsed this way.

**`virtual-service-all-v1.yaml`** collapsed from 51 lines to 15 lines (−71%).
It contains four identical VirtualServices routing each app to its v1 subset;
all four are expressed as `_app: <name>` + `$extends: virtual-service-v1-base`.

**`virtual-service-subset-base.yaml++`** (new): Routes host `_app` to a
parameterized `_subset`. Used directly by `virtual-service-details-v2` and
`virtual-service-reviews-v3`, and as the building block for three ratings
scenario files — `virtual-service-ratings-db`, `virtual-service-ratings-mysql`,
and `virtual-service-ratings-mysql-vm`. Each of those is a two-document file
where the first document locks reviews to v3 and the second varies only the
ratings subset (`v2`, `v2-mysql`, `v2-mysql-vm`):
```yaml
$extends:
  - virtual-service-subset-base.yaml++
_app: ratings
_subset: v2-mysql
```

**`virtual-service-weighted-base.yaml++`** (new): Parameterizes two weighted
destinations with `_subset1/_weight1` and `_subset2/_weight2`. Used by all four
weighted-split variants (`50-v3`, `80-20`, `90-10`, `v2-v3`), each reduced to
6 lines.

**`virtual-service-reviews-jason-base.yaml++`** (new): Captures the
`end-user: jason` header-match pattern with a parameterized `_match_subset`
and `_default_subset`. Used by `virtual-service-reviews-test-v2` (jason→v2,
default→v1) and `virtual-service-reviews-jason-v2-v3` (jason→v2, default→v3),
each reduced to 4 lines.

**Float-preservation edge case:** `virtual-service-ratings-test-abort` and
`virtual-service-ratings-test-delay` both contain `value: 100.0`. Because jq++
normalizes this to `100` in its JSON pass, these two files use the `@01.yaml`
naming convention (bypassing jq++ elaboration and passing through `yq -y '.'`
directly) to preserve the float representation.

**Inlined as-is:** `certmanager-gateway`, `egress-rule-google-apis`, and
`fault-injection-details-v1` have unique structures with no counterparts
elsewhere in the sample and were left as plain `.yaml++` with no `$extends`.

### gateway-api — HTTPRoute patterns

`route-all-v1.yaml` contains four HTTPRoutes routing each service to its
v1-versioned backend. The `httproute-svc-v1-base` uses a `_svc` holder to
derive `metadata.name`, `parentRefs[0].name`, and `backendRefs[0].name`
(`_svc + "-v1"`), reducing 59 lines to 15 lines (−75%). Each document is:
```yaml
$extends:
  - httproute-svc-v1-base.yaml++
_svc: reviews
```

The four `route-reviews-*.yaml` files all target the same reviews service
parentRef. `httproute-reviews-base` captures that common header; each variant
only overrides `spec.rules` with its specific `backendRefs` array.

`bookinfo-gateway.yaml` was not reduced: its Gateway and HTTPRoute documents
have unique structures with no counterparts elsewhere in the sample.

### policy — EnvoyFilter base

Both EnvoyFilters share `namespace: istio-system` and
`workloadSelector.labels.istio: ingressgateway`. The `envoyfilter-ingressgateway-base`
extracts these, reducing the file from 80 to 72 lines. The saving is modest
because the bulk of each filter is its unique `configPatches` structure.

**Note:** The original file contains extensive inline YAML comments explaining
the `configPatches` semantics. These are stripped during the jq++ → yq
round-trip and do not appear in the generated output.
