# Refactoring Report: proxy-coredump

## Metrics

| | Original | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 45 | 43 | 0 | −2 (−4%) |
| Words | 85 | 79 | 0 | −6 (−7%) |

## Verification

**PASS** — Generated file matches original semantically:

```
daemonset.yaml: PASS
```

Verified with `yq -S '.'` (sorted-key diff) against original.

## Source file layout

```
.refactored/
  daemonset.yaml++   # DaemonSet enable-istio-coredumps
  generate.sh
```

## Findings

### Single document, no structural repetition

The sample contains exactly one file with one document (a DaemonSet). There are no variants, no cross-file repetition, and no structural patterns meeting the ~5-line savings threshold. The refactoring is a direct 1:1 translation to `.yaml++`.

### Commented-out fields stripped

The original contains two commented-out fields:
```yaml
# hostPID: true
# hostIPC: true
```
These represent intentionally disabled features (host process/IPC namespace sharing, which would expand the DaemonSet's privilege surface). They are stripped during the jq++ → yq round-trip since YAML comments are not preserved. This is the most significant practical difference between the original and the generated output — anyone applying `daemonset.yaml` from `.generated/` will not see these hints.
