# Refactoring Report: helloworld

## Metrics

| | Original | Refactored sources | Change |
|---|---|---|---|
| Lines | 250 | 279 | +29 (+12%) |
| Words | 422 | 459 | +37 (+9%) |

Note: line/word counts increase because the 6 original multi-document YAML files are split
into 11 individual `.yaml++` files — file-split overhead outweighs savings for the
gateway/route files that have no shared structure.

## Verification

**PASS (6/6)** — semantic diff (sorted JSON via `yq -S '.'`) confirms all six output files
match their originals.

## Findings

### Key pattern: Deployment v1/v2 duplication

`helloworld.yaml` and `helloworld-dual-stack.yaml` each contain the same two Deployments
(helloworld-v1 and helloworld-v2). The two Deployments differ in only three fields: the
`version` label (in metadata, selector, and template), and the image tag suffix (`-v1`/`-v2`).
Each Deployment is now written once as a `.yaml++` file and referenced twice in `generate.sh`
(for both output files). This is where the cross-document DRY benefit is most tangible.

### Three-level inheritance: dual-stack Service

`helloworld-dual-stack.yaml`'s Service adds just three fields to the standard helloworld
Service (`ipFamilyPolicy`, `ipFamilies`). The chain is:
`helloworld-service-dual-stack.yaml++` → `helloworld-service.yaml++` → `shared/service-base.yaml++`

Only those 3 fields appear in the dual-stack file, cleanly capturing the delta.

### No benefit for gateway/route files

`helloworld-gateway.yaml`, `gateway-api/helloworld-gateway.yaml`, and
`gateway-api/helloworld-route.yaml` contain Istio/Gateway-API resources with no meaningful
repetition between them. They are refactored as plain `.yaml++` files (no `$extends`) —
equivalent to the originals but with YAML formatting normalized by jq++.

### Why line count increases

The original files pack multiple documents tightly into 6 files. Splitting into 11 files
adds per-file overhead (~2–3 lines each). For the deployment and service files this is
offset by shared bases; for the gateway/route files it is not. The source overhead is
acceptable because `generate.sh` reconstructs the original multi-document structure exactly,
and each `.yaml++` file is independently readable and modifiable.

### Comment loss

The original files contain inline comments (e.g., `imagePullPolicy: IfNotPresent #Always`).
These are stripped during the jq++ → yq round-trip. The generated output is semantically
equivalent but loses these annotations.
