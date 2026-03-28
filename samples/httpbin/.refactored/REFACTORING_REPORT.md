# Refactoring Report: httpbin

## Metrics

| | Original | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 219 | 152 | 36 | −67 (−31%) |
| Words | 537 | 252 | 60 | −285 (−53%) |

> **Note:** Word count reduction is partly dominated by license header comments in `httpbin.yaml` and `httpbin-nodeport.yaml` that are stripped during the jq++ → yq round-trip. The line reduction reflects both comment removal and genuine structural deduplication.

## Verification

**PASS** — All generated files match originals semantically:

```
httpbin.yaml:                    PASS
httpbin-gateway.yaml:            PASS
httpbin-nodeport.yaml:           PASS
gateway-api/httpbin-gateway.yaml: PASS
sample-client/fortio-deploy.yaml: PASS
```

Verified with `yq -S '.'` (sorted-key diff) against originals.

## Source file layout

```
.refactored/
  shared/
    httpbin-service-base.yaml++         # httpbin Service (ClusterIP fields, no type)
    httpbin-deployment-base.yaml++      # httpbin Deployment (no serviceAccountName)
  httpbin-serviceaccount.yaml++         # ServiceAccount httpbin
  httpbin-service.yaml++                # Service httpbin (ClusterIP — extends base, no overrides)
  httpbin-deployment.yaml++             # Deployment httpbin (extends base, adds serviceAccountName)
  httpbin-nodeport-service.yaml++       # Service httpbin (NodePort — extends base, adds type)
  httpbin-nodeport-deployment.yaml++    # Deployment httpbin (extends base, no overrides)
  httpbin-gateway-gateway.yaml++        # Gateway httpbin-gateway (Istio API)
  httpbin-gateway-virtualservice.yaml++ # VirtualService httpbin
  gateway-api/
    httpbin-gateway-gateway.yaml++      # Gateway httpbin-gateway (gateway.networking.k8s.io)
    httpbin-gateway-httproute.yaml++    # HTTPRoute httpbin
  sample-client/
    fortio-deploy-service.yaml++        # Service fortio
    fortio-deploy-deployment.yaml++     # Deployment fortio-deploy
  generate.sh
```

## Findings

### Document splitting

All five YAML files contain multiple `---`-separated documents. Each document is extracted into its own `.yaml++` file, preserving the original subdirectory layout under `.refactored/`.

### Shared httpbin Service base

The httpbin `Service` appears in both `httpbin.yaml` (no `type`, defaulting to ClusterIP) and `httpbin-nodeport.yaml` (with `type: NodePort`). The 14 shared lines — `apiVersion`, `kind`, `metadata`, `spec.ports`, and `spec.selector` — are extracted to `shared/httpbin-service-base.yaml++`. The two variants become:

- `httpbin-service.yaml++`: a pure `$extends` with no overrides (2 lines)
- `httpbin-nodeport-service.yaml++`: `$extends` + `spec.type: NodePort` (4 lines)

This reduces 29 original lines to 14 (base) + 2 + 4 = 20 lines — saving **9 lines**.

### Shared httpbin Deployment base

The httpbin `Deployment` appears in both files with an identical structure. The sole difference: `httpbin.yaml` includes `spec.template.spec.serviceAccountName: httpbin`; `httpbin-nodeport.yaml` omits it. The 22-line common structure (including the full container spec with image, ports, labels, selectors) lives in `shared/httpbin-deployment-base.yaml++`. The variants:

- `httpbin-deployment.yaml++`: `$extends` + adds `spec.template.spec.serviceAccountName: httpbin` (6 lines). jq++ deep-merges `spec.template.spec`, leaving the inherited `containers` array untouched.
- `httpbin-nodeport-deployment.yaml++`: pure `$extends` with no overrides (2 lines)

This reduces 45 original lines to 22 (base) + 6 + 2 = 30 lines — saving **15 lines**.

### Remaining files

`httpbin-gateway.yaml`, `gateway-api/httpbin-gateway.yaml`, and `sample-client/fortio-deploy.yaml` have no cross-file repetition and are translated 1:1 into split `.yaml++` files. The fortio Deployment inline comment (`# This annotation causes Envoy to serve cluster.outbound statistics…`) is stripped by the yq round-trip and noted here for reference.
