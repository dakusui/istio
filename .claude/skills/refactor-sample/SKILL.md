---
name: refactor-sample
description: Refactor a sample under the samples/ directory using jq++ and yq to eliminate repetition, producing a DRY, maintainable version. Use this skill whenever the user asks to refactor, DRY up, or reduce duplication in a sample, mentions jq++ or YAML/JSON templating for a sample, or wants to create a generate.sh for a sample. Trigger on phrases like "refactor samples/X", "refactor the X sample", "DRY up this sample", "create a jq++ version of", "reduce duplication in samples", or "generate.sh for a sample". Do NOT produce a REFACTORING_REPORT.md unless the user explicitly asks for a report (in which case use refactor-and-report-sample instead).
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

### `yq++ FILE`

Elaborates a single `.yaml[++]` file to stdout. Internally splits the file on `---` boundaries, processes each document through `jq++` (for `.yaml++`) or `yq` (for `.yaml`), and concatenates the results. Relative `$extends` paths resolve correctly because the input file's directory is mirrored into the temp workspace via symlinks.

```bash
"${SKILL_BIN}/yq++" samples/foo/.refactored/foo.yaml++
"${SKILL_BIN}/yq++" samples/foo/.refactored/foo.yaml++ > /tmp/foo-elaborated.yaml
```

Useful for quickly inspecting what a `.yaml++` file produces without running the full `yjoin` pipeline.

### `ystrip [FILE ...]`

Removes all object keys beginning with `_` from YAML input, recursively at any depth. Reads from stdin when no files are given; handles multi-document YAML.

```bash
cat elaborated.yaml | "${SKILL_BIN}/ystrip"
"${SKILL_BIN}/ystrip" file.yaml
```

Useful for stripping private/internal annotations (e.g., `_comment`, `_internal`) added during authoring before feeding output to downstream tools.

### `yjoin [--out-dir OUT_DIR] [SRC_DIR]`

Batch-assembles all source files in `SRC_DIR` into `.yaml` files in `OUT_DIR`.

- Files named `{name}.yaml++` (no `@`) are elaborated via `yq++` — this is the primary pattern; multi-document files with `---` separators are handled correctly, with `$extends` working per-document
- Files named `{stem}@{id}.yaml++` are rendered via `jq++ | yq -y '.'` and grouped by stem — retained for backward compatibility
- Files named `{stem}@{id}.yaml` are rendered via `yq -y '.'` and grouped by stem

Typical invocation:
```bash
SKILL_BIN="$(git rev-parse --show-toplevel)/.claude/skills/refactor-sample/bin"
"${SKILL_BIN}/yjoin" --out-dir "samples/{sample-name}/.generated" "samples/{sample-name}/.refactored"
```

### `ysplit [--out-dir OUT_DIR] FILE [FILE ...]`

Splits a multi-document `.yaml` file into `{stem}@{NN}.yaml` parts. Useful as a migration aid when starting a refactoring from an existing multi-document file — inspect the parts, then combine into a single `.yaml++` with `$extends` added where needed.

```bash
"${SKILL_BIN}/ysplit" --out-dir /tmp/ samples/foo/foo.yaml
```

These tools replace hand-written `generate.sh` assembly blocks.

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

Path resolution: jq++ resolves `$extends` paths relative to the source file's directory, then checks `JF_PATH`. Because `generate.sh` puts the sample's `shared/` directory and `samples/shared/` on `JF_PATH`, shared base files can be referenced by bare filename (e.g., `deployment-base.yaml++`) from any subdirectory — no `../shared/` prefix needed. Always use the bare filename for shared bases; relative paths are only needed for files that are not on `JF_PATH`.

**Note on `yq` flavors:** The `yq` on this system is the `kislyuk/yq` wrapper (a jq wrapper for YAML). Its YAML output flag is `-y '.'`, not `-P`. Always use `yq -y '.'` (never `yq -P`).

## Directory Layout

Everything lives inside the sample directory — no centralized folders:

```
samples/
  {sample-name}/              ← originals — DO NOT MODIFY
    *.yaml
    *.json
    .refactoring/
      refactored/             ← refactored jq++ source files
        generate.sh           ← build sandbox/ from sources (see Step 4)
        verify.sh             ← check sandbox/ vs generated/ (see Step 5)
        shared/               ← base files reused within this sample
          *.yaml++
          *.json++
        {name}.yaml++         ← one file per output YAML; use --- to separate documents
        *.json++
        REFACTORING_REPORT.md ← metrics, verification, findings
      sandbox/                ← working output; default target of generate.sh (not committed)
        *.yaml
        *.json
      generated/              ← committed output baseline; promoted from sandbox when verified
        *.yaml
        *.json
```

### File-naming convention

One `.yaml++` file per output YAML file. Use `---` separators to include multiple documents:

```
{name}.yaml++   →  {name}.yaml   (one or more documents)
```

Examples:
```
httpbin.yaml++         →  httpbin.yaml         (ServiceAccount + Service + Deployment)
httpbin-gateway.yaml++ →  httpbin-gateway.yaml  (Gateway + VirtualService)
```

Each `---`-separated document in a `.yaml++` file is elaborated independently by `yq++`, so `$extends` works correctly per-document.

## Step-by-Step Workflow

### 1. Analyze the original sample

Read all `.yaml` and `.json` files in `samples/{sample-name}/` recursively. For each file:

- Record the Kubernetes `kind`, `apiVersion`, and key metadata
- Identify repeated field groups (labels, selectors, resource requests, image prefixes, etc.)
- Note multi-document YAML files (`---` separators) — the output `.yaml++` will use `---` to separate documents within a single file
- Identify parametric variants (e.g., same Deployment shape for v1/v2/v3)

### 2. Design the refactored structure

Decide what to extract:

- **Repeated structure across documents in the same sample** → shared base in `.refactoring/refactored/shared/`
- **Parametric variants** (same structure, different values) → base file + per-variant extends
- **Derived values** (e.g., name built from app + version) → `eval:string:refexpr(...)` within the file
- **Orthogonal cross-cutting concern** (e.g., a naming convention repeated across documents that already have different structural bases) → separate shared base, added to `$extends` alongside the existing base (multi-base inheritance)
- **Parameter that determines multiple sibling fields** (e.g., a version string that appears as both `name` and `labels.version`) → custom jq function in `shared/*.jq`, called via `eval:object:Namespace::function(arg)`

A useful heuristic: if removing a repetition saves fewer than ~5 lines total, it's probably not worth the abstraction.

### 3. Create the jq++ source files

**One `.yaml++` per output file.** Use `---` to separate documents within it, exactly as in the original YAML. Each document is elaborated independently, so `$extends` works per-document.

Use `ysplit` to generate a quick initial split if you want to inspect documents individually, then fold them back into a single `.yaml++`:

```bash
SKILL_BIN="$(git rev-parse --show-toplevel)/.claude/skills/refactor-sample/bin"
# Optional: inspect individual documents
"${SKILL_BIN}/ysplit" --out-dir /tmp/ samples/{sample-name}/file.yaml
```

**Shared base files** (in `.refactoring/refactored/shared/`):
Provide the common structure. Only include fields that truly appear in all variants — do not add empty `{}` or `[]` placeholders for fields that some variants omit, as they will be inherited even when unwanted.

```yaml
# .refactoring/refactored/shared/deployment-base.yaml++
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

Reference shared bases by bare filename from any depth — JF_PATH handles the lookup:
```yaml
$extends:
  - base.yaml++   # resolves via JF_PATH regardless of subdirectory depth
```

**Variant files** using `$extends`:
```yaml
# .refactoring/refactored/helloworld-deployment-v1.yaml++
$extends:
  - deployment-base.yaml++
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

**Private `_`-prefixed value holders:**
`ystrip` removes all `_`-prefixed keys from the output, so you can define values under `_`-prefixed keys as private anchors and reference them with `eval:`. This is useful when a value is scattered across one document — defining it once in a `_`-prefixed key makes the document structurally uniform without polluting the output.

At the document level, use `refexpr` to reference a top-level `_` holder:

```yaml
# The Helm repo URL appears in both profiles.
# Define it once at the top; reference it from each profile.
_repo: https://istio-release.storage.googleapis.com/charts
profiles:
  - name: dev
    deploy:
      helm:
        releases:
          - remoteChart: istiod
            repo: "eval:string:refexpr(\"._repo\")"
  - name: run
    deploy:
      helm:
        releases:
          - remoteChart: istiod
            repo: "eval:string:refexpr(\"._repo\")"
```

**Revealing structural similarity in nested objects with `reftag`:**
When varying values are embedded inside nested objects (e.g., array items), define `_`-prefixed holders *within* each item and reference them with `reftag(name)`, which searches upward through ancestor objects for the nearest matching key. This often reveals that two items which looked different are actually structurally identical:

```yaml
profiles:
  - _chart: istiod
    _ns: istio-system
    name: run
    activation:
      - command: run
    deploy:
      helm:
        releases:
          - remoteChart: "eval:string:reftag(\"_chart\")"
            namespace: "eval:string:reftag(\"_ns\")"
  - _chart: istio-ingressgateway
    _ns: istio-system
    name: run
    activation:
      - command: run
    deploy:
      helm:
        releases:
          - remoteChart: "eval:string:reftag(\"_chart\")"
            namespace: "eval:string:reftag(\"_ns\")"
```

Both items now have identical non-`_` structure — making them candidates for a shared `$extends` base where only `_chart` and `_ns` are overridden. The `$cur` (current path as array) and `$curexpr` (current path as string, e.g. `.profiles[0]`) built-ins are available when you need to construct sibling paths manually, but `reftag` is usually the simpler choice for this pattern.

See the [jq++ builtins reference](https://dakusui.github.io/jqplusplus/reference/builtins.html) for full documentation on `$cur`, `$curexpr`, `reftag`, `ref`, `refexpr`, and `parent`.

**Multi-base (node-level) inheritance:**
A single document can extend multiple bases when two orthogonal concerns each deserve their own file. List both in `$extends`; the child wins over all parents, and the first-listed parent wins over later ones. This works cleanly when the bases cover non-overlapping keys.

```yaml
# structural base         orthogonal concern (serviceAccountName pattern)
$extends:
  - simple-deployment-base.yaml++
  - bookinfo-svcaccount-base.yaml++
_app: ratings
_version: v1
```

Use this when a cross-cutting concern (e.g., a naming convention, a security context, a label set) repeats across documents that already inherit different structural bases. Extract the concern into its own shared base and add it to `$extends` rather than duplicating it in each variant.

**Custom jq function libraries:**
When a recurring structural pattern can't be expressed as a plain `eval:` reference — typically when a single parameter determines multiple sibling fields — define a custom function in a `.jq` file placed in `shared/` (so it is on `JF_PATH` and accessible by bare filename).

*Defining* — create `shared/functions.jq`:
```jq
def versioned_subset(p): {"name": p, "labels": {"version": p}};
```

*Including* — add the `.jq` file to `$extends` alongside any data bases:
```yaml
$extends:
  - destination-rule-base.yaml++
  - subsets.jq
```

*Calling* — use `Filename::function_name(arg)` inside an `eval:` expression, where the namespace is the `.jq` filename stem:
```yaml
spec:
  subsets:
  - "eval:object:subsets::versioned_subset(\"v1\")"
  - "eval:object:subsets::versioned_subset(\"v2\")"
```

The `eval:object:` type causes jq++ to replace the string with the returned object, so each array element becomes a proper mapping. Use this technique when a pattern has a fixed internal structure but a varying parameter — it removes the duplication of the parameter at every use site.

**Important caveat — array merging:** jq++ deep-merges objects but shallow-replaces arrays. A child's `containers: [...]` fully replaces the base's `containers: []`. Design base arrays accordingly (usually empty `[]` as placeholder).

**Comments:** YAML comments are stripped during jq++ → yq round-trip. If the original has significant comments, note this in the report.

### 4. Create generate.sh and generate output

Create `samples/{sample-name}/.refactoring/refactored/generate.sh` using this template:

```bash
#!/usr/bin/env bash
# Usage:
#   generate.sh [OUT_DIR]
#
# Assembles .refactoring/refactored/ sources into OUT_DIR (default: .refactoring/sandbox).
# _-prefixed keys (private jq++ variables) are stripped from all output files.
#
# Typical workflow:
#   generate.sh                                 # build into .refactoring/sandbox (default)
#   diff -r ../.refactoring/sandbox ../.refactoring/generated
#   generate.sh ../.refactoring/generated       # promote to .refactoring/generated when satisfied

set -euo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"
SKILL_BIN="${REPO_ROOT}/.claude/skills/refactor-sample/bin"
SAMPLE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="${1:-${SAMPLE_DIR}/.refactoring/sandbox}"
export JF_PATH="${SAMPLE_DIR}/.refactoring/refactored/shared:${REPO_ROOT}/samples/shared"

# ── assemble ──────────────────────────────────────────────────────────────────
"${SKILL_BIN}/yjoin" --out-dir "${OUT_DIR}" "${SAMPLE_DIR}/.refactoring/refactored"
# Add one line per subdirectory, e.g.:
# "${SKILL_BIN}/yjoin" --out-dir "${OUT_DIR}/gateway-api" "${SAMPLE_DIR}/.refactoring/refactored/gateway-api"

# ── strip private _-prefixed keys ─────────────────────────────────────────────
while IFS= read -r f; do
  tmp="$(mktemp)"
  "${SKILL_BIN}/ystrip" "${f}" > "${tmp}"
  mv "${tmp}" "${f}"
done < <(find "${OUT_DIR}" -name "*.yaml" | sort)
```

Adjust the `yjoin` lines to match the sample's subdirectory structure. Make it executable:

```bash
chmod +x samples/{sample-name}/.refactoring/refactored/generate.sh
```

JSON files (`.json++`) still require explicit processing — `yjoin` handles `.yaml[++]` only. Add them to the assemble section of `generate.sh`:
```bash
jq++ "${SAMPLE_DIR}/.refactoring/refactored/config.json++" | jq . > "${OUT_DIR}/config.json"
```

Also create `samples/{sample-name}/.refactoring/refactored/verify.sh` using this template:

```bash
#!/usr/bin/env bash
# Usage:
#   verify.sh [DIR_A [DIR_B]]
#
# Checks semantic equivalence between DIR_A and DIR_B.
# Defaults: DIR_A=.refactoring/generated  DIR_B=.refactoring/sandbox
#
# YAML files are compared via: yq -S '.'  (key-sorted, null-filtered)
# JSON files are compared via: jq -S .
#
# Exits 0 if all files match, non-zero if any differ.

set -euo pipefail
SAMPLE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DIR_A="${1:-${SAMPLE_DIR}/.refactoring/generated}"
DIR_B="${2:-${SAMPLE_DIR}/.refactoring/sandbox}"

pass=0
fail=0

check_yaml() {
  local fa="$1" fb="$2" rel="$3"
  local out
  if out=$(diff \
      <(yq -S '.' "${fa}" | grep -v '^null$') \
      <(yq -S '.' "${fb}" | grep -v '^null$') 2>&1); then
    echo "OK:   ${rel}"
    pass=$((pass + 1))
  else
    echo "FAIL: ${rel}"
    echo "${out}" | sed 's/^/      /'
    fail=$((fail + 1))
  fi
}

check_json() {
  local fa="$1" fb="$2" rel="$3"
  local out
  if out=$(diff <(jq -S . "${fa}") <(jq -S . "${fb}") 2>&1); then
    echo "OK:   ${rel}"
    pass=$((pass + 1))
  else
    echo "FAIL: ${rel}"
    echo "${out}" | sed 's/^/      /'
    fail=$((fail + 1))
  fi
}

while IFS= read -r fa; do
  rel="${fa#${DIR_A}/}"
  fb="${DIR_B}/${rel}"
  if [[ ! -f "${fb}" ]]; then
    echo "MISS: ${rel}  (absent in ${DIR_B})"
    fail=$((fail + 1))
    continue
  fi
  case "${fa}" in
    *.yaml) check_yaml "${fa}" "${fb}" "${rel}" ;;
    *.json) check_json "${fa}" "${fb}" "${rel}" ;;
  esac
done < <(find "${DIR_A}" \( -name "*.yaml" -o -name "*.json" \) | sort)

echo ""
if [[ ${fail} -eq 0 ]]; then
  echo "PASS  ${pass}/${pass} files match"
else
  echo "FAIL  ${pass} passed, ${fail} failed"
fi

[[ ${fail} -eq 0 ]]
```

Make it executable:
```bash
chmod +x samples/{sample-name}/.refactoring/refactored/verify.sh
```

### 5. Run and verify

Run `generate.sh` to build into `.refactoring/sandbox/`, verify semantic equivalence against `.refactoring/generated/`, then promote:

```bash
# Build into .refactoring/sandbox (default)
samples/{sample-name}/.refactoring/refactored/generate.sh

# Verify .refactoring/sandbox matches .refactoring/generated
samples/{sample-name}/.refactoring/refactored/verify.sh
```

If diffs exist, investigate whether they are:
- Purely cosmetic (key ordering, trailing newlines) → acceptable, note in report
- Structural differences → fix the jq++ sources before reporting

Once all diffs pass, promote `.refactoring/sandbox/` to `.refactoring/generated/`:

```bash
samples/{sample-name}/.refactoring/refactored/generate.sh samples/{sample-name}/.refactoring/generated
```

