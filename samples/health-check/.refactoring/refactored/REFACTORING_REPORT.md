# Refactoring Report: health-check

## Metrics

| | Generated (baseline) | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 81 | 79 | 13 | −2 (−2%) |
| Words | 133 | 131 | 22 | −2 (−2%) |

## Verification

**PASS** — 2/2 files match.

## Findings

The health-check sample is small — two files, four documents total — with limited structural
overlap. Both files contain one Service and one Deployment. The Deployment documents are entirely
different (different probes, different images, different container arguments), so no shared
Deployment base is viable. The two Services follow an identical structural pattern and are
extracted into `shared/service-base.yaml++`.

### Service base

Both Services share the same structure: `apiVersion v1`, `kind Service`, `metadata.name` matching
the app label, `labels.app` and `labels.service` both equal to the app name, a single HTTP port,
and `selector.app`. They differ only in app name (`liveness` vs `liveness-http`) and port number
(`80` vs `8001`).

`shared/service-base.yaml++` captures this pattern with `_app` and `_port` private holders. Each
service document is now 4 lines:

```yaml
$extends:
  - service-base.yaml++
_app: liveness
_port: 80
```

This replaces the 14-line and 15-line inline service documents (which repeated `eval:` expressions
for every occurrence of the app name) with a single 13-line base and two 4-line extend stubs.

### `_app` and `_port` private holders in Deployment documents

The Deployment documents retain standalone inline form — no `$extends` — because their container
definitions are completely different and share no extractable structure. Each document defines
`_app` (and `_port` where a port appears) at the document top, then references it via
`eval:string:refexpr("._app")` and `eval:number:refexpr("._port")` throughout, eliminating the
repeated literal app name from `metadata.name`, `spec.selector.matchLabels.app`,
`spec.template.metadata.labels.app`, and `containers[0].name`.

### Limits of structural sharing

- `liveness-command` Deployment has `spec.selector.matchLabels: {app: liveness}` only; `liveness-http`
  adds `version: v1` in both selector and template labels. This asymmetry prevents a shared
  Deployment base even if the container sections were abstractable.
- The two probes are entirely different structures (exec command vs HTTP GET), so no probe base is
  applicable.

### Limitations

- YAML comments from the originals (Apache license header, section banners) are stripped during the
  jq++ → yq round-trip.
- The sample is small enough that absolute line savings are modest; the primary value is eliminating
  the repeated literal app name within each document and making the two Services obviously
  structurally identical.
