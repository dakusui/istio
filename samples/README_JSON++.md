# Reproducing the jq++ Refactoring Results

This document explains how to reproduce the jq++ refactoring results for the
Istio sample manifests in this repository, and how to experiment with jq++
yourself.

## What is jq++?

[jq++](https://github.com/dakusui/jqplusplus) is a YAML/JSON elaboration engine
that adds inheritance and computed values on top of plain YAML. It lets you
eliminate repetition in YAML files the same way object-oriented languages
eliminate repetition in code — through shared base files, parameterisation, and
reusable function libraries.

## Prerequisites

Install the following tools and make sure they are on your `PATH`:

| Tool | Purpose | Repository |
|---|---|---|
| `jq++` | YAML++ elaboration engine | [dakusui/jqplusplus](https://github.com/dakusui/jqplusplus) |
| `yq` | YAML/JSON converter (`kislyuk/yq` flavour) | [kislyuk/yq](https://github.com/kislyuk/yq) |
| `jq` | JSON processor (dependency of `yq`) | [jqlang/jq](https://github.com/jqlang/jq) |

Verify your installation:

```bash
jq++ --version   # e.g. jq++ version v0.0.30
yq --version
jq  --version
```

> **Note on `yq` flavour**: this repository uses `kislyuk/yq`, whose YAML output
> flag is `-y '.'`. The unrelated `mikefarah/yq` tool uses a different flag (`-P`)
> and will not work here.

## Refactored samples

| Sample | Refactored directory |
|---|---|
| `bookinfo/networking` | `samples/bookinfo/networking/.refactoring/refactored/` |
| `bookinfo/gateway-api` | `samples/bookinfo/gateway-api/.refactoring/refactored/` |
| `bookinfo` (platform) | `samples/bookinfo/.refactoring/refactored/` |
| `helloworld` | `samples/helloworld/.refactoring/refactored/` |
| `curl` | `samples/curl/.refactoring/refactored/` |
| `health-check` | `samples/health-check/.refactoring/refactored/` |
| `cicd` | `samples/cicd/.refactoring/refactored/` |

Each refactored directory follows this layout:

```
.refactoring/
  refactored/         ← jq++ source files (.yaml++, .jq)
    generate.sh       ← build output into sandbox/
    verify.sh         ← compare sandbox/ against generated/
    shared/           ← shared bases and function libraries
  generated/          ← committed baseline (what the sources should produce)
  sandbox/            ← local build output (git-ignored)
```

## Reproducing the results

For any refactored sample, run:

```bash
# 1. Build into sandbox/
samples/bookinfo/networking/.refactoring/refactored/generate.sh

# 2. Verify sandbox/ matches the committed baseline
samples/bookinfo/networking/.refactoring/refactored/verify.sh
```

A successful run prints `PASS  N/N files match`. Replace the path prefix with
any other sample from the table above.

## Key jq++ concepts used

### `$extends` — inheritance

A `.yaml++` file can inherit from one or more parent files. The current file
wins over parents; the first-listed parent wins over later ones. Objects are
deep-merged; arrays are shallow-replaced (the child's array fully replaces the
parent's).

```yaml
# shared/virtual-service-base.yaml++
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: "eval:string:refexpr(\"._svc\")"
spec:
  hosts:
  - "eval:string:refexpr(\"._svc\")"
  http: []
```

```yaml
# virtual-service-reviews-v3.yaml++
$extends:
  - traffic-split/all.yaml++      # first: its http array wins
  - virtual-service-base.yaml++   # second: provides apiVersion, kind, metadata
_svc: reviews
_subset: v3
```

### `_`-prefixed keys — private parameters

Keys starting with `_` are private configuration values (e.g. `_svc`, `_subset`).
They are available during elaboration and are stripped from the final output by
`generate.sh`.

### `eval:` — computed values

Values prefixed with `eval:<type>:` are computed using jq expressions:

```yaml
name: "eval:string:refexpr(\"._svc\")"       # reads _svc from the merged object
weight: "eval:number:refexpr(\"._traffic_split[0].weight\")"
destination: "eval:object:spec::routing_destination(refexpr(\"._subset\"))"
```

Types: `string`, `number`, `bool`, `array`, `object`.

### `.jq` modules — reusable functions

A `.jq` file in `$extends` acts as a function library. The filename becomes the
call-site prefix:

```jq
# shared/spec.jq
def subset_of(v): {"name": v, "labels": {"version": v}};
def routing_destination(sub): {"host": reftag("_svc"), "subset": sub};
def http_port(n): {"number": n, "name": "http", "protocol": "HTTP"};
def https_port(n): {"number": n, "name": "https", "protocol": "HTTPS"};
```

```yaml
# usage in a .yaml++
$extends:
  - spec.jq
spec:
  subsets:
  - "eval:object:spec::subset_of(\"v1\")"
  - "eval:object:spec::subset_of(\"v2\")"
```

`reftag("_svc")` searches upward through ancestor objects for the nearest `_svc`
key — useful inside functions that need context from the calling file.

### Cross-cutting mixins

Orthogonal concerns are expressed as separate base files composed side by side,
rather than through deep inheritance chains:

```yaml
# destination-rule-all-mtls.yaml++ (one document)
$extends:
  - subsets/reviews.yaml++          # what subsets to expose
  - destination-rule-base.yaml++    # DR boilerplate
  - policy/mtls.yaml++              # add mTLS traffic policy
_svc: reviews
```

```yaml
# shared/policy/mtls.yaml++
spec:
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
```

### Array ordering matters

Because the first-listed parent wins on conflicts, **traffic-split bases must be
listed before `virtual-service-base`** so their `spec.http` array takes
precedence over the empty placeholder `http: []` in the base:

```yaml
$extends:
  - traffic-split/ab-testing.yaml++   # first → http: [{route: ...}] wins
  - virtual-service-base.yaml++       # second → provides the rest
```

## Experimenting with Claude Code

If you have [Claude Code](https://claude.com/claude-code) installed, this
repository ships with slash commands that let an AI agent do the heavy lifting
for you. Open Claude Code in this repo's root and try:

| Command | What it does |
|---|---|
| `/refactor-sample samples/bookinfo/networking` | Refactors a sample directory from scratch using jq++ |
| `/refactor-and-report-sample samples/bookinfo/networking` | Refactors and writes a `REFACTORING_REPORT.md` in one go |
| `/refactoring-report bookinfo/networking` | Writes a report for an already-refactored sample |

For example, to refactor the `helloworld` sample and get a report, just type:

```
/refactor-and-report-sample samples/helloworld
```

The agent will analyse the YAML files, design a jq++ structure, write the
`.yaml++` sources, run `generate.sh` and `verify.sh`, and iterate until all
files match — no manual jq++ knowledge required to get started.

> **Tip**: you can also just describe what you want in plain English —
> *"Reduce repetition in `samples/bookinfo/networking` using jq++"* — and
> Claude Code will invoke the right skill automatically.

## Experimenting manually

To elaborate a single `.yaml++` file and inspect the output:

```bash
SKILL_BIN="$(git rev-parse --show-toplevel)/.claude/skills/refactor-yamls/bin"
SAMPLE="samples/bookinfo/networking/.refactoring/refactored"
export JF_PATH="${SAMPLE}/shared"

"${SKILL_BIN}/yq++" "${SAMPLE}/virtual-service-reviews-v3.yaml++"
```

Try editing `_subset`, adding a new entry to `_traffic_split`, or writing a new
leaf file that extends one of the existing shared bases — then re-run `generate.sh`
and `verify.sh` to see the effect.
