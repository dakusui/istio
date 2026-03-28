# Refactoring Report: health-check

## Metrics

| | Generated (baseline) | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 81 | 87 | 0 | +6 (+7%) |
| Words | 133 | 145 | 0 | +12 (+9%) |

## Verification

**PASS** — 2/2 files match (`verify.sh` `.generated` vs `.sandbox`).

## Findings

### `_app` private holder

In both source files, the app name appears repeatedly across the Service and Deployment documents:
- `liveness-command.yaml`: `"liveness"` appears 4 times in the Service and 3 times in the Deployment
- `liveness-http-same-port.yaml`: `"liveness-http"` appears 4 times in the Service and 3 times in the Deployment

Both were refactored to define `_app` once at the top of each document and reference it via
`eval:string:refexpr("._app")`. Changing the app name now requires editing one line per document
rather than hunting down every occurrence.

### `_port` private holder

In `liveness-http-same-port.yaml`, port `8001` appears three times: in `spec.ports[0].port`
(Service), `containers[0].ports[0].containerPort` (Deployment), and
`livenessProbe.httpGet.port` (Deployment). A `_port: 8001` holder is defined in each document,
making the "same port" constraint explicit and in one place.

### No shared bases

The two Services are structurally similar (same fields, different name and port), but a shared
`service-base.yaml++` would save only ~2 lines — below the ~5-line abstraction threshold. The
two Deployments use different probe types (exec vs HTTP) and different container configurations,
so no structural sharing was applicable.

### Line count trade-off

The refactored sources are slightly larger (+6 lines, +9% words) than the generated baseline
because `eval:string:refexpr("._app")` (37 characters) is considerably longer than the literal
values it replaces (`"liveness"`, `"liveness-http"`). The primary benefit of this refactoring is
not line reduction but single-point-of-change: renaming the app or changing the port requires
editing one line per document instead of making multiple scattered changes.

### Limitations

- The 14-line Apache license header in `liveness-command.yaml` is stripped by the jq++ → yq
  round-trip. The generated output is semantically equivalent but loses the license comment.
