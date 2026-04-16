# Refactoring Report: bookinfo/networking

## Metrics

| | Generated (baseline) | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 615 | 412 | 62 | −203 (−33%) |
| Words | 1035 | 697 | 101 | −338 (−33%) |
| DuplicationRatio | 18.6% | 5.0% | — | −13.6 pp |

DuplicationRatio measures the fraction of structural content (key-value pairs)
that is redundant repetition across files. The "shared" column is not applicable
because the ratio is computed across the whole directory.

## Verification

PASS — 21/21 files match.

## Findings

### Source structure

The refactored tree has 21 leaf `.yaml++` files (one per output YAML) and 11 shared
bases under `shared/`, organized into four subdirectories:

```
shared/
  spec.jq                        # jq function library
  destination-rule-base.yaml++
  gateway-base.yaml++
  virtual-service-base.yaml++
  policy/
    mtls.yaml++                  # ISTIO_MUTUAL traffic policy mixin
  subsets/
    productpage.yaml++
    reviews.yaml++
    ratings.yaml++
    details.yaml++
  traffic-split/
    all.yaml++                   # route 100% to a single subset
    ab-testing.yaml++            # weighted split across two subsets
```

### jq function library (`spec.jq`)

Four repeated inline object constructions were extracted into named functions:

- `subset_of(v)` — DestinationRule subset entry `{name, labels.version}`
- `http_port(n)` / `https_port(n)` — Gateway/ServiceEntry port objects
- `routing_destination(sub)` — VirtualService route destination `{host, subset}`

These eliminate verbose repeated object literals across 15+ files and make the
intent of each eval expression self-evident at a glance.

### Gateway base (`gateway-base.yaml++`)

`bookinfo-gateway.yaml` and `certmanager-gateway.yaml` shared all Gateway boilerplate
(apiVersion, kind, selector, empty servers array). Extracting `gateway-base.yaml++`
reduced each file by ~6 lines while keeping only the `servers` definition per leaf.

### DestinationRule bases and mixins

`destination-rule-base.yaml++` captures the common DR skeleton (apiVersion, kind,
metadata.name, spec.host derived from `_svc`, empty subsets). The mTLS policy was
originally a subclass (`destination-rule-mtls-base.yaml++` extending the DR base),
but was split into an independent mixin `policy/mtls.yaml++` with no parent. This
makes the relationship explicit: `-mtls` variants now compose `destination-rule-base`
and `policy/mtls` side by side, rather than inheriting through a deeper hierarchy.

The four subset lists (productpage: 1 subset, details: 2, reviews: 3, ratings: 4)
were extracted into `shared/subsets/`. Since both `destination-rule-all.yaml++` and
`destination-rule-all-mtls.yaml++` repeated identical subset lists, this eliminated
8 duplicate blocks. Every document in both files is now just `$extends` + `_svc`.

### VirtualService traffic-split pattern

The most significant reduction came from the traffic-split bases. Fourteen
VirtualService files fell into two structural families:

- **All-traffic-to-one-subset** (8 files: `virtual-service-all-v1`, `*-reviews-v3`,
  `*-details-v2`, `*-ratings-{db,mysql,mysql-vm}` × 2 docs each): extracted into
  `traffic-split/all.yaml++`, which uses `routing_destination(refexpr("._subset"))`.
  Each leaf is now 5 lines: two `$extends` entries, `_svc`, and `_subset`.

- **Weighted two-way split** (4 files: `virtual-service-reviews-{v2-v3,90-10,80-20,50-v3}`):
  extracted into `traffic-split/ab-testing.yaml++`, which reads `_traffic_split[0/1]`
  for names and weights. Each leaf is 9 lines including the two-entry `_traffic_split`
  array.

Both traffic-split bases extend only `spec.jq` (not `virtual-service-base`), making
them cross-cutting concerns reusable outside the VS context. Leaf files compose both
`traffic-split/X.yaml++` and `virtual-service-base.yaml++` explicitly. The ordering
matters: the traffic-split base must be listed **first** so its `spec.http` array
wins over the empty `http: []` placeholder in `virtual-service-base.yaml++` (jq++
first-parent-wins semantics for arrays).

### Latent bug discovered during refactoring

When the weighted-split files were first introduced (`ab-testing.yaml++`), the
`$extends` order was inadvertently reversed — `virtual-service-base` was listed first
and its `http: []` silently won, producing empty route arrays in the generated output.
This was only caught when `traffic-split/all.yaml++` was introduced and the same
symptom appeared for a different set of files. Both sets were corrected together by
swapping the extends order.

### Limitations

- **Array deep-merge not yet supported**: `virtual-service-ratings-test-abort.yaml++`
  and `virtual-service-ratings-test-delay.yaml++` differ only in their `fault` block
  but cannot share a base that defines the surrounding `match` and `route` structure,
  because a child array replaces the parent array entirely rather than merging by
  index. A feature request has been filed: [dakusui/jqplusplus#53](https://github.com/dakusui/jqplusplus/issues/53).
  Once implemented, these two 19-line files could each shrink to ~8 lines with a
  shared `traffic-split/ratings-fault.yaml++` base.

- **Comments stripped**: YAML comments in the originals are lost during the
  jq++ → yq round-trip. The generated files are semantically equivalent but
  lack inline documentation.
