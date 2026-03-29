# Refactoring Report: extauthz

## Metrics

| | Original | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 167 | 123 | 6 | −44 (−26%) |
| Words | 509 | 215 | 11 | −294 (−58%) |

> **Note:** The large word-count reduction is dominated by the Apache license header blocks (14 comment lines × 2 files) present in the originals but absent from jq++ sources. These headers are stripped during the YAML round-trip in any case.

## Verification

**PASS** — Both generated files match originals semantically:

```
ext-authz.yaml:       PASS
local-ext-authz.yaml: PASS
```

Verified with `yq -S '.'` (sorted-key diff) against originals.

## Source file layout

```
.refactored/
  shared/
    local-service-entry-base.yaml++     # base for both local ServiceEntry resources
  ext-authz-service.yaml++              # ext-authz Service
  ext-authz-deployment.yaml++           # ext-authz Deployment
  local-ext-authz-service-entry-http.yaml++   # httpbin-ext-authz-http ServiceEntry
  local-ext-authz-service-entry-grpc.yaml++   # httpbin-ext-authz-grpc ServiceEntry
  local-ext-authz-deployment.yaml++     # httpbin Deployment (with ext-authz sidecar)
  local-ext-authz-service.yaml++        # httpbin Service
  local-ext-authz-serviceaccount.yaml++ # httpbin ServiceAccount
  generate.sh
```

## Findings

### Document splitting

Both original YAML files are multi-document (separated by `---`). The primary refactoring is splitting them into one `.yaml++` file per Kubernetes resource:

- `ext-authz.yaml` (2 docs) → `ext-authz-service.yaml++` + `ext-authz-deployment.yaml++`
- `local-ext-authz.yaml` (5 docs) → 5 individual files

This makes each resource independently readable and maintainable.

### Shared ServiceEntry base

The two `ServiceEntry` resources in `local-ext-authz.yaml` share the same shape — both define a local sidecar listener at `127.0.0.1` with `resolution: STATIC`. Only the name, host, port number, and protocol differ. These 4 common fields are extracted to `shared/local-service-entry-base.yaml++`, and each variant uses `$extends` to inherit them.

This saves 4 lines of duplication (the 4 shared fields would otherwise appear twice) and makes the intent clear: both entries follow the same local-sidecar pattern.

### ext-authz container duplication

The ext-authz container spec (image `registry.istio.io/testing/ext-authz:latest`, `imagePullPolicy: Always`, and ports 8000/9000) appears identically in both the standalone `ext-authz` Deployment and as the sidecar container inside the `httpbin` Deployment. This cross-file repetition cannot be cleanly eliminated with jq++: containers live inside arrays, and jq++ shallow-replaces arrays on `$extends` merge. A shared container fragment would need to be inlined as the entire `containers` array, which breaks the httpbin Deployment that has two containers. This limitation is noted for awareness.

### Within-document label repetition

In `local-ext-authz.yaml`, the label set `{app: httpbin, version: v1}` appears twice in the httpbin Deployment (in `spec.selector.matchLabels` and `spec.template.metadata.labels`). While this could be extracted via a `$local` object + nested `$extends`, the savings amount to only 2 lines — below the ~5-line threshold that justifies the abstraction overhead. The labels are left verbatim.

Similarly, `app: ext-authz` repeats 4 times within the ext-authz Deployment (metadata.name, selector, pod labels, container name). These are all the same literal string with no derived relationship, so `eval:` expressions would add noise without meaningful benefit.
