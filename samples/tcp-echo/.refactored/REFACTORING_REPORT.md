# Refactoring Report: tcp-echo

## Metrics

|                    | Original | Refactored sources | of which: shared | Change          |
|--------------------|----------|--------------------|------------------|-----------------|
| Lines              | 494      | 251                | 49               | −243 (−49%)     |
| Words              | 1417     | 426                | 81               | −991 (−70%)     |

Originals: `tcp-echo-services.yaml`, `tcp-echo.yaml`, `tcp-echo-ipv6.yaml`, `tcp-echo-ipv4.yaml`,
`tcp-echo-dual-stack.yaml`, `tcp-echo-all-v1.yaml`, `tcp-echo-20-v2.yaml`,
`gateway-api/tcp-echo-all-v1.yaml`, `gateway-api/tcp-echo-20-v2.yaml`

Refactored sources: 15 `.yaml++` files (3 in `shared/`, 5 in `gateway-api/`, 7 top-level)

Note: original files contain ~15-line Apache license headers which are not included in the refactored
sources (YAML comments are stripped during jq++ → yq round-trip). This accounts for a portion of the
word reduction.

## Verification

**PASS** — all 9 generated files match their originals exactly:

```
diff <(yq -S '.' tcp-echo-services.yaml      | grep -v '^null$') <(yq -S '.' .generated/tcp-echo-services.yaml      | grep -v '^null$')  # PASS
diff <(yq -S '.' tcp-echo.yaml               | grep -v '^null$') <(yq -S '.' .generated/tcp-echo.yaml               | grep -v '^null$')  # PASS
diff <(yq -S '.' tcp-echo-ipv6.yaml          | grep -v '^null$') <(yq -S '.' .generated/tcp-echo-ipv6.yaml          | grep -v '^null$')  # PASS
diff <(yq -S '.' tcp-echo-ipv4.yaml          | grep -v '^null$') <(yq -S '.' .generated/tcp-echo-ipv4.yaml          | grep -v '^null$')  # PASS
diff <(yq -S '.' tcp-echo-dual-stack.yaml    | grep -v '^null$') <(yq -S '.' .generated/tcp-echo-dual-stack.yaml    | grep -v '^null$')  # PASS
diff <(yq -S '.' tcp-echo-all-v1.yaml        | grep -v '^null$') <(yq -S '.' .generated/tcp-echo-all-v1.yaml        | grep -v '^null$')  # PASS
diff <(yq -S '.' tcp-echo-20-v2.yaml         | grep -v '^null$') <(yq -S '.' .generated/tcp-echo-20-v2.yaml         | grep -v '^null$')  # PASS
diff <(yq -S '.' gateway-api/tcp-echo-all-v1.yaml | grep -v '^null$') <(yq -S '.' .generated/gateway-api/tcp-echo-all-v1.yaml | grep -v '^null$')  # PASS
diff <(yq -S '.' gateway-api/tcp-echo-20-v2.yaml  | grep -v '^null$') <(yq -S '.' .generated/gateway-api/tcp-echo-20-v2.yaml  | grep -v '^null$')  # PASS
```

## Findings

The `tcp-echo` sample has rich repetition across three distinct patterns, all addressed here.

### Pattern 1: Identical Deployment repeated four times (largest win)

`tcp-echo.yaml`, `tcp-echo-ipv6.yaml`, `tcp-echo-ipv4.yaml`, and `tcp-echo-dual-stack.yaml` each embed
an **identical 20-line Deployment** for the `hello`-variant `tcp-echo` server. That is 80 lines of
duplicated source across four files. `shared/deployment-hello.yaml++` (21 lines) captures this once;
`generate.sh` references it four times, reducing those 80 lines to a single canonical definition.

### Pattern 2: Five Service documents share the same base, with three IP-family variants

The five top-level files all define the same `tcp-echo` Service (name, labels, 2-port spec, selector).
Three of them add `ipFamilyPolicy` and `ipFamilies` to form SingleStack-IPv6, SingleStack-IPv4, and
RequireDualStack variants. The `shared/service-base.yaml++` (15 lines) captures the common structure.
Each variant extends it with just 3–4 additional lines:

- `service-default.yaml++` — 2 lines (`$extends` only)
- `service-ipv6.yaml++` / `service-ipv4.yaml++` — 6 lines each
- `service-dual-stack.yaml++` — 7 lines

The five original Services (≈15 lines each = 75 lines) become 36 lines total in the refactored sources.

### Pattern 3: Parametric v1/v2 Deployments in tcp-echo-services.yaml

The two Deployments in `tcp-echo-services.yaml` are identical except for three varying fields: the
resource name (`tcp-echo-v1`/`tcp-echo-v2`), the `version` label in metadata, selector, and template
labels, and the container `args` (`"one"`/`"two"`). `shared/deployment-base.yaml++` (13 lines) holds
the shared skeleton; `deployment-v1.yaml++` and `deployment-v2.yaml++` (24 lines each) extend it,
providing the version-specific fields and the full containers array (required because jq++ shallow-
replaces arrays). The two original Deployments (52 lines) become 61 lines in the refactored sources —
a slight increase due to the `$extends` + full container block overhead — but the structural relationship
between v1 and v2 is now explicit and a version label change requires editing exactly one place per file.

### Limitations

- **Comments stripped:** The original files contain inline comments (e.g., the note about port 9002
  being intentionally omitted). These are lost in the jq++ → yq round-trip and do not appear in the
  generated output. This is expected behavior.
- **Array merge:** Because jq++ shallow-replaces arrays, the `containers` array cannot be split between
  base and variant — each variant must provide the full container spec. This prevents extracting the
  shared `image`, `imagePullPolicy`, and `ports` sub-fields into the base, limiting savings on the v1/v2
  Deployment pair.
- **License headers:** Original files include a 15-line Apache 2.0 license header that is not replicated
  in the jq++ sources. This contributes substantially to the word-count reduction and should be
  considered when interpreting the 70% word reduction figure.
