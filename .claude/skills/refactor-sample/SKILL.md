---
name: refactor-sample
description: Refactor a sample under the samples/ directory using jq++ and yq to eliminate repetition, producing a DRY, maintainable version. Use this skill whenever the user asks to refactor, DRY up, or reduce duplication in a sample, mentions jq++ or YAML/JSON templating for a sample, or wants to create a generate.sh for a sample. Trigger on phrases like "refactor samples/X", "refactor the X sample", "DRY up this sample", "create a jq++ version of", "reduce duplication in samples", or "generate.sh for a sample".
---

# Refactor Sample Skill

Refactor a single sample under `samples/` using jq++ to eliminate repetition across YAML and JSON files.

## Prerequisites

These tools must be available on PATH — verify before starting:

- **`jq++`** — JSON++/YAML++ elaboration engine ([dakusui/jqplusplus](https://github.com/dakusui/jqplusplus))
- **`yq`** — YAML/JSON converter (for YAML output and semantic diffing)
- **`jq`** — for JSON output formatting

```bash
jq++ --version && yq --version && jq --version
```

If any are missing, stop and tell the user.

## Skill Utilities

Three scripts are provided under `.claude/skills/refactor-sample/bin/` and should be invoked with their full path (or add the directory to PATH):

### `ystrip [FILE ...]`

Removes all object keys beginning with `_` from YAML input, recursively at any depth. Reads from stdin when no files are given; handles multi-document YAML.

```bash
cat elaborated.yaml | "${SKILL_BIN}/ystrip"
"${SKILL_BIN}/ystrip" file.yaml
```

Useful for stripping private/internal annotations (e.g., `_comment`, `_internal`) added during authoring before feeding output to downstream tools.

### `yjoin [--out-dir OUT_DIR] [SRC_DIR]`

Concatenates `{stem}@{id}.yaml[++]` part-files in `SRC_DIR` into `{stem}.yaml` in `OUT_DIR`.

- Files named `{stem}@{id}.yaml++` are rendered via `jq++ | yq -y '.'`
- Files named `{stem}@{id}.yaml` are rendered via `yq -y '.'`
- Files named `{name}.yaml++` (no `@`) are treated as single-doc passthrough
- Files within each stem group are sorted lexicographically by identifier — use numeric prefixes (`01-`, `02-`, …) to control document order

Typical invocation from `.refactored/`:
```bash
SKILL_BIN="$(git rev-parse --show-toplevel)/.claude/skills/refactor-sample/bin"
"${SKILL_BIN}/yjoin" --out-dir ../.generated .
```

### `ysplit [--out-dir OUT_DIR] FILE [FILE ...]`

Splits a multi-document `.yaml` file into `{stem}@{NN}.yaml` parts (two-digit sequence, e.g. `@01`, `@02`). Each document is re-formatted through `yq -y '.'`. Output files go next to the input by default.

```bash
"${SKILL_BIN}/ysplit" --out-dir .refactored/ samples/foo/foo.yaml
```

These tools replace hand-written `generate.sh` assembly blocks. Use `yjoin` wherever a `generate.sh` would previously concatenate files.

## Key jq++ Concepts

jq++ elaborates `.yaml++` / `.json++` files into plain YAML/JSON. All directives are valid YAML/JSON — existing tooling still works on source files unchanged.

| Directive | Purpose |
|---|---|
| `$extends: [file]` | Inherit fields from parent files. Current object wins; first listed parent wins over later ones. Deep-merges objects, shallow-replaces arrays. |
| `$local: {Name: {...}}` | Define named local objects for in-file reuse (stripped from output). |
| `eval:string:refexpr(".field")` | Reference another field's value (chained: follows further eval: references). |
| `eval:<type>:<jq expr>` | Compute a value with jq. Types: `string`, `number`, `bool`, `array`, `object`. |
| `raw:key` | Emit a key literally, bypassing all directive processing. |

Run: `jq++ file.yaml++` → plain JSON on stdout. Pipe to `yq -y '.'` for YAML output.

Path resolution: jq++ resolves `$extends` paths relative to the source file's directory, then checks `JF_PATH`. Use relative paths for self-contained samples.

**Note on `yq` flavors:** The `yq` on this system is the `kislyuk/yq` wrapper (a jq wrapper for YAML). Its YAML output flag is `-y '.'`, not `-P`. Always use `yq -y '.'` (never `yq -P`).

## Directory Layout

Everything lives inside the sample directory — no centralized folders:

```
samples/
  {sample-name}/              ← originals — DO NOT MODIFY
    *.yaml
    *.json
    .refactored/              ← refactored jq++ source files
      shared/                 ← base files reused within this sample
        *.yaml++
        *.json++
      {stem}@{NN}-{id}.yaml++ ← part-files (grouped by stem, ordered by NN)
      {name}.yaml++           ← single-doc passthrough (no @)
      *.json++
      REFACTORING_REPORT.md   ← metrics, verification, findings
    .generated/               ← output of yjoin; mirrors original file layout
      *.yaml
      *.json
```

### File-naming convention for part-files

Multi-document YAML files are split into individual part-files using the `@` separator:

```
{stem}@{NN}-{description}.yaml++
```

- **`stem`** — base name of the output file (may contain hyphens, e.g. `httpbin-gateway`)
- **`@`** — unambiguous separator between stem and identifier
- **`NN`** — zero-padded sequence number controlling concatenation order (`01`, `02`, …)
- **`description`** — human-readable label (e.g. `serviceaccount`, `service`, `deployment-v1`)

Examples:
```
httpbin@01-serviceaccount.yaml++   →  httpbin.yaml  (doc 1)
httpbin@02-service.yaml++          →  httpbin.yaml  (doc 2)
httpbin@03-deployment.yaml++       →  httpbin.yaml  (doc 3)
httpbin-gateway@01-gateway.yaml++  →  httpbin-gateway.yaml  (doc 1)
httpbin-gateway@02-vs.yaml++       →  httpbin-gateway.yaml  (doc 2)
```

## Step-by-Step Workflow

### 1. Analyze the original sample

Read all `.yaml` and `.json` files in `samples/{sample-name}/` recursively. For each file:

- Record the Kubernetes `kind`, `apiVersion`, and key metadata
- Identify repeated field groups (labels, selectors, resource requests, image prefixes, etc.)
- Note multi-document YAML files (`---` separators) — each document becomes its own `.yaml++` file
- Identify parametric variants (e.g., same Deployment shape for v1/v2/v3)

### 2. Design the refactored structure

Decide what to extract:

- **Repeated structure across documents in the same sample** → shared base in `.refactored/shared/`
- **Parametric variants** (same structure, different values) → base file + per-variant extends
- **Derived values** (e.g., name built from app + version) → `eval:string:refexpr(...)` within the file

A useful heuristic: if removing a repetition saves fewer than ~5 lines total, it's probably not worth the abstraction.

### 3. Create the jq++ source files

**Splitting multi-document YAML files:**
Each `---`-document gets its own `.yaml++` file using the `@` naming convention.
Use `ysplit` to generate the initial split, then rename/refactor as needed:

```bash
SKILL_BIN="$(git rev-parse --show-toplevel)/.claude/skills/refactor-sample/bin"
"${SKILL_BIN}/ysplit" --out-dir .refactored/ samples/{sample-name}/file.yaml
# produces: .refactored/file@01.yaml  .refactored/file@02.yaml  …
# rename to add descriptions: file@01-serviceaccount.yaml++ etc.
```

Name part-files clearly with a numeric prefix and description:
- `{sample}@01-serviceaccount.yaml++`
- `{sample}@02-service.yaml++`
- `{sample}@03-deployment-v1.yaml++`

**Shared base files** (in `.refactored/shared/`):
Provide the common structure. Only include fields that truly appear in all variants — do not add empty `{}` or `[]` placeholders for fields that some variants omit, as they will be inherited even when unwanted.

```yaml
# .refactored/shared/deployment-base.yaml++
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: 1
  selector:
    matchLabels: {}
  template:
    spec:
      containers: []
```

Path from a top-level `.refactored/` file to a shared base: `shared/base.yaml++`
Path from a subdirectory `.refactored/gateway-api/` file to a shared base: `../shared/base.yaml++`

**Variant files** using `$extends`:
```yaml
# .refactored/helloworld-deployment-v1.yaml++
$extends:
  - shared/deployment-base.yaml++
metadata:
  name: helloworld-v1
  labels:
    app: helloworld
    version: v1
spec:
  selector:
    matchLabels:
      app: helloworld
      version: v1
  template:
    metadata:
      labels:
        app: helloworld
        version: v1
    spec:
      containers:
        - name: helloworld
          image: registry.istio.io/release/examples-helloworld-v1:1.0
          resources:
            requests:
              cpu: "100m"
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 5000
```

**In-file deduplication** using `$local` and `eval:`:
```yaml
# When version appears in many places within one file
$local:
  DeploymentBase:
    apiVersion: apps/v1
    kind: Deployment
    spec:
      replicas: 1

helloworld-v1:
  $extends:
    - DeploymentBase
  metadata:
    name: helloworld-v1
```

Or use `eval:` to derive repeated values:
```yaml
appName: helloworld
version: v1
metadata:
  name: "eval:string:refexpr(\".appName\") + \"-\" + refexpr(\".version\")"
  labels:
    app: "eval:string:refexpr(\".appName\")"
    version: "eval:string:refexpr(\".version\")"
```

**Important caveat — array merging:** jq++ deep-merges objects but shallow-replaces arrays. A child's `containers: [...]` fully replaces the base's `containers: []`. Design base arrays accordingly (usually empty `[]` as placeholder).

**Comments:** YAML comments are stripped during jq++ → yq round-trip. If the original has significant comments, note this in the report.

### 4. Generate output with yjoin

No hand-written `generate.sh` is needed. Run `yjoin` from `.refactored/` to produce `.generated/`:

```bash
SKILL_BIN="$(git rev-parse --show-toplevel)/.claude/skills/refactor-sample/bin"
"${SKILL_BIN}/yjoin" \
  --out-dir "samples/{sample-name}/.generated" \
  "samples/{sample-name}/.refactored"
```

For samples with subdirectories (e.g. `gateway-api/`, `platform/kube/`), run `yjoin` once per subdirectory with the appropriate `--out-dir`:

```bash
"${SKILL_BIN}/yjoin" \
  --out-dir "samples/{sample-name}/.generated/gateway-api" \
  "samples/{sample-name}/.refactored/gateway-api"
```

JSON files (`.json++`) still require explicit processing — `yjoin` handles `.yaml[++]` only:
```bash
jq++ "samples/{sample-name}/.refactored/config.json++" | jq . \
  > "samples/{sample-name}/.generated/config.json"
```

### 5. Run and verify

```bash
SKILL_BIN="$(git rev-parse --show-toplevel)/.claude/skills/refactor-sample/bin"
"${SKILL_BIN}/yjoin" \
  --out-dir "samples/{sample-name}/.generated" \
  "samples/{sample-name}/.refactored"
```

Verify semantic equivalence (YAML formatting differences are not errors):

```bash
# For each YAML file pair (kislyuk/yq: use -S flag to sort keys via jq):
diff \
  <(yq -S '.' samples/{sample-name}/file.yaml | grep -v '^null$') \
  <(yq -S '.' samples/{sample-name}/.generated/file.yaml | grep -v '^null$')

# For JSON:
diff \
  <(jq -S . samples/{sample-name}/file.json) \
  <(jq -S . samples/{sample-name}/.generated/file.json)
```

If diffs exist, investigate whether they are:
- Purely cosmetic (key ordering, trailing newlines) → acceptable, note in report
- Structural differences → fix the jq++ sources before reporting

### 6. Produce the report

Write the report to `samples/{sample-name}/.refactored/REFACTORING_REPORT.md`.

**Metrics table:**

| | Generated (baseline) | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | N | N | N | −N (−X%) |
| Words | N | N | N | −N (−X%) |

Use `.generated/` files as the baseline, not the originals. The originals may contain comments that are stripped during the jq++ → yq round-trip, which would make the refactored sources look better than they actually are. The generated files represent what the refactored sources produce after elaboration, so comparing against them gives a fair measure of how much the jq++ sources reduce repetition.

Count `.yaml`/`.json` files under `.generated/` vs `.yaml++`/`.json++` files under `.refactored/` (exclude `generate.sh`). Use `wc -lw` for counts. The "of which: shared" column counts only files under `.refactored/shared/`.

**Verification:** PASS or FAIL with details of any remaining diffs.

**Findings (prose):** Describe what patterns were found and how jq++ addressed them. Include specific numbers where interesting (e.g., "Both Deployments were identical except for 3 fields — the version label, selector, and image tag — reducing 35 repetitive lines to a 6-line base and two 10-line variants"). Note any limitations (stripped comments, array merge behavior, etc.).
