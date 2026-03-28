# Refactoring Report: helloworld

## Metrics

| | Generated (baseline) | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 250 | 167 | 58 | −83 (−33%) |
| Words | 413 | 284 | 104 | −129 (−31%) |

Baseline is `.generated/` (not the originals), since the originals contain inline comments (e.g., `#Always`)
that are stripped during the jq++ → yq round-trip and would inflate apparent savings.

## Verification

**PASS** — 6/6 files match (`verify.sh` `.generated` vs `.sandbox`).

## Findings

### Deployment deduplication with `_version` private holder

The largest source of duplication: `helloworld.yaml` and `helloworld-dual-stack.yaml` each contain
Deployment v1 and Deployment v2, for a total of 4 near-identical Deployment specs (71 lines × 2 + 75 × 2
would be the naive expansion). The two Deployments within any one file differ only in 5 places — the
name suffix, version label, selector, template label, and image tag — all of which carry the same
version string (`v1` or `v2`).

This was addressed with a `_version` private holder in `shared/deployment-base.yaml++`:

```yaml
_version: <set by child>
metadata:
  name: "eval:string:\"helloworld-\" + refexpr(\"._version\")"
  labels:
    version: "eval:string:refexpr(\"._version\")"
...
  template:
    spec:
      containers:
        - image: "eval:string:\"registry.istio.io/.../helloworld-\" + refexpr(\"._version\") + \":1.0\""
```

`shared/deployment-v1.yaml++` and `deployment-v2.yaml++` each extend this base with only `_version: v1`
(or `v2`) — 3 lines each. The two old 28-line standalone specs collapse to 28 (base) + 3 + 3 = 34 lines.
Since both `helloworld.yaml++` and `helloworld-dual-stack.yaml++` reference the same shared deployments,
all four Deployment instances are now covered by a single base definition.

### Service deduplication

The helloworld Service (12 lines) appears verbatim in both `helloworld.yaml` and
`helloworld-dual-stack.yaml`. It is extracted into `shared/service-base.yaml++`. The dual-stack variant
extends it and adds only 4 lines (`ipFamilyPolicy` + `ipFamilies`), rather than restating the 17-line
service in full.

### gateway-api versioned Services

`helloworld-versions.yaml` contains two Services (v1 and v2) that differ only in `metadata.name` and
`spec.selector.version`. A `shared/service-version-base.yaml++` template uses `_version` + `eval:` for
both fields. `helloworld-versions.yaml++` is now 7 lines (`$extends` + `_version` stubs separated by
`---`), down from 20 lines for the two old part files.

### Files with no significant repetition

`helloworld-gateway.yaml++` (33 lines), `gateway-api/helloworld-gateway.yaml++` (29 lines), and
`gateway-api/helloworld-route.yaml++` (19 lines) had no meaningful intra-file repetition and are written
as plain multi-document `.yaml++` files without `$extends`.

### Migration from `@NN` part files to single `.yaml++`

All `@NN` part-file groups were converted to single multi-document `.yaml++` files with `---` separators,
matching the current preferred authoring pattern.

### Limitations

- YAML comments (`#Always` on `imagePullPolicy` lines) are stripped by the jq++ → yq round-trip.
- `helloworld-gateway.yaml++` and `gateway-api/helloworld-gateway.yaml++` are coincidentally similar
  (both named `helloworld-gateway`, both two-document files), but they use different API groups
  (`networking.istio.io/v1` vs `gateway.networking.k8s.io/v1`) and are not related structurally.
