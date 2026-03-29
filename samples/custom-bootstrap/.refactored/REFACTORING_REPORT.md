# Refactoring Report — custom-bootstrap

## Metrics

| | Original | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 50 | 58 | 9 | +8 (+16%) |
| Words | 83 | 94 | 14 | +11 (+13%) |

*Counts include all `.yaml` / `.json` originals vs all `.yaml++` / `.json++` refactored sources. `generate.sh` excluded.*

## Verification

**PASS** — semantic diff (`yq -S '.'`) of both output files against originals shows no differences.

## Findings

The custom-bootstrap sample consists of two files:

- **`custom-bootstrap.yaml`** — a ConfigMap holding a partial Envoy bootstrap JSON string. No internal repetition exists; it is transcribed unchanged to `custom-bootstrap.yaml++`.
- **`example-app.yaml`** — a single Deployment for `helloworld-v1`. The labels `app: helloworld` and `version: v1` appear three times each (in `metadata.labels`, `spec.selector.matchLabels`, and `spec.template.metadata.labels`), following the standard Kubernetes label/selector pattern.

**Why the line count increases:** The shared `deployment-base.yaml++` (9 lines) is a new artifact that the variant file extends. When there is only one variant, this base file is pure overhead — the savings only materialize when a second variant (e.g., a future `helloworld-v2` deployment) also extends it, at which point each new variant costs ~10 lines instead of ~30.

**Label repetition within `example-app.yaml++`:** The three occurrences of `app: helloworld` / `version: v1` are not eliminated in this refactoring. Fully deduplicating them would require either:
- A second shared YAML++ file providing the three label blocks (and deep-merge would fill them in), or
- jq++ `$local` / `eval:refexpr` expressions to derive the label values from a single source — viable but adds syntax complexity for a two-value pair that is unlikely to change independently across the three positions.

Given the sample's small size and single-variant nature, the `$extends` from `deployment-base.yaml++` establishes the structural pattern (consistent with other refactored samples in this repo) without introducing unnecessary complexity.
