# Refactoring Report: mtls-echo

## Metrics

| | Original | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 101 | 100 | 0 | −1 (−1%) |
| Words | 182 | 181 | 0 | −1 (−1%) |

## Verification

**PASS** — Generated file matches original semantically:

```
mtls-echo.yaml: PASS
```

Verified with `yq -S '.'` (sorted-key diff) against original.

## Source file layout

```
.refactored/
  mtls-echo-service.yaml++         # Service mtls-echo (ClusterIP, port 8443)
  mtls-echo-deployment-v1.yaml++   # Deployment mtls-echo-v1
  generate.sh
```

## Findings

### Document splitting

The single two-document `mtls-echo.yaml` is split into one `.yaml++` file per resource: `mtls-echo-service.yaml++` and `mtls-echo-deployment-v1.yaml++`.

### No structural repetition

The sample contains exactly one Service and one Deployment with no parametric variants and no cross-file content. There is no structural repetition meeting the ~5-line savings threshold, so no shared base is created.

The Deployment name `mtls-echo-v1` (with explicit version suffix) implies a v2 variant may have been planned or removed. If a v2 variant were added in future, `shared/deployment-base.yaml++` would be the natural extraction point for the shared `env`, probes, `image`, `imagePullPolicy`, and `ports` block (~45 lines), with variants differing only in `--version` arg and labels.

### Preserved discrepancy

The original contains a volumeMount referencing `name: ca-certs` while the corresponding volume is declared as `name: ca`. This mismatch is preserved verbatim — the refactoring does not fix bugs in the original.
