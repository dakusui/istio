# Refactoring Report: grpc-echo

## Metrics

| | Original | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 191 | 193 | 18 | +2 (+1%) |
| Words | 350 | 346 | 28 | −4 (−1%) |

## Verification

**PASS** — Generated file matches original semantically:

```
grpc-echo.yaml: PASS
```

Verified with `yq -S '.'` (sorted-key diff) against original.

## Source file layout

```
.refactored/
  shared/
    deployment-base.yaml++        # shared Deployment boilerplate for echo-v1 and echo-v2
  grpc-echo-service.yaml++        # echo Service (ClusterIP, ports 80/7070/9090)
  grpc-echo-deployment-v1.yaml++  # echo-v1 Deployment
  grpc-echo-deployment-v2.yaml++  # echo-v2 Deployment
  generate.sh
```

## Findings

### Document splitting

The single multi-document `grpc-echo.yaml` (3 docs) is split into one `.yaml++` file per resource.

### Shared Deployment base

The two Deployments (`echo-v1` and `echo-v2`) are nearly identical. They share 18 lines of Deployment boilerplate extracted to `shared/deployment-base.yaml++`:

- `apiVersion: apps/v1`, `kind: Deployment`
- `metadata.namespace: echo-grpc`
- `spec.replicas: 1`
- `spec.selector.matchLabels.app: echo`
- `spec.template.metadata.annotations` (`inject.istio.io/templates` and `proxy.istio.io/config`)
- `spec.template.metadata.labels.app: echo`
- `spec.template.spec.containers: []` (placeholder)

Each variant adds via `$extends`: `metadata.name`, `spec.selector.matchLabels.version`, `spec.template.metadata.labels.version`, and the full `containers` array.

### Array merge limitation — container spec repeats

The largest section of each Deployment — the container spec (~60 lines: `env`, `livenessProbe`, `readinessProbe`, `startupProbe`, `ports`, `image`, `imagePullPolicy`) — is identical between v1 and v2 and cannot be shared. jq++ shallow-replaces arrays, so a child's `containers: [...]` fully replaces the parent's `containers: []`. Any container fields placed in the base would be overwritten, requiring the variant to re-specify the entire container anyway. This is the fundamental constraint preventing larger savings here.

The actual per-variant differences are only 3 fields:
1. `metadata.name`: `echo-v1` vs `echo-v2`
2. `version` label (selector + pod template): `v1` vs `v2`
3. `--version` arg value: `v1` vs `v2`
4. Minor arg ordering: v1 places `--port 18080` before `--xds-grpc-server=17070`; v2 reverses these

### Net line impact

The 18-line base saves 18 lines × 2 (once per variant) = 36 lines. The `$extends` blocks add 2 lines × 2 = 4 lines. Net saving: 32 lines. However, this is offset by the ~34 extra lines needed to re-specify the full containers array in each variant vs the original (which already included it). The result is effectively break-even at the file level (+2 lines total).

The structural value is in explicit documentation: the base makes clear that both Deployments share the same Istio injection annotations, namespace, and label set — and that only the version discriminates them. This benefit grows with additional variants (v3, v4, etc.).
