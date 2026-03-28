# Refactoring Report: open-telemetry

## Metrics

| | Original | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 312 | 288 | 32 | −24 (−8%) |
| Words | 563 | 487 | 53 | −76 (−13%) |

## Verification

**PASS** — All generated files match originals semantically:

```
otel.yaml:              PASS
loki/otel.yaml:         PASS
loki/iop.yaml:          PASS
loki/telemetry.yaml:    PASS
tracing/telemetry.yaml: PASS
```

Verified with `yq -S '.'` (sorted-key diff) against originals.

## Source file layout

```
.refactored/
  shared/
    otel-deployment-base.yaml++      # shared Deployment boilerplate (strategy, volumes, pod spec)
  otel-configmap.yaml++              # ConfigMap (root otel config — zipkin/opencensus/auth)
  otel-service.yaml++                # Service (4 ports: 55678, 4317, 4318, 5317)
  otel-deployment.yaml++             # Deployment (root, image 0.123.0, args, 3 ports)
  loki/
    otel-configmap.yaml++            # ConfigMap (loki config — loki exporter)
    otel-service.yaml++              # Service (2 ports: 55678, 4317)
    otel-deployment.yaml++           # Deployment (loki, image 0.73.0, command, 2 ports)
    iop.yaml++                       # IstioOperator (envoyOtelAls extension provider)
    telemetry.yaml++                 # Telemetry (mesh-logging access logging)
  tracing/
    telemetry.yaml++                 # Telemetry (otel-demo tracing)
  generate.sh
```

## Findings

### Document splitting

Both multi-document `otel.yaml` files (root and `loki/`) are split into individual `.yaml++` files per resource. Single-document files (`iop.yaml`, `telemetry.yaml`) translate 1:1.

### Shared Deployment base

The root `otel.yaml` and `loki/otel.yaml` Deployments share 30 lines of identical boilerplate extracted to `shared/otel-deployment-base.yaml++`:

- `apiVersion`, `kind`, `metadata.name`
- `spec.selector.matchLabels`
- `spec.strategy` (rolling update with maxSurge/maxUnavailable)
- `spec.template.metadata.labels` (including `sidecar.istio.io/inject: "false"`)
- `spec.template.spec` pod-level fields: `dnsPolicy`, `restartPolicy`, `schedulerName`, `terminationGracePeriodSeconds`
- `spec.template.spec.volumes` (the ConfigMap volume mount — identical in both)
- `spec.template.spec.containers: []` (placeholder)

The `loki/` variant uses `../shared/otel-deployment-base.yaml++` (relative upward path). Each variant overrides only `spec.template.spec.containers` with its specific image, startup args/command, and ports. Since `containers` is an array and jq++ shallow-replaces arrays, the variant's containers list fully replaces the base's `[]`, while the inherited `volumes` array is preserved untouched.

The two Deployments were 157 and 68 content lines respectively (after removing ConfigMap/Service). The shared base extracts the 30-line boilerplate so it appears once instead of twice — saving 26 lines.

### Container-level repetition (not abstracted)

Inside each container, ~25 lines are identical between root and loki: the `env` block (POD_NAME and POD_NAMESPACE from field references), `resources`, `terminationMessagePath/Policy`, and `volumeMounts`. These cannot be shared because they live inside the `containers` array, which is shallow-replaced on merge. Both variants must re-specify the full container spec.

### ConfigMap content

The two `opentelemetry-collector-config` ConfigMaps embed entirely different YAML-as-a-string content (root targets Zipkin/debug with OpenCensus and bearer auth; loki targets Loki with attribute processors). No structural sharing is possible.

### Service ports

The root Service has 4 ports (55678, 4317, 4318, 5317) while the loki Service has 2 (55678, 4317). Because `ports` is an array (shallow-replaced), a shared Service base would not reduce lines — each variant still needs its full ports list.

### Comments stripped

Inline port comments (`# Default endpoint for OpenTelemetry receiver.`, `# do not inject`) are stripped by the jq++ → yq round-trip and noted here for reference.
