# Refactoring Report: security

## Metrics

|                    | Original | Refactored sources | of which: shared | Change       |
|--------------------|----------|--------------------|------------------|--------------|
| Lines              | 1325     | 1279               | 16               | −46 (−3%)    |
| Words              | 3692     | 3453               | 26               | −239 (−6%)   |

Originals: 10 YAML files across `psp/`, `spire/`, and `spire-trust-domain-federation/`

Refactored sources: 17 `.yaml++` files (1 in `shared/`, 3 in `psp/`, 7 in `spire/`, 4 in `spire-trust-domain-federation/`)

## Verification

**PASS** — all 10 generated files match their originals exactly:

```
psp/sidecar-psp.yaml                                PASS
spire/clusterspiffeid.yaml                          PASS
spire/istio-spire-config.yaml                       PASS
spire/curl-spire.yaml                               PASS
spire/sleep-spire.yaml                              PASS
spire/spire-quickstart.yaml                         PASS  (byte-for-byte diff)
spire-trust-domain-federation/spire-base.yaml       PASS
spire-trust-domain-federation/spire-east.yaml       PASS
spire-trust-domain-federation/spire-west.yaml       PASS
spire-trust-domain-federation/cluster-federated-trust-domain.yaml  PASS
```

## Findings

### Pattern identified: curl-spire.yaml and sleep-spire.yaml are near-identical

`curl-spire.yaml` and `sleep-spire.yaml` are structurally identical files (ServiceAccount + Service +
Deployment), differing only by app name (`curl` vs `sleep`) in ~8 distinct locations. This is the
only meaningful repetition in the entire sample.

The `shared/deployment-spire-app-base.yaml++` (16 lines) captures the common Deployment structure:
`replicas`, `spiffe.io/spire-managed-identity` label, `inject.istio.io/templates` annotation,
`terminationGracePeriodSeconds`, the `tmp` volume, and the empty `containers` placeholder.

Each variant (`curl-deployment.yaml++`, `sleep-deployment.yaml++`) extends the base and provides
the app-specific `name`, `selector`, `serviceAccountName`, and `containers` array (24 lines each).

**Why savings are small — array merge constraint:** The two containers differ only in `.name`
(`curl` vs `sleep`); `image`, `command`, `imagePullPolicy`, `volumeMounts`, and `securityContext` are
identical. However, jq++ shallow-replaces arrays — a child's `containers: [...]` fully replaces the
base's `containers: []`, so each variant must repeat the entire 10-line container spec. This prevents
extracting the shared container fields into the base. The net saving from the Deployment pair is
approximately 8 lines (the common non-array fields), offset slightly by the `$extends` directive overhead.

The ServiceAccount (4 lines each) and Service (13 lines each) documents were not given shared bases
because the structural overhead of `$extends` would produce no net line reduction for documents
this small.

### Files passed verbatim

**`spire/spire-quickstart.yaml`** (985 lines, ~26 documents): A large monolithic deployment manifest
for the SPIRE infrastructure. Each of its 26 documents is a unique resource (CRDs, ConfigMaps with
embedded HCL configs, RBAC, Deployment, DaemonSet). The three Services that share
`selector: {app: spire-server}` are too short to warrant a shared base. The CRD schemas contain
extensive auto-generated description strings repeated across two CRDs, but these are deeply nested
and non-structural — they document distinct types and cannot be meaningfully shared via jq++.
This file is passed verbatim using `cat` in `generate.sh`.

**`spire-trust-domain-federation/`**: These are Helm values files, not Kubernetes resources. The
relationship between `spire-base.yaml`, `spire-east.yaml`, and `spire-west.yaml` is intentional Helm
layering (applied as `helm install -f spire-base.yaml -f spire-east.yaml`). Merging them via
`$extends` would produce a fully-merged file that is not the correct Helm override artifact. These
files are passed verbatim.

**Comments stripped:** `curl-spire.yaml` and `sleep-spire.yaml` each have two inline comments
(section headers and a sidecar annotation note) that are lost in the jq++ → yq round-trip. The
`spire-quickstart.yaml` preserves its comments because it is passed via `cat` without jq++ processing.
