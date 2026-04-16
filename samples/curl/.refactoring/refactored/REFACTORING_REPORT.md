# Refactoring Report: curl

## Metrics

| | Generated (baseline) | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 50 | 48 | — | −2 (−4%) |
| Words | 83 | 81 | — | −2 (−2%) |
| DuplicationRatio | 0.0% | 0.0% | — | 0.0 pp |

## Verification

**PASS** — 1/1 files match.

## Findings

The curl sample is a single two-document YAML file (`curl.yaml`) containing one
ServiceAccount and one Deployment. There is no cross-file or cross-document
structural repetition, so no shared bases were introduced.

The refactoring is limited to cosmetic reformatting of the source:

- The `containers` array uses inline `command: ["/bin/sleep", "infinity"]` (1 line)
  instead of the block-sequence form (2 lines), accounting for the 2-line reduction.
- Key ordering within objects was normalised (e.g., `metadata.name` hoisted,
  `secretName` before `optional` in the volume spec).

These changes produce semantically identical output — `verify.sh` confirms a
clean match — while making the source slightly more compact.
