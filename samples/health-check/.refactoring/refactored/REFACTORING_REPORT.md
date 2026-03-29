# Refactoring Report: health-check

## Metrics

| | Generated (baseline) | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 81 | 84 | 25 | +3 (+4%) |
| Words | 133 | 135 | 38 | +2 (+2%) |

## Verification

**PASS** — 2/2 files match.

## Findings

The health-check sample contains two files — `liveness-command.yaml` and
`liveness-http-same-port.yaml` — each with a Service + Deployment pair for a
liveness-probe demonstration app. The files are small (40–41 lines generated)
and structurally similar at the outer level, but their container definitions
differ entirely: one uses an exec probe against a busybox shell command, the
other uses an HTTP probe against a versioned health endpoint.

### What was extracted

**`shared/service-base.yaml++`** — captures the common Service skeleton:
`apiVersion`, `kind`, `metadata.name/labels.app/labels.service` (all derived
from `_app`), and `spec.selector.app`. Each file overrides only `spec.ports`
with its concrete port entry. This removes 8 lines of structural repetition
per Service document.

**`shared/deployment-base.yaml++`** — captures the outer Deployment shell:
`apiVersion`, `kind`, `metadata.name`, `spec.selector.matchLabels.app`, and
`spec.template.metadata.labels.app`, all derived from `_app`. Each file then
provides the full `containers` array.

A single `_app` value now drives `metadata.name`, `labels.app`, `labels.service`,
and `spec.selector.app` consistently across all four documents without repetition
of the literal app name.

### Why the line count increases slightly

The `eval:string:refexpr(\"._app\")` expressions in the shared bases are longer
than the literal values they replace. With only two output files, the overhead
of the shared bases outweighs the savings in the per-file sources — the
refactored total is 3 lines larger than the generated baseline.

The value here is **naming clarity**, not size reduction: the bases make explicit
that both Services and both Deployments follow the same parametric structure
driven by `_app`, and that any structural divergence (the `version: v1` label
and the different probe types in `liveness-http`) is intentional and local to
that variant.

### Array merge constraint

`livenessProbe.initialDelaySeconds: 5` and `periodSeconds: 5` appear in both
container definitions but cannot be shared: the `containers` array is
shallow-replaced by the child, so the base cannot contribute individual
container fields. Both values are repeated in each variant file.

### `liveness-http` version label

`liveness-http-same-port` carries `version: v1` in both `spec.selector.matchLabels`
and `spec.template.metadata.labels`. Because jq++ deep-merges objects, the child
only needs to supply the `version` key in each location — the `app` key is
inherited from `deployment-base` transparently.
