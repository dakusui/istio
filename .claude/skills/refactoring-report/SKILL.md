---
name: refactoring-report
description: Write a REFACTORING_REPORT.md for a refactored sample under samples/. Use this skill whenever the user asks to write the report, produce REFACTORING_REPORT.md, document the refactoring results, or summarize the metrics for a refactored sample. Trigger on phrases like "write the report for samples/X", "produce the refactoring report", "document the refactoring", or "REFACTORING_REPORT".
---

# Refactoring Report Skill

Write `samples/{sample-name}/.refactored/REFACTORING_REPORT.md` summarizing the outcome of a jq++ refactoring.

## What you need before writing

- The sample name (e.g. `helloworld`, `cicd`)
- `.generated/` populated (run `generate.sh` if not yet done)
- `.refactored/` populated with `.yaml++` / `.json++` sources

## Metrics

Collect line and word counts with `wc -lw`, then fill in the table:

```bash
# Generated baseline
find samples/{sample-name}/.generated -name "*.yaml" -o -name "*.json" | sort | xargs wc -lw

# Refactored sources (exclude generate.sh and verify.sh)
find samples/{sample-name}/.refactored -name "*.yaml++" -o -name "*.json++" | sort | xargs wc -lw

# Shared subset only
find samples/{sample-name}/.refactored/shared -name "*.yaml++" -o -name "*.json++" 2>/dev/null | sort | xargs wc -lw
```

Use `.generated/` as the baseline — not the originals. The originals may contain comments that are stripped during the jq++ → yq round-trip, which would inflate the apparent savings. The generated files represent what the refactored sources actually produce.

## Verification status

Run `verify.sh` and record the result:

```bash
samples/{sample-name}/.refactored/verify.sh
```

Report PASS or FAIL. On FAIL, list the files that differ.

## Report structure

```markdown
# Refactoring Report: {sample-name}

## Metrics

| | Generated (baseline) | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | N | N | N | −N (−X%) |
| Words | N | N | N | −N (−X%) |

## Verification

PASS / FAIL — N/N files match.

## Findings

[Prose: what patterns were found and how jq++ addressed them.]
```

## Findings guidance

Describe what patterns were found and how jq++ addressed them. Include specific numbers where interesting — for example: "Both Deployments were identical except for 3 fields (version label, selector, image tag), reducing 35 repetitive lines to a 6-line base and two 10-line variants." Note any limitations encountered, such as stripped comments or array merge constraints.
