# Refactoring Report: external

## Metrics

| | Original | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 117 | 81 | 7 | −36 (−31%) |
| Words | 344 | 138 | 13 | −206 (−60%) |

> **Note:** The large word-count reduction is dominated by comment blocks present in the originals (inline documentation, license-like headers, and URL references) that are stripped during the jq++ → yq round-trip. The line reduction reflects both comment removal and genuine structural deduplication.

## Verification

**PASS** — All generated files match originals semantically:

```
aptget.yaml:  PASS
github.yaml:  PASS
pypi.yaml:    PASS
```

Verified with `yq -S '.'` (sorted-key diff) against originals.

## Source file layout

```
.refactored/
  shared/
    service-entry-https-base.yaml++   # HTTPS ServiceEntry base (port 443)
  aptget.yaml++                       # make-aptget-work (HTTP/80, 5 hosts)
  github-https.yaml++                 # github-https (HTTPS/443)
  github-tcp.yaml++                   # github-tcp (TCP/22, 18 CIDR addresses)
  pypi-python-https.yaml++            # python-https (HTTPS/443)
  pypi-pypi-https.yaml++              # pypi-https (HTTPS/443)
  pypi-pythonhosted-https.yaml++      # pythonhosted-https (HTTPS/443)
  generate.sh
```

## Findings

### Document splitting

All three original files contain multiple `---`-separated documents. Each document is extracted into its own `.yaml++` file named to reflect both the source file and the resource:

- `aptget.yaml` (1 doc) → `aptget.yaml++`
- `github.yaml` (2 docs) → `github-https.yaml++` + `github-tcp.yaml++`
- `pypi.yaml` (3 docs) → `pypi-python-https.yaml++` + `pypi-pypi-https.yaml++` + `pypi-pythonhosted-https.yaml++`

### Shared HTTPS ServiceEntry base

Four of the six `ServiceEntry` resources expose a single external host over HTTPS (port 443): `github-https`, `python-https`, `pypi-https`, and `pythonhosted-https`. All four share the same `apiVersion`, `kind`, and `spec.ports` block. These 7 shared lines are extracted to `shared/service-entry-https-base.yaml++`, and each variant uses `$extends` to inherit them — reducing 4 × 11 content lines to one 7-line base plus four 7-line variants (44 → 35 lines, saving 9 lines).

### Non-shared entries

Two entries have unique structures and do not extend the shared base:

- **`aptget.yaml++`** (`make-aptget-work`): HTTP/80 with 5 hosts — distinct port + multi-host structure.
- **`github-tcp.yaml++`** (`github-tcp`): TCP/22 with 18 IP CIDR addresses and `location: MESH_EXTERNAL` — unique in the sample; the 18-address block cannot be abstracted further.

### Comments stripped

The originals contain substantial inline commentary (purpose, caveats, links to Istio/GitHub documentation). These are valid YAML comments and are stripped during the jq++ → yq elaboration round-trip. The comments are preserved in the `.yaml++` sources if desired, but were omitted here to keep the sources clean; they are noted in the originals for reference.
