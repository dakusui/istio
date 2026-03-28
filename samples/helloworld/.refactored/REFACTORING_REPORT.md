# Refactoring Report: helloworld

## Metrics

| | Generated (baseline) | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 250 | 195 | 56 | −55 (−22%) |
| Words | 413 | 328 | 90 | −85 (−21%) |

Baseline is `.generated/` (not the originals), since the originals contain inline comments (e.g., `#Always`)
that are stripped during the jq++ → yq round-trip and would inflate the apparent savings.
Files counted: `helloworld.yaml`, `helloworld-gateway.yaml`, `helloworld-dual-stack.yaml`,
`gateway-api/helloworld-gateway.yaml`, `gateway-api/helloworld-route.yaml`, `gateway-api/helloworld-versions.yaml`

## Verification

**PASS** — all 6 generated files are semantically equivalent to the originals (zero diff after `yq -S '.'` normalization):

- `helloworld.yaml` ✓
- `helloworld-gateway.yaml` ✓
- `helloworld-dual-stack.yaml` ✓
- `gateway-api/helloworld-gateway.yaml` ✓
- `gateway-api/helloworld-route.yaml` ✓
- `gateway-api/helloworld-versions.yaml` ✓

## Findings

### Primary repetition: identical Deployment specs across two files

The main source of duplication was that `helloworld.yaml` and `helloworld-dual-stack.yaml` each contain identical Deployment v1 and Deployment v2 documents — 4 occurrences of nearly identical 17-line specs, totalling 68 lines. The two deployments within each file differ only in 3 fields: the version label, the matchLabels selector, and the container image tag.

Both repetition axes were addressed by placing the full Deployment specs in `shared/deployment-v1.yaml++` and `shared/deployment-v2.yaml++` (28 lines each). The four per-stem part files (`helloworld@02-deployment-v1.yaml++`, etc.) become 2-line `$extends` stubs. This collapses 68 lines to 56 (shared) + 8 (stubs) = 64 lines — a direct reduction, with the structural benefit that any future change to the Deployment spec is made in one place.

A two-level hierarchy (a `deployment-base.yaml++` extended by `deployment-v1.yaml++` and `deployment-v2.yaml++`) was considered but rejected: because jq++ shallow-replaces arrays, the `containers` array cannot be inherited from a base and then partially overridden with just an image tag. The child must re-specify the full container entry, which eliminates most of the savings from a base file.

### Secondary repetition: dual-stack Service

`helloworld-dual-stack.yaml`'s Service document is identical to the one in `helloworld.yaml` except for 3 extra fields (`ipFamilyPolicy`, `ipFamilies`). Since the two services go into different output stems, they cannot share a part file, and a `$extends`-based approach would not save enough lines to be worthwhile. Each is written as a self-contained `@01-service.yaml++`.

### gateway-api files

`gateway-api/helloworld-versions.yaml` has two versioned Services (v1/v2) with the same structure — each 11 lines. A shared base would reduce them to ~9 (base) + 7 + 7 = 23 lines vs 22 lines, so sharing was not applied. Each is a standalone part file.

The `gateway-api/helloworld-gateway.yaml` (Gateway + HTTPRoute) and `gateway-api/helloworld-route.yaml` (single-doc HTTPRoute) had no significant intra-file repetition; they were split or passed through without extraction.

### Limitations

- YAML comments (e.g., `#Always` on `imagePullPolicy` lines) are stripped by the jq++ → yq round-trip. The generated files are semantically equivalent but lose inline comments.
- The `generate.sh` script and `gen-helloworld.sh` in the sample directory are not replaced by this refactoring; `yjoin` serves the same assembly role for `.yaml++` sources.
