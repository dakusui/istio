# Refactoring Report: websockets

## Metrics

|                    | Original | Refactored sources | of which: shared | Change       |
|--------------------|----------|--------------------|------------------|--------------|
| Lines              | 69       | 71                 | 0                | +2 (+3%)     |
| Words              | 112      | 113                | 0                | +1 (+1%)     |

Originals: `app.yaml`, `route.yaml`
Refactored sources: `app-service.yaml++`, `app-deployment.yaml++`, `route-gateway.yaml++`, `route-virtualservice.yaml++`

## Verification

**PASS** — both generated files match the originals exactly:

```
diff <(yq -S '.' samples/websockets/app.yaml   | grep -v '^null$') \
     <(yq -S '.' samples/websockets/.generated/app.yaml   | grep -v '^null$')
# (no output — identical)

diff <(yq -S '.' samples/websockets/route.yaml | grep -v '^null$') \
     <(yq -S '.' samples/websockets/.generated/route.yaml | grep -v '^null$')
# (no output — identical)
```

## Findings

The `websockets` sample is small: two multi-document YAML files, four Kubernetes resources total.

**Repetition identified:**

- In `app.yaml`'s Deployment, `app: tornado` + `version: v1` appear twice — once in `spec.selector.matchLabels` and again in `spec.template.metadata.labels`. These two lines are the only meaningful structural repetition in the entire sample.
- Port `8888` appears in both the Service (`spec.ports[].port`) and the Deployment container (`ports[].containerPort`), but these are semantically distinct fields (service port vs container port) and eliminating the repetition would obscure that distinction.
- The gateway name `tornado-gateway` is referenced in both the Gateway's `metadata.name` and the VirtualService's `gateways` list, but they live in separate documents and sharing a single-value string across files via a shared base would add more lines than it saves.

**What jq++ provided:**

The `$local: AppLabels` block in `app-deployment.yaml++` eliminates the duplicate `app: tornado` + `version: v1` label block by defining it once and referencing it in both `selector.matchLabels` and `template.metadata.labels` via `$extends`. However, the `$local` definition itself costs 4 lines, and the savings from eliminating one duplicate block is only 2 lines — a net addition of 2 lines. The structural split (one resource per `.yaml++` file) similarly adds a small amount of overhead without a corresponding line reduction.

**Conclusion:** This sample is too small for jq++ refactoring to yield a net reduction in source size. The primary benefit of the refactoring is structural — each Kubernetes resource is now an independent, self-contained file — rather than quantitative. The `$local`/`$extends` pattern for labels is semantically cleaner (a single definition of `AppLabels` cannot drift between `selector` and `template`), but the line count savings do not materialize at this scale.
