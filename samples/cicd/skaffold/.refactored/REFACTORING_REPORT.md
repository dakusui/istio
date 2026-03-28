# Refactoring Report: samples/cicd/skaffold

## Metrics

| | Original | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 145 | 129 | 2 | −16 (−11%) |
| Words | 326 | 238 | 4 | −88 (−27%) |

Counts cover `skaffold.yaml` (original) vs all `.yaml++` files (refactored). `generate.sh` excluded.

## Verification

**PASS** — `diff <(yq -S '.' skaffold.yaml | grep -v '^null$') <(yq -S '.' .generated/skaffold.yaml | grep -v '^null$')` produces no output.

## Findings

### What was refactored

The original `skaffold.yaml` contains 6 YAML documents (separated by `---`), each defining a `skaffold/v2beta22 Config`. Splitting them into individual `.yaml++` files enables a shared base:

**`shared/config-base.yaml++`** holds the two fields common to all six documents:
```yaml
apiVersion: skaffold/v2beta22
kind: Config
```
Each document file uses `$extends: [shared/config-base.yaml++]` (1 line) instead of repeating both fields (2 lines). This saves 1 line per document × 6 = 6 lines, offset by the 2-line shared file — a net −4 lines in pure count terms, but more importantly a single authoritative definition of the API version.

**Document splitting** itself accounts for the larger word-count reduction. The original file carries 14 lines of block comments at the top describing installation options — these are informal documentation and were not carried into the split source files (they belong in the `README.md` which already exists).

### Why deeper deduplication is limited here

The three Helm-based configs (`istio-base`, `istiod`, `ingress`) share a near-identical `profiles` structure:
- `dev` profile: `activation: [{command: dev}]` + a local `chartPath` release
- `run` profile: `activation: [{command: run}]` + a `remoteChart` + `repo: https://istio-release.storage.googleapis.com/charts` + `namespace: istio-system` release

**Array merge limitation:** jq++ deep-merges objects but shallow-replaces arrays. Since `profiles` is a top-level array, a child extending a base with `profiles: [dev, run]` would need to re-declare the entire array to add `releases`, defeating the purpose. There is no per-element merge for arrays in jq++.

`namespace: istio-system` (7 occurrences) and `repo: https://istio-release.storage.googleapis.com/charts` (3 occurrences) sit inside array elements, so they cannot be shared via `$extends`. They could be referenced with `eval:string:refexpr(...)` if defined as document-level fields, but those fields would then appear in the generated output, breaking semantic equivalence.

### Summary

This file is a good example of the limits of jq++ for skaffold-style configs: the primary structure (profiles as arrays with variant releases) resists deep-merge inheritance. The tangible gain is a canonical `apiVersion`/`kind` definition and a clean per-document split that makes individual configs easier to read, modify, and diff in isolation.
