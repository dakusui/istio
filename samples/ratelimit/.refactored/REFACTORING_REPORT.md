# Refactoring Report: ratelimit

## Metrics

|                    | Original | Refactored sources | of which: shared | Change       |
|--------------------|----------|--------------------|------------------|--------------|
| Lines              | 238      | 192                | 0                | −46 (−19%)   |
| Words              | 603      | 343                | 0                | −260 (−43%)  |

Originals: `rate-limit-service.yaml`, `local-rate-limit-service.yaml`

Refactored sources: 5 `.yaml++` files (no shared/ directory)

Note: the word count reduction is dominated by the removal of the Apache 2.0 license header
(~130 words) and the inline ConfigMap example in `rate-limit-service.yaml`'s comment block
(~80 words), both of which are YAML comments stripped during jq++ → yq round-trip.

## Verification

**PASS** — both generated files match their originals exactly:

```
diff <(yq -S '.' rate-limit-service.yaml      | grep -v '^null$') \
     <(yq -S '.' .generated/rate-limit-service.yaml      | grep -v '^null$')  # PASS
diff <(yq -S '.' local-rate-limit-service.yaml | grep -v '^null$') \
     <(yq -S '.' .generated/local-rate-limit-service.yaml | grep -v '^null$') # PASS
```

## Findings

The `ratelimit` sample is a small, two-file sample with two distinct configurations. Neither file
contains structural repetition that jq++ can meaningfully reduce.

### rate-limit-service.yaml

This file contains four documents: a Redis Service and Deployment, and a ratelimit Service and
Deployment. The documents are split into individual `.yaml++` files for clarity.

The only intra-file repetition is the label pattern: `app: redis` appears in `metadata.labels`,
`spec.selector`, and `spec.template.metadata.labels` (4 places across the two Redis documents;
same for `ratelimit`). Eliminating these via `$local` + `eval:` would save approximately 2 lines
per document-pair at the cost of added `$local` definition overhead — well below the ~5-line
threshold. The label duplication was left as-is.

The ratelimit Deployment image tag includes an inline comment (`# 2024/08/01`) that is stripped
by the jq++ → yq round-trip. This is noted for awareness but does not affect semantic correctness.

### local-rate-limit-service.yaml

This single-document EnvoyFilter has no separate shared-base opportunity (it is a standalone
resource with no variants). One internal repetition is worth noting: the `filter_enabled` and
`filter_enforced` blocks are structurally identical:

```yaml
filter_enabled:
  runtime_key: test_enabled
  default_value:
    numerator: 100
    denominator: HUNDRED
filter_enforced:          # identical structure and values
  runtime_key: test_enabled
  default_value:
    numerator: 100
    denominator: HUNDRED
```

These 10 lines could theoretically be reduced using `$local` + `$extends`. However, the blocks
are nested four levels deep inside a `configPatches` array element, and the `$extends` overhead
(2 lines per reference) would match the savings exactly — net change of 0 lines. The abstraction
was not applied.

The inline comment on `enable_x_ratelimit_headers` is stripped in the generated output.

### Summary

No `shared/` directory was created. This sample's content is too unique and compact for jq++
to provide line-count savings beyond what is achieved by splitting the multi-document YAML into
individual per-resource files.
