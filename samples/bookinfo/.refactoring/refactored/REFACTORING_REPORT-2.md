# Refactoring Report: bookinfo

## Metrics

| | Generated (baseline) | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 2042 | 1172 | 212 | −870 (−43%) |
| Words | 3482 | 1981 | 406 | −1501 (−43%) |

## Verification

PASS — 31/31 files match.

## Findings

The bookinfo sample is the largest in the repository, spanning four subdirectories
(`platform/kube`, `networking`, `gateway-api`, `policy`) and 31 output files covering
six microservices across multiple configuration variants. The refactoring reduced
source volume by 43% through 15 shared base files.

### platform/kube — Deployment and Service boilerplate

The dominant pattern is the repetition of ServiceAccount → Service → Deployment triples
for each microservice (details, ratings, reviews-v1/v2/v3, productpage). Three shared
bases — `service-account-base`, `service-base`, and `simple-deployment-base` — capture
the common structure (apiVersion, kind, metadata scaffold, selector wiring). Individual
variant files only supply the differentiating fields: app label, image tag, and port.

The largest files show the biggest savings:
- `bookinfo.yaml`: 294 lines → 102 lines (−65%). All five services' triples are
  expressed as short variant files extending the shared bases.
- `bookinfo-dualstack.yaml`: 310 lines → 122 lines (−61%).
- `bookinfo-psa.yaml`: 330 lines → 108 lines (−67%), using dedicated
  `psa-simple-deployment-base` and `psa-reviews-deployment-base` that bake in the
  Pod Security Admission security contexts.

Reviews deployments use a separate `reviews-deployment-base` (and its PSA counterpart)
because they carry an additional `env: []` placeholder for the `DO_NOT_ENCRYPT`
environment variable.

The ratings-v2 mysql variants are an extreme case: `bookinfo-ratings-v2-mysql-vm.yaml`
and `bookinfo-ratings-v2-mysql.yaml` each shrank from 36 lines to 4 lines — they are
pure `$extends` with a single override field (`_app`), because their structure is
entirely captured by `ratings-v2-mysql-deployment-base`.

Private `_app` and `_port` holders drive `eval:string:refexpr(...)` expressions in the
bases, keeping derived values (container name, image suffix, Service selector, etc.)
consistent without repeating the literal string in every location.

### networking — VirtualService and DestinationRule patterns

`virtual-service-all-v1.yaml` collapsed from 51 lines to 15 lines (−71%). It contains
four identical VirtualServices routing each app to its v1 subset; all four are expressed
as `_app: <name>` + `$extends: virtual-service-v1-base`.

DestinationRule files (`destination-rule-all.yaml`, `destination-rule-all-mtls.yaml`)
saw more modest savings (61 → 53 lines each) because each rule still requires its own
`subsets` array listing, which jq++ shallow-replaces rather than merges.

### gateway-api — HTTPRoute patterns

`route-all-v1.yaml` contains four HTTPRoutes routing each service to its v1-versioned
backend. The new `httproute-svc-v1-base` uses a `_svc` holder to derive `metadata.name`,
`parentRefs[0].name`, and `backendRefs[0].name` (`_svc + "-v1"`), reducing 59 lines to
15 lines (−75%). Each of the four documents is just:

```yaml
$extends:
  - ../shared/httproute-svc-v1-base.yaml++
_svc: reviews   # (or productpage, ratings, details)
```

The four `route-reviews-*.yaml` files all target the same reviews service parentRef.
A `httproute-reviews-base` captures that common header; each variant only overrides
`spec.rules` with its specific `backendRefs` array. The single-backend files
(`route-reviews-v1`, `route-reviews-v3`) shrank from 14 to 7 lines; the weighted
two-backend files (`route-reviews-50-v3`, `route-reviews-90-10`) from 18 to 11 lines.

`bookinfo-gateway.yaml` was not reduced: its Gateway and HTTPRoute documents have
unique structures (gatewayClassName, multi-match path rules) with no counterparts
elsewhere in the sample.

### policy — EnvoyFilter base

Both EnvoyFilters in `productpage_envoy_ratelimit.yaml` share `namespace: istio-system`
and `workloadSelector.labels.istio: ingressgateway`. The `envoyfilter-ingressgateway-base`
extracts these, reducing the file from 80 to 72 lines. The saving is modest because the
bulk of each filter is its unique `configPatches` structure.

**Note:** The original file contains extensive inline YAML comments explaining the
`configPatches` semantics and providing example alternatives. These are stripped during
the jq++ → yq round-trip and do not appear in the generated output.
