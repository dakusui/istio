# Refactoring Report: cicd

## Metrics

| | Generated (baseline) | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 143 | 145 | 8 | +2 (+1.4%) |
| Words | 256 | 248 | 16 | −8 (−3.1%) |
| DuplicationRatio | 0.0% | 0.0% | — | 0.0 pp |

Baseline is `.generated/skaffold/skaffold.yaml`. The original `skaffold/skaffold.yaml` has 146 lines including a header comment block and several inline comments that are stripped by the jq++ → yq round-trip.

## Verification

**PASS** — 1/1 files match.

## Findings

### Structure

The cicd sample is a single multi-document YAML file (`skaffold/skaffold.yaml`) with 6 Skaffold `Config` documents. Three shared base files are extracted under `.refactored/shared/`:

- **`config-base.yaml++`** (2 lines) — `apiVersion: skaffold/v2beta22` + `kind: Config`, shared by all 6 documents.
- **`profile-run-base.yaml++`** (3 lines) — `name: run` + `activation: [{command: run}]`, shared by the 3 Helm-deploy configs (istio-base, istiod, ingress) as the `run` profile header.
- **`profiles-dev-base.yaml++`** (3 lines) — `name: dev` + `activation: [{command: dev}]`, shared similarly for the `dev` profile header.

### Limitations

Savings are minimal (+2 lines overall) because the primary repetition — the `deploy.helm.releases` block within each profile — cannot be abstracted. jq++ shallow-replaces arrays, so a child document that `$extends` a profile cannot inherit and patch only the chart name; the entire `deploy` section must be restated per variant. The `$extends` inside array items captures only the name/activation header (3 lines per profile), while the deploy body is still fully spelled out.

Cross-document scalar repetition (`namespace: istio-system`, the Helm repo URL) also cannot be shared, since jq++ processes each `---`-separated document independently.

Two documents (`istiod`, `bookinfo`) originally used `shared/config-base.yaml++` (with an explicit `shared/` prefix) rather than the bare `config-base.yaml++`. Because `yq++` mirrors only the immediate source directory into its temp workspace, the prefixed path was unresolvable and those two documents silently dropped from the generated output. Corrected to the bare filename, which `jq++` finds via `JF_PATH`.

### Primary value

The sample now participates in the `yjoin`/`yq++` pipeline with a clean shared-base structure. A future change to `apiVersion`, or to the run/dev profile activation logic, is made in one place rather than across every document.
