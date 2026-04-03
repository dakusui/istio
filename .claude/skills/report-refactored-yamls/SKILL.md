---
name: report-refactored-yamls
description: Write a REFACTORING_REPORT.md for any directory refactored by the refactor-yamls skill. Use this skill whenever the user asks to write the report, produce REFACTORING_REPORT.md, document the refactoring results, or summarize the metrics for a refactored directory. Trigger on phrases like "write the report for X", "produce the refactoring report", "document the refactoring", or "REFACTORING_REPORT".
---

# Report Refactored YAMLs Skill

Write `{TARGET_DIR}/.refactoring/refactored/REFACTORING_REPORT.md` summarizing the outcome of a jq++ refactoring produced by the `refactor-yamls` skill.

## Arguments

- **TARGET_DIR** — the directory that was refactored (e.g. `infra/k8s/staging`, `samples/helloworld`)

## What you need before writing

- `{TARGET_DIR}/.refactoring/generated/` populated (run `generate.sh` if not yet done)
- `{TARGET_DIR}/.refactoring/refactored/` populated with `.yaml++` / `.json++` sources

## Metrics

Collect line and word counts with `wc -lw`, then fill in the table:

```bash
# Generated baseline
find {TARGET_DIR}/.refactoring/generated -name "*.yaml" -o -name "*.json" | sort | xargs wc -lw

# Refactored sources (exclude generate.sh and verify.sh)
find {TARGET_DIR}/.refactoring/refactored -name "*.yaml++" -o -name "*.json++" | sort | xargs wc -lw

# Shared subset only
find {TARGET_DIR}/.refactoring/refactored/shared -name "*.yaml++" -o -name "*.json++" 2>/dev/null | sort | xargs wc -lw
```

Use `.generated/` as the baseline — not the originals. The originals may contain comments that are stripped during the jq++ → yq round-trip, which would inflate the apparent savings. The generated files represent what the refactored sources actually produce.

## Verification status

Run `verify.sh` and record the result:

```bash
{TARGET_DIR}/.refactoring/refactored/verify.sh
```

Report PASS or FAIL. On FAIL, list the files that differ.

## Report structure

```markdown
# Refactoring Report: {TARGET_DIR}

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

ARGUMENTS: {args}
