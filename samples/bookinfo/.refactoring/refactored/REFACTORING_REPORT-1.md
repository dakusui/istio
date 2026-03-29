# Refactoring Report: bookinfo

## Metrics

| | Generated (baseline) | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 1798 | 976 | 180 | −822 (−46%) |
| Words | 3053 | 1648 | 348 | −1405 (−46%) |

Scope: 24 output files — 20 under `platform/kube/` and 4 under `networking/`.

## Verification

PASS — 24/24 files match.

## Findings

### Repeated Deployment scaffold

Every bookinfo Deployment repeats the same ~15-line scaffold: `apiVersion`, `kind`, `metadata` (name, labels), `spec.replicas`, `spec.selector.matchLabels`, and `spec.template.metadata.labels`. A shared `deployment-base.yaml++` captures this structure once, deriving name and all label values from two private holders `_app` and `_version` using `refexpr`. Any child document merely sets `_app` and `_version` and overrides `spec.template.spec`.

```yaml
# Entire details-v1 deployment source (vs ~30 original lines)
$extends:
  - simple-deployment-base.yaml++
_app: details
_version: v1
```

The savings were sharpest for standalone per-service files: `bookinfo-details.yaml` (57 → 8 lines), `bookinfo-ratings.yaml` (57 → 8 lines), `bookinfo-reviews-v2.yaml` (56 → 4 lines), and `bookinfo-ratings-discovery.yaml` (31 → 3 lines).

### Parametric deployment variants with identical structure

`bookinfo-ratings-v2-mysql.yaml` and `bookinfo-ratings-v2-mysql-vm.yaml` are structurally identical — they share the same image (`ratings-v2:1.20.3`), five env vars, and a single port — differing only in the deployment name/version label and the value of `MYSQL_DB_HOST`. A shared `ratings-v2-mysql-deployment-base.yaml++` holds the full container spec, with `MYSQL_DB_HOST` derived from a `_mysql_host` holder. Each variant is now 4 lines:

```yaml
$extends:
  - ratings-v2-mysql-deployment-base.yaml++
_version: v2-mysql
_mysql_host: mysqldb
```

Combined source went from 109 lines to 8 lines for the two variant files (plus ~20 lines in the shared base).

### Three-variant files (bookinfo.yaml, bookinfo-dualstack.yaml, bookinfo-psa.yaml)

These three files are the same 14-document application manifest with incremental additions: `bookinfo-dualstack.yaml` adds `ipFamilyPolicy`/`ipFamilies` to each Service; `bookinfo-psa.yaml` adds a `securityContext` block to each container. Separate PSA-specific bases (`psa-simple-deployment-base.yaml++`, `psa-reviews-deployment-base.yaml++`) encode the securityContext once. The reviews deployments (v1/v2/v3) additionally share `reviews-deployment-base.yaml++` for the LOG_DIR env var and wlp-output/tmp volume structure. The three files shrank from 1041 combined lines to 332 lines of jq++ source.

### Version-pinned services (bookinfo-versions.yaml)

Six Services with version-specific selectors (`reviews-v1`, `reviews-v2`, `reviews-v3`, `productpage-v1`, `ratings-v1`, `details-v1`) follow a single pattern: name is `{app}-{version}`, selector has both `app` and `version`. A `service-version-base.yaml++` captures this; each document becomes 4 lines (72 → 29 total, including separators).

### Repeated Service and ServiceAccount structure

All four bookinfo Services (details, ratings, reviews, productpage) use port 9080/HTTP with name, `app`/`service` labels, and a single-field `app` selector. A `service-base.yaml++` derives all four fields from `_app`. Similarly, all four ServiceAccounts follow `bookinfo-{app}` naming with an `account: {app}` label, handled by `service-account-base.yaml++`.

### Networking: DestinationRules and VirtualServices

`destination-rule-all.yaml` and `destination-rule-all-mtls.yaml` share the same four-service structure; the mtls variant adds `trafficPolicy.tls.mode: ISTIO_MUTUAL`. A `destination-rule-base.yaml++` plus a thin `destination-rule-mtls-base.yaml++` extension reduce each document to a `_app` setter plus a `subsets` list. `virtual-service-all-v1.yaml` has four identical VirtualServices (one per service, all routing to subset `v1`); a `virtual-service-v1-base.yaml++` reduces each from 13 lines to 4 lines (52 → 15 total).

### Limitations

- **Comments stripped.** All YAML comments in the originals (Apache license headers, section banners) are lost during the jq++ → yq round-trip. The generated files are semantically equivalent but have no comments.
- **Array merge constraint.** jq++ deep-merges objects but shallow-replaces arrays. Container specs cannot be partially overridden — a child that needs to add a field (e.g., `env`, `securityContext`) to an inherited container must redeclare the full container entry. This is why `bookinfo-details-v2.yaml++` re-specifies the entire container despite extending `simple-deployment-base.yaml++`, and why PSA bases duplicate the non-PSA container spec plus the added securityContext.
- **Non-standard images not derivable.** For ratings-v2 variants (mysql, mysql-vm), the image tag is `ratings-v2`, not `ratings-{version}`, so the standard `{app}-{version}` image formula does not apply. The shared base hardcodes the image name, which makes this clear.
- **Out-of-scope files.** The remaining networking files (individual VirtualServices, fault-injection configs, egress rules) and all gateway-api files were not included in this refactoring — each is already a single unique document with no cross-file repetition worth addressing.
