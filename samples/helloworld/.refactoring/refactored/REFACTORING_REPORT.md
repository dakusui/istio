# Refactoring Report: helloworld

## Metrics

| | Generated (baseline) | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 250 | 165 | 56 | −85 (−34%) |
| Words | 413 | 278 | 98 | −135 (−33%) |

Baseline is `.refactoring/generated/` (not the originals), since the originals contain inline comments
(e.g., `#Always` on `imagePullPolicy` lines) that are stripped during the jq++ → yq round-trip and
would inflate apparent savings.

## Verification

**PASS** — 6/6 files match.

## Findings

### Deployment deduplication with `_version` private holder

The dominant source of duplication: `helloworld.yaml` and `helloworld-dual-stack.yaml` each contain
two Deployments (v1 and v2) that are identical in structure and differ only in five places — the name
suffix, version label, selector, template label, and image tag — all driven by the same version string.

A single `shared/deployment-base.yaml++` (28 lines) captures the full Deployment structure and derives
all version-dependent fields from a private `_version` holder:

```yaml
metadata:
  name: "eval:string:\"helloworld-\" + refexpr(\"._version\")"
  labels:
    version: "eval:string:refexpr(\"._version\")"
spec:
  selector:
    matchLabels:
      version: "eval:string:refexpr(\"._version\")"
  template:
    spec:
      containers:
        - image: "eval:string:\"registry.istio.io/release/examples-helloworld-\" + refexpr(\"._version\") + \":1.0\""
```

`shared/deployment-v1.yaml++` and `shared/deployment-v2.yaml++` are each 3 lines — just `$extends`
plus `_version: v1` (or `v2`). Both `helloworld.yaml++` and `helloworld-dual-stack.yaml++` extend
these shared files, so all four Deployment instances across the two output files are covered by a
single base definition.

### Service deduplication — two-level inheritance

Both `service-base` (the plain helloworld Service) and `service-version-base` (the versioned Services
used in `gateway-api/helloworld-versions.yaml`) share the same `apiVersion: v1`, `kind: Service`,
`spec.ports`, and `spec.selector.app: helloworld` — seven lines in common.

These are extracted into `shared/service-common-base.yaml++`, which both files extend:

- `service-base.yaml++` adds `metadata.name: helloworld` and `metadata.labels`.
- `service-version-base.yaml++` adds `metadata.name` (version-derived eval) and `spec.selector.version`.

jq++ deep-merges the `spec.selector` object, so `service-version-base` only needs to supply the
`version` key — `app: helloworld` is inherited from `service-common-base` automatically.

`helloworld.yaml++` is 8 lines — three `$extends` stubs separated by `---`.
`helloworld-dual-stack.yaml++` is 13 lines — first document extends `service-base` with the dual-stack
override (`ipFamilyPolicy` + `ipFamilies`); the remaining two documents are identical one-liner stubs.

### gateway-api versioned Services

`gateway-api/helloworld-versions.yaml` contains two Services (v1 and v2) differing only in
`metadata.name` and `spec.selector.version`. `shared/service-version-base.yaml++` derives both fields
from `_version`. `gateway-api/helloworld-versions.yaml++` is 7 lines (two `$extends` + `_version`
stubs separated by `---`), down from 23 lines in the generated baseline — a 70% reduction for that
file.

### Files with no significant repetition

`helloworld-gateway.yaml++` (33 lines), `gateway-api/helloworld-gateway.yaml++` (29 lines), and
`gateway-api/helloworld-route.yaml++` (19 lines) have no intra-file or cross-file structural
repetition and are written as plain multi-document `.yaml++` files without `$extends`. The two gateway
files are superficially similar (both named `helloworld-gateway`, both two-document files) but use
different API groups (`networking.istio.io/v1` vs `gateway.networking.k8s.io/v1`) and are unrelated
structurally.

### Limitations

- YAML comments (`#Always` on `imagePullPolicy` lines) are stripped during the jq++ → yq round-trip
  and do not appear in the generated output.
