# Refactoring Report: cicd

## Metrics

| | Generated (baseline) | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 143 | 145 | 2 | +2 (+1%) |
| Words | 256 | 254 | 4 | −2 (−1%) |

Baseline is `.generated/skaffold/skaffold.yaml`. The original `skaffold/skaffold.yaml` has 146 lines including a header comment block (14 lines) and several inline comments that are stripped by the jq++ → yq round-trip.

## Verification

**PASS** — generated file is semantically equivalent to the original (zero diff after `yq -S '.'` normalization):

- `skaffold/skaffold.yaml` ✓

## Findings

### Limited jq++ applicability

The cicd sample contains a single multi-document YAML file (`skaffold/skaffold.yaml`) with 6 Skaffold `Config` documents. All 6 share `apiVersion: skaffold/v2beta22` and `kind: Config`, and those are extracted into `shared/config-base.yaml++` and consumed via `$extends` in each document.

However, the metrics show no meaningful line savings (+2 lines, −2 words). This is because replacing 2 lines (`apiVersion` + `kind`) with 2 lines (`$extends` block) is a wash at the document level, and the shared file itself adds 2 more lines.

The larger repetition across the three Istio helm-based configs (istio-base, istiod, ingress) — each having an identical dev/run profile pair structure differing only in chart name/path — cannot be abstracted via jq++. The `profiles` field is an array, and jq++ shallow-replaces arrays: a child document cannot inherit a profile array and override just the chart name inside a nested release entry. Each config must define its full `profiles` array independently.

Similarly, repeated scalar values (`namespace: istio-system`, `repo: https://istio-release.storage.googleapis.com/charts`) appear across separate documents. Since `jq++` processes each `---`-separated document independently, cross-document value sharing is not available.

### Primary value of this refactoring

The main benefit is structural: the sample now participates in the `yjoin`/`yq++` pipeline, and the single-file multi-document `skaffold.yaml++` authoring pattern is validated end-to-end. If `apiVersion` changes in a future Skaffold version, it is updated in one place (`shared/config-base.yaml++`) rather than six.

### Limitations

- Inline comments (the 14-line header block and per-section comments) are stripped by the jq++ → yq round-trip. The generated file is semantically equivalent but loses documentation value.
- Array-merge constraints prevent sharing the dev/run profile structure across the three Istio configs — the most significant repetition in the file.
