# Refactoring Report: multicluster

## Metrics

|               | Original | Refactored sources | of which: shared | Change      |
|---------------|----------|--------------------|------------------|-------------|
| Lines         | 146      | 137                | 10               | −9 (−6%)    |
| Words         | 273      | 226                | 47               | −47 (−17%)  |

Originals counted: `expose-istiod.yaml`, `expose-istiod-https.yaml`, `expose-services.yaml`.
`expose-istiod-rev.yaml.tmpl` was excluded — see note below.

## Verification

**PASS** — all three generated files are semantically identical to their originals:

```
diff <(yq -S '.' expose-istiod.yaml)       <(yq -S '.' .generated/expose-istiod.yaml)       → identical
diff <(yq -S '.' expose-istiod-https.yaml) <(yq -S '.' .generated/expose-istiod-https.yaml) → identical
diff <(yq -S '.' expose-services.yaml)     <(yq -S '.' .generated/expose-services.yaml)      → identical
```

Cosmetic differences (trailing whitespace after `PASSTHROUGH` in the original, trailing blank lines) are stripped by the `yq` round-trip; these are not semantic differences.

## Findings

### Pattern: shared Gateway selector

All three YAML files contain a `Gateway` resource with the same `apiVersion`, `kind`, and selector:

```yaml
spec:
  selector:
    istio: eastwestgateway
```

This was extracted into `shared/gateway-base.yaml++`, which serves as the root base for all three gateways. Each variant extends it and contributes only what differs (name, servers).

### Pattern: shared istiod Gateway name

`expose-istiod.yaml` and `expose-istiod-https.yaml` both contain a Gateway named `istiod-gateway` with the same selector. A second shared file, `shared/istiod-gateway-base.yaml++`, extends `gateway-base.yaml++` and adds only `metadata.name: istiod-gateway`. Both istiod gateway variants then extend this base and contribute only their `spec.servers` arrays.

The two server lists use the same port numbers (15012 and 15017) but differ in protocol (`tls` vs `https`), TLS mode (`PASSTHROUGH` vs `SIMPLE`), credential configuration, and host patterns — so they cannot share a server-level base without unwanted coupling.

### Pattern: multi-document YAML splitting

All three original files mix multiple Kubernetes resources in a single YAML file separated by `---`. Each document becomes its own `.yaml++` source file, improving individual resource readability. `generate.sh` concatenates them back with `---` separators to reproduce the original multi-document files.

### Note: expose-istiod-rev.yaml.tmpl excluded

`expose-istiod-rev.yaml.tmpl` is a Go template file using `{{.Revision}}` placeholders. These are not valid YAML values and cannot be processed by jq++. The file was excluded from this refactoring. A future approach could generate this template from a base plus a Go template post-processing step, but that is outside jq++'s scope.

### Note: YAML comments stripped

The original `expose-istiod-https.yaml` contains inline comments (e.g., `# use a valid credential here`, `# use a valid gateway host and domain for istiod`). These are stripped during the `jq++ | yq` round-trip. The generated output is semantically identical but lacks these comments. This is an inherent limitation of the toolchain.
