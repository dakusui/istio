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
      *.yaml++
      *.json++
      generate.sh             ← produces .generated/ from these sources
      REFACTORING_REPORT.md   ← metrics, verification, findings
    .generated/               ← output of generate.sh; mirrors original file layout
      *.yaml
      *.json
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
Each `---`-document gets its own `.yaml++` file. Name clearly:
- `{sample}-service.yaml++`
- `{sample}-deployment-v1.yaml++`

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

### 4. Create generate.sh

Place `generate.sh` in `samples/{sample-name}/.refactored/` and **make it executable with `chmod +x generate.sh`** — this step is required, not optional.

```bash
#!/usr/bin/env bash
# generate.sh — regenerate ../.generated/ from jq++ sources in this directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../.generated"
mkdir -p "${OUT_DIR}"

# ---- single-document YAML example ----
jq++ "${SCRIPT_DIR}/resource.yaml++" | yq -y '.' > "${OUT_DIR}/resource.yaml"

# ---- multi-document YAML example (concatenate with ---) ----
{
  jq++ "${SCRIPT_DIR}/foo-service.yaml++"       | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/foo-deployment-v1.yaml++" | yq -y '.'
  printf -- "---\n"
  jq++ "${SCRIPT_DIR}/foo-deployment-v2.yaml++" | yq -y '.'
} > "${OUT_DIR}/foo.yaml"

# ---- JSON example ----
jq++ "${SCRIPT_DIR}/config.json++" | jq . > "${OUT_DIR}/config.json"

echo "Generated: ${OUT_DIR}"
```

Fill in the actual files matching the original sample's structure. Preserve original filenames and directory layout under `.generated/`.

### 5. Run and verify

```bash
bash samples/{sample-name}/.refactored/generate.sh
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

| | Original | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | N | N | N | −N (−X%) |
| Words | N | N | N | −N (−X%) |

Count only `.yaml`/`.json` originals vs `.yaml++`/`.json++` refactored sources (exclude `generate.sh` from the word/line counts). Use `wc -lw` for counts. The "of which: shared" column counts only files under `.refactored/shared/`.

**Verification:** PASS or FAIL with details of any remaining diffs.

**Findings (prose):** Describe what patterns were found and how jq++ addressed them. Include specific numbers where interesting (e.g., "Both Deployments were identical except for 3 fields — the version label, selector, and image tag — reducing 35 repetitive lines to a 6-line base and two 10-line variants"). Note any limitations (stripped comments, array merge behavior, etc.).
