---
name: refactor-yamls
description: Refactor YAML/JSON files in any directory tree using jq++ to eliminate repetition, producing a DRY, maintainable version. Use this skill whenever the user asks to refactor, DRY up, or reduce duplication in a directory of YAML/JSON files using jq++ or YAML/JSON templating outside of the samples/ convention. Trigger on phrases like "refactor the YAMLs in {dir}", "DRY up the configs in {dir}", "apply jq++ to {dir}". Prefer refactor-sample for directories under samples/.
---

# Refactor YAMLs Skill

Refactor YAML and JSON files in any directory using jq++ to eliminate repetition.

## Arguments

- **TARGET_DIR** — the directory containing the YAML/JSON files to refactor (e.g. `infra/k8s/staging`)

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

Three scripts are provided under `.claude/skills/refactor-yamls/bin/` and should be invoked with their full path (or add the directory to PATH):

### `yq++ FILE`

Elaborates a single `.yaml[++]` file to stdout. Internally splits the file on `---` boundaries, processes each document through `jq++` (for `.yaml++`) or `yq` (for `.yaml`), and concatenates the results. Relative `$extends` paths resolve correctly because the input file's directory is mirrored into the temp workspace via symlinks.

```bash
"${SKILL_BIN}/yq++" path/to/file.yaml++
```

Useful for quickly inspecting what a `.yaml++` file produces without running the full `yjoin` pipeline.

### `ystrip [FILE ...]`

Removes all object keys beginning with `_` from YAML input, recursively at any depth. Reads from stdin when no files are given; handles multi-document YAML.

```bash
cat elaborated.yaml | "${SKILL_BIN}/ystrip"
"${SKILL_BIN}/ystrip" file.yaml
```

### `yjoin [--out-dir OUT_DIR] [SRC_DIR]`

Batch-assembles all source files in `SRC_DIR` into `.yaml` files in `OUT_DIR`.

- Files named `{name}.yaml++` are elaborated via `yq++`; multi-document files with `---` separators are handled correctly, with `$extends` working per-document
- Files named `{stem}@{id}.yaml++` are rendered via `jq++ | yq -y '.'` and grouped by stem
- Files named `{stem}@{id}.yaml` are rendered via `yq -y '.'` and grouped by stem

```bash
SKILL_BIN="$(git rev-parse --show-toplevel)/.claude/skills/refactor-yamls/bin"
"${SKILL_BIN}/yjoin" --out-dir "${TARGET_DIR}/.refactoring/sandbox" "${TARGET_DIR}/.refactoring/refactored"
```

### `ysplit [--out-dir OUT_DIR] FILE [FILE ...]`

Splits a multi-document `.yaml` file into `{stem}@{NN}.yaml` parts. Useful as a migration aid when starting a refactoring.

```bash
"${SKILL_BIN}/ysplit" --out-dir /tmp/ path/to/file.yaml
```

## Key jq++ Concepts

jq++ elaborates `.yaml++` / `.json++` files into plain YAML/JSON. All directives are valid YAML/JSON.

| Directive | Purpose |
|---|---|
| `$extends: [file]` | Inherit fields from parent files. Current object wins; first listed parent wins over later ones. Deep-merges objects, shallow-replaces arrays. |
| `$local: {Name: {...}}` | Define named local objects for in-file reuse (stripped from output). |
| `eval:string:refexpr(".field")` | Reference another field's value (chained: follows further eval: references). |
| `eval:<type>:<jq expr>` | Compute a value with jq. Types: `string`, `number`, `bool`, `array`, `object`. |
| `raw:key` | Emit a key literally, bypassing all directive processing. |

Run: `jq++ file.yaml++` → plain JSON on stdout. Pipe to `yq -y '.'` for YAML output.

**Path resolution:** jq++ resolves `$extends` paths relative to the source file's directory, then checks `JF_PATH`. Because `generate.sh` puts the `shared/` directory on `JF_PATH`, shared base files can be referenced by bare filename from any subdirectory — no relative path prefix needed.

**Note on `yq` flavors:** The `yq` on this system is the `kislyuk/yq` wrapper. Its YAML output flag is `-y '.'`, not `-P`. Always use `yq -y '.'`.

## Directory Layout

```
{TARGET_DIR}/               ← originals — DO NOT MODIFY
  *.yaml
  *.json
  .refactoring/
    refactored/             ← refactored jq++ source files
      generate.sh           ← build sandbox/ from sources
      verify.sh             ← check sandbox/ vs generated/
      shared/               ← base files reused within this tree
        *.yaml++
        *.jq
      {name}.yaml++         ← one file per output YAML
      *.json++
    sandbox/                ← working output; default target of generate.sh
    generated/              ← committed output baseline; promoted from sandbox when verified
```

### File-naming convention

One `.yaml++` file per output YAML. Use `---` separators for multi-document files:

```
{name}.yaml++   →  {name}.yaml   (one or more documents)
```

Each `---`-separated document in a `.yaml++` file is elaborated independently, so `$extends` works per-document.

## Step-by-Step Workflow

### 1. Analyze the original files

Read all `.yaml` and `.json` files in `{TARGET_DIR}/` recursively. For each file:

- Record the Kubernetes `kind`, `apiVersion`, and key metadata
- Identify repeated field groups (labels, selectors, resource requests, image prefixes, etc.)
- Note multi-document YAML files (`---` separators)
- Identify parametric variants (same structure, different values)

### 2. Design the refactored structure

Decide what to extract:

- **Repeated structure across documents** → shared base in `.refactoring/refactored/shared/`
- **Parametric variants** (same structure, different values) → base file + per-variant extends
- **Derived values** (e.g., name built from app + version) → `eval:string:refexpr(...)` within the file
- **Orthogonal cross-cutting concern** → separate shared base added to `$extends` (multi-base inheritance)
- **Pattern where one parameter determines multiple sibling fields** → custom jq function in `shared/*.jq`

Two complementary reasons to extract an abstraction:

- **Size reduction** — duplicate lines that appear in three or more places, or repeated blocks that save ~5+ lines total, are worth pulling into a shared base.
- **Naming** — even a small extraction can be worthwhile if giving the base or function a meaningful name makes the intent of the file tree clearer. A three-line base named `dual-stack-service-base` communicates more than an inline `ipFamilyPolicy` block.

When neither applies — the repetition is small *and* a name adds no clarity — leave it inline.

### 3. Create the jq++ source files

**One `.yaml++` per output file.** Use `---` to separate documents within it.

Use `ysplit` to generate a quick initial split for inspection:

```bash
SKILL_BIN="$(git rev-parse --show-toplevel)/.claude/skills/refactor-yamls/bin"
"${SKILL_BIN}/ysplit" --out-dir /tmp/ "{TARGET_DIR}/file.yaml"
```

**Shared base files** in `.refactoring/refactored/shared/`:

```yaml
# shared/deployment-base.yaml++
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

Reference by bare filename from any depth — JF_PATH handles the lookup:
```yaml
$extends:
  - deployment-base.yaml++
```

**Private `_`-prefixed value holders** — `ystrip` removes them from output:

```yaml
_app: myservice
_version: v1
metadata:
  name: "eval:string:refexpr(\"._app\") + \"-\" + refexpr(\"._version\")"
  labels:
    app: "eval:string:refexpr(\"._app\")"
    version: "eval:string:refexpr(\"._version\")"
```

**`reftag` for values embedded in nested objects:**

```yaml
profiles:
  - _chart: istiod
    _ns: istio-system
    deploy:
      helm:
        releases:
          - remoteChart: "eval:string:reftag(\"_chart\")"
            namespace: "eval:string:reftag(\"_ns\")"
```

`reftag(name)` searches upward through ancestor objects for the nearest matching key.

**Multi-base inheritance:**

```yaml
$extends:
  - deployment-base.yaml++
  - svcaccount-mixin.yaml++
_app: myapp
_version: v1
```

**Custom jq function libraries** for patterns where one parameter determines multiple sibling fields:

```jq
# shared/funcs.jq
def versioned_subset(p): {"name": p, "labels": {"version": p}};
```

```yaml
$extends:
  - destination-rule-base.yaml++
  - funcs.jq
spec:
  subsets:
  - "eval:object:funcs::versioned_subset(\"v1\")"
  - "eval:object:funcs::versioned_subset(\"v2\")"
```

**Note:** Custom `.jq` module functions can call jq++ built-ins (`refexpr`, `reftag`, etc.) directly — they do not run in a restricted plain-jq context. You can use `refexpr` and `reftag` inside `.jq` functions just as you would in a `.yaml++` file.

**Array merging:** jq++ deep-merges objects but shallow-replaces arrays. A child's `containers: [...]` fully replaces the base's `containers: []`. Design base arrays accordingly (usually empty `[]` as placeholder).

**Comments:** YAML comments are stripped during jq++ → yq round-trip.

### 4. Create generate.sh and verify.sh

Copy the templates and make them executable:

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
cp "${REPO_ROOT}/.claude/skills/refactor-yamls/templates/generate.sh" \
   "{TARGET_DIR}/.refactoring/refactored/generate.sh"
cp "${REPO_ROOT}/.claude/skills/refactor-yamls/templates/verify.sh" \
   "{TARGET_DIR}/.refactoring/refactored/verify.sh"
chmod +x "{TARGET_DIR}/.refactoring/refactored/generate.sh" \
         "{TARGET_DIR}/.refactoring/refactored/verify.sh"
```

**Edit the `# ── assemble ──` section** to match the subdirectory structure — adjust `yjoin` lines and `mkdir -p` for any output subdirectories. If the source tree has subdirectories, add one `yjoin` call per subdirectory:

```bash
mkdir -p "${OUT_DIR}/subdir-a" "${OUT_DIR}/subdir-b"
"${SKILL_BIN}/yjoin" --out-dir "${OUT_DIR}/subdir-a" "${TARGET_DIR}/.refactoring/refactored/subdir-a"
"${SKILL_BIN}/yjoin" --out-dir "${OUT_DIR}/subdir-b" "${TARGET_DIR}/.refactoring/refactored/subdir-b"
```

JSON files (`.json++`) require explicit processing:
```bash
jq++ "${TARGET_DIR}/.refactoring/refactored/config.json++" | jq . > "${OUT_DIR}/config.json"
```

### 5. Run and verify

```bash
# Build into .refactoring/sandbox (default)
{TARGET_DIR}/.refactoring/refactored/generate.sh

# Verify .refactoring/sandbox matches .refactoring/generated
{TARGET_DIR}/.refactoring/refactored/verify.sh
```

If diffs exist, investigate whether they are:
- Purely cosmetic (key ordering, trailing newlines) → acceptable
- Structural differences → fix the jq++ sources before reporting

Once all diffs pass, promote `.refactoring/sandbox/` to `.refactoring/generated/`:

```bash
{TARGET_DIR}/.refactoring/refactored/generate.sh {TARGET_DIR}/.refactoring/generated
```
