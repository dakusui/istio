# Refactoring Report: jwt-server

## Metrics

| | Original | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 124 | 104 | 0 | −20 (−16%) |
| Words | 279 | 156 | 0 | −123 (−44%) |

> **Note:** No shared bases are used — no cross-document structural repetition meets the savings threshold. Word count reduction is primarily from the Apache license header comments stripped during the jq++ → yq round-trip.

## Verification

**PASS** — Generated file matches original semantically:

```
jwt-server.yaml: PASS
```

Verified with `yq -S '.'` (sorted-key diff) against original.

## Source file layout

```
.refactored/
  jwt-server-service.yaml++     # Service (ports 8000/8443)
  jwt-server-secret.yaml++      # Secret (embedded PEM certificate and key)
  jwt-server-deployment.yaml++  # Deployment (mounts secret as volume)
  generate.sh
```

## Findings

### Document splitting

The single three-document `jwt-server.yaml` is split into one `.yaml++` file per resource: Service, Secret, and Deployment. This is the primary structural improvement.

### No shared base

The three documents are structurally distinct (Service, Secret, Deployment) and share no reusable block beyond the string `jwt-server` as a name. While that name appears 7 times across the file, replacing those occurrences with `eval:string:refexpr(".appName")` expressions would produce longer lines and add an `appName` root field that bleeds into output — a net negative.

### Secret with dotted keys

The `stringData` block uses dotted YAML keys (`server.crt`, `server.key`). jq++ correctly handles these as plain string keys at the YAML level; no `raw:key` escaping was needed.

### PEM data preservation

The embedded TLS certificate and private key (multi-line PEM blocks using YAML `|` literal scalars) are preserved verbatim through the jq++ → yq round-trip. The round-trip reformats them as YAML block scalars with consistent indentation, which is semantically equivalent.
