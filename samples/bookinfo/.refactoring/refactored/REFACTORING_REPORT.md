# Refactoring Report: bookinfo

## Metrics

| | Generated (baseline) | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 2042 | 1099 | 216 | −943 (−46%) |
| Words | 3482 | 1879 | 413 | −1603 (−46%) |

## Verification

PASS — 31/31 files match.

## Findings

The bookinfo sample spans four subdirectories (`platform/kube`, `networking`,
`gateway-api`, `policy`) and 31 output files covering six microservices across
multiple configuration variants. The refactoring reduced source volume by 46%
through 16 shared base files and one custom jq function library.

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

`virtual-service-all-v1.yaml` collapsed from 51 lines to 15 lines (−71%). It
contains four identical VirtualServices routing each app to its v1 subset; all
four are expressed as `_app: <name>` + `$extends: virtual-service-v1-base`.

DestinationRule files benefit from two complementary abstractions:

1. **Shared bases** (`destination-rule-base`, `destination-rule-mtls-base`)
   capture apiVersion, kind, host, and trafficPolicy — saving 4–8 lines per doc.

2. **Custom jq function** `versioned_subset(p)` (defined in `shared/subsets.jq`)
   reduces each subset entry from 3 lines to 1:
   ```
   # before                        # after
   - name: v2-mysql                - "eval:object:subsets::versioned_subset(\"v2-mysql\")"
     labels:
       version: v2-mysql
   ```
   Every subset entry in both DestinationRule files follows the pattern
   `name == labels.version`, so all 22 entries across the two files are
   collapsed this way. This is the first use of a custom `.jq` function
   library in the refactoring.

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
