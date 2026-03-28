# Refactoring Report: sleep

## Metrics

| | Original | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 66 | 61 | 16 | −5 (−8%) |
| Words | 181 | 101 | 27 | −80 (−44%) |

## Verification

**PASS** — Generated file matches original semantically:

```
sleep.yaml: PASS
```

Verified with `yq -S '.'` (sorted-key diff) against original.

## Source file layout

```
.refactored/
  shared/
    deployment-base.yaml++       # Deployment skeleton (apiVersion, kind, replicas, empty containers)
    service-base.yaml++          # Service skeleton (apiVersion, kind, empty ports/selector)
    service-account-base.yaml++  # ServiceAccount skeleton (apiVersion, kind)
  sleep-serviceaccount.yaml++    # ServiceAccount sleep
  sleep-service.yaml++           # Service sleep (port 80, selector app=sleep)
  sleep-deployment.yaml++        # Deployment sleep (curlimages/curl, volume mount)
  generate.sh
```

## Findings

### Document splitting

The single three-document `sleep.yaml` (ServiceAccount + Service + Deployment) is split into one `.yaml++` file per resource.

### Shared bases for all three resource types

All three documents extend a shared skeleton in `shared/`:

- **`deployment-base.yaml++`** (9 lines): `apiVersion: apps/v1`, `kind: Deployment`, `spec.replicas: 1`, `spec.selector.matchLabels: {}`, `spec.template.spec.containers: []`
- **`service-base.yaml++`** (5 lines): `apiVersion: v1`, `kind: Service`, `spec.ports: []`, `spec.selector: {}`
- **`service-account-base.yaml++`** (2 lines): `apiVersion: v1`, `kind: ServiceAccount`

These three bases save the 3 × `apiVersion`/`kind` repetition and establish the common skeleton for each resource type. The primary metric win (−80 words, −44%) comes from the 14-line Apache license header in the original being stripped during the jq++ → yq round-trip, plus the structural boilerplate absorbed by the bases.

### App label repetition

The `app: sleep` label appears four times in the original (Service `labels`, Service `selector`, Deployment `matchLabels`, Deployment template `labels`). It remains explicit in the variant files — deriving it via `eval:refexpr` would add more characters than it saves for a single-variant sample with a short, predictable name.

### Shared bases and the curl sample

The three shared bases (`deployment-base.yaml++`, `service-base.yaml++`, `service-account-base.yaml++`) are structurally identical to those created for the `curl` sample. Per this skill's design, bases are kept per-sample; no cross-sample sharing is introduced.
