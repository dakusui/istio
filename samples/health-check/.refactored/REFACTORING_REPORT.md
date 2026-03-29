# Refactoring Report: health-check

## Metrics

| | Original | Refactored sources | Change |
|---|---|---|---|
| Lines | 98 | 82 | −16 (−16%) |
| Words | 232 | 130 | −102 (−44%) |

Originals: `liveness-http-same-port.yaml`, `liveness-command.yaml`
Refactored sources: `shared/service-base.yaml++`, `shared/deployment-base.yaml++`, `liveness-{http-same-port,command}-{service,deployment}.yaml++`

## Verification

PASS — both generated files match their originals semantically (`yq -S` diff: no output).

## Findings

Both YAML files follow the same structural pattern: a Service document followed by a Deployment document. Four shared abstractions were extracted:

**`shared/service-base.yaml++`** captures the `apiVersion: v1 / kind: Service` skeleton and uses `eval:string:refexpr(".metadata.name")` to derive the `app` and `service` labels as well as the `selector.app` — all three previously repeated the same string as the service name. Each variant only needs to supply `metadata.name` and the port definition (6 lines each vs ~12 lines each).

**`shared/deployment-base.yaml++`** captures `apiVersion: apps/v1 / kind: Deployment` and uses `eval:` to derive `spec.selector.matchLabels.app` and `spec.template.metadata.labels.app` from `metadata.name`. The child's `containers` array fully replaces the base's `[]` placeholder (jq++ shallow-replaces arrays). Additional labels like `version: v1` in `liveness-http-same-port` are deep-merged into the selector and template label objects by the child.

**In-file `eval:` for container name** — each deployment uses `eval:string:refexpr(".metadata.name")` for the container name, which always matches the Deployment name in these samples, eliminating another repetition.

The word count reduction (−44%) is large relative to line count (−16%) because the eval expressions replace repeated string literals: `liveness-http` appeared 5 times in one file, `liveness` appeared 4 times in the other.

**Limitations:**
- YAML comments (including the Apache License header in `liveness-command.yaml`) are stripped during jq++ → yq round-trip and do not appear in `.generated/` output. This is a known limitation of the elaboration pipeline.
- Port `8001` still appears twice in `liveness-http-same-port-deployment.yaml++` (containerPort and livenessProbe.httpGet.port). Extracting it would require a phantom top-level field, which would pollute the output document.
