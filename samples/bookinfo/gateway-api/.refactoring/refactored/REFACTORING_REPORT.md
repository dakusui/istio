# Refactoring Report: bookinfo/gateway-api

## Metrics

| | Generated (baseline) | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 164 | 104 | 25 | −60 (−37%) |
| Words | 303 | 183 | 71 | −120 (−40%) |

## Verification

PASS — 6/6 files match.

## Findings

### Source structure

The refactored tree has 6 leaf `.yaml++` files (one per output YAML) and 3 shared
files under `shared/`:

```
shared/
  httproute.jq                      # jq function library
  httproute/
    svc-v1-base.yaml++              # single-service v1 HTTPRoute
    reviews-base.yaml++             # reviews-specific HTTPRoute boilerplate
```

### jq function library (`httproute.jq`)

Three functions encapsulate the repeated object constructions in HTTPRoute specs:

- `parentRef(port)` — Gateway parent reference; derives the service name from
  the nearest `_svc` ancestor via `reftag`
- `backendRef(version; port)` — single backend ref with name built as
  `_svc + "-" + version`
- `backendRef(version; port; weight)` — same, with an added `weight` field for
  weighted routing

The two arities of `backendRef` cleanly cover both the unweighted (v1/v3 pinning)
and weighted (90/10, 50/50) cases without any conditional logic in the leaf files.

### `svc-v1-base.yaml++` — per-service v1 route

`route-all-v1.yaml` contains four HTTPRoute documents (one per service), each
routing all traffic to `v1`. Extracting `svc-v1-base.yaml++` parameterizes this
with `_svc`, reducing each document to two lines (`$extends` + `_svc`).
`route-all-v1.yaml++` shrank from 59 generated lines to 15 lines (−75%).

### `reviews-base.yaml++` — reviews route boilerplate

The four reviews-specific route files (`route-reviews-v1`, `route-reviews-v3`,
`route-reviews-50-v3`, `route-reviews-90-10`) all share the same HTTPRoute
skeleton: `apiVersion`, `kind`, `metadata.name: reviews`, and
`spec.parentRefs` pointing at the gateway. This was extracted into
`reviews-base.yaml++` (which hardcodes `_svc: reviews`). Each leaf then only
specifies `spec.rules[0].backendRefs`, reducing 14–18 generated lines per file
to 6–7 lines.

### `bookinfo-gateway.yaml++` — no reduction

The gateway file combines a `Gateway` resource and a catch-all `HTTPRoute` with
five distinct path matchers. Neither resource has a counterpart elsewhere in the
tree, so no extraction was applicable. The file is identical in size to its
generated output (41 lines).

### Iterative evolution (git history)

The refactoring evolved over 7 commits, reflecting design decisions made
incrementally:

1. **Initial jq++ split** — established the leaf/shared structure and moved
   repeated boilerplate into bases.
2. **`backendRef/2,3` with `_svc` derivation** — eliminated hardcoded service
   names by deriving them from the `_svc` context key via `reftag`.
3. **`parentRef/1`** — extracted the gateway parent reference into a function,
   also using `reftag` for the service name.
4. **Rename `funcs.jq` → `httproute.jq`** — aligned the module name with its
   domain so call sites read as `httproute::backendRef(...)`.
5. **Service name resolved inside `parentRef`** — moved `_svc` resolution into
   the function rather than requiring callers to pass it explicitly.
6. **Bases moved into `shared/httproute/`** — grouped the two base files into a
   subdirectory for clarity, separating them from the `.jq` module.
7. **Relative paths** — updated `$extends` entries to use paths relative to the
   leaf file's directory (resolved via `JF_PATH`).
