# Refactoring Report: helloworld

## Metrics

| | Generated (baseline) | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 250 | 167 | 58 | −83 (−33%) |
| Words | 413 | 284 | 104 | −129 (−31%) |

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

### Service deduplication

The helloworld Service (13 lines in generated form) appears verbatim in both `helloworld.yaml` and
`helloworld-dual-stack.yaml`. Extracting it into `shared/service-base.yaml++` lets the dual-stack
variant extend it and add only 4 lines (`ipFamilyPolicy` + `ipFamilies`) rather than restating the
full service.

`helloworld.yaml++` is therefore 8 lines — three `$extends` stubs separated by `---`.
`helloworld-dual-stack.yaml++` is 13 lines — first document extends `service-base` with the dual-stack
override; the remaining two documents are identical one-liner stubs.

### gateway-api versioned Services

`gateway-api/helloworld-versions.yaml` contains two Services (v1 and v2) differing only in
`metadata.name` and `spec.selector.version`. A `shared/service-version-base.yaml++` (11 lines) derives
both fields from `_version`. `gateway-api/helloworld-versions.yaml++` is 7 lines (two `$extends` +
`_version` stubs separated by `---`), down from 23 lines in the generated baseline — a 70% reduction
for that file.

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
