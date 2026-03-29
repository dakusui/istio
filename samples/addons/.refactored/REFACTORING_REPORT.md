# Refactoring Report: samples/addons

## Metrics

|            | Original | Refactored sources | Change        |
|------------|----------|--------------------|---------------|
| Lines      | 3026     | 2852               | −174 (−5.8%)  |
| Words      | 7255     | 6912               | −343 (−4.7%)  |

Originals: `grafana.yaml`, `jaeger.yaml`, `kiali.yaml`, `loki.yaml`, `prometheus.yaml`, `extras/prometheus-operator.yaml`, `extras/skywalking.yaml`, `extras/zipkin.yaml`

Refactored sources: all `.yaml++` files in `.refactored/` (including `shared/` bases).

## Verification

**PASS** — all 8 output files match their originals under Python `yaml.safe_load_all` + `json.dumps(sort_keys=True)` normalization:

- `grafana.yaml` ✓
- `jaeger.yaml` ✓
- `kiali.yaml` ✓
- `loki.yaml` ✓
- `prometheus.yaml` ✓
- `extras/prometheus-operator.yaml` ✓
- `extras/skywalking.yaml` ✓
- `extras/zipkin.yaml` ✓

Cosmetic differences (stripped from comparison):
- YAML document-end `...` markers in original `kiali.yaml` do not appear in generated output — YAML-equivalent, not a semantic difference.
- Comment lines in Helm `# Source:` headers are stripped.
- Key ordering may differ (e.g. `kind:` at end in original grafana dashboard ConfigMaps normalizes to standard order in output).

## Findings

### Pattern 1 — Per-addon label sets repeated across every resource

Each of the four main Helm-generated addons embeds an identical label block in every Kubernetes resource it defines. The label sets and their repetition counts:

| Addon      | Labels | Repetitions (incl. Deployment template) | Lines eliminated |
|------------|--------|-----------------------------------------|-----------------|
| kiali      | 7      | 8 (4 namespaced + 2 cluster-scoped + 2 Deployment template) | ~56 → ~25 via shared bases |
| prometheus | 6      | 7 (3 namespaced + 2 cluster-scoped + 2 template) | ~42 → ~20 via shared bases |
| loki       | 4      | 9 (7 namespaced + 2 cluster-scoped, StatefulSet has no separate template labels) | ~36 → ~16 via shared bases |
| grafana    | 4      | 5 (3 namespaced + Deployment template + Deployment metadata) | ~20 → ~10 via shared meta |

**Solution:** Two shared base files per addon (except grafana which has no ClusterRole):
- `shared/{addon}-labels.yaml++` — just the label set, extended by cluster-scoped resources (ClusterRole, ClusterRoleBinding) that must not inherit `namespace`
- `shared/{addon}-meta.yaml++` — extends labels + adds `metadata.namespace: istio-system`, extended by all namespaced resources

For example, kiali's 7-label block appears verbatim in 6 resources (ServiceAccount, ConfigMap, ClusterRole, ClusterRoleBinding, Service, Deployment metadata) plus once in the Deployment's `spec.template.metadata.labels`. The shared bases eliminate it from the 6 resource headers entirely; the template labels in the Deployment remain explicit since merging `spec.*` from a shared base would pollute other resource types.

### Pattern 2 — Multi-document YAML split into single-document sources

Each original `.yaml` file contains multiple Kubernetes documents separated by `---`. These were split into one `.yaml++` file per document, making each resource independently editable. The `generate.sh` reassembles them with `---` separators to reproduce the original file layout.

Document counts:
- `grafana.yaml`: 6 documents → 6 yaml++ files
- `jaeger.yaml`: 5 documents → 5 yaml++ files
- `kiali.yaml`: 6 documents → 6 yaml++ files
- `loki.yaml`: 9 documents → 9 yaml++ files
- `prometheus.yaml`: 6 documents → 6 yaml++ files
- `extras/prometheus-operator.yaml`: 2 documents → 2 yaml++ files
- `extras/skywalking.yaml`: 6 documents → 6 yaml++ files
- `extras/zipkin.yaml`: 3 documents → 3 yaml++ files

### Pattern 3 — Immutable data blobs in grafana dashboard ConfigMaps

Two of grafana's six documents (`istio-grafana-dashboards` and `istio-services-grafana-dashboards`) contain ~900 lines of minified/formatted Grafana dashboard JSON. These are opaque data with no structural repetition. They were extracted verbatim as yaml++ source files — jq++ passes them through unchanged since they contain no jq++ directives. These account for ~900 of the 3026 original lines and offer no DRY-up opportunity.

### Limitations

- **Comments stripped:** YAML comments in the original files (including `# Source:` Helm headers, inline notes in `jaeger.yaml`'s configmap, and comments in other configs) are not reproduced in the generated output. Content comments inside literal block scalars (i.e. within embedded YAML/text values like jaeger's `config.yaml`) are preserved as they are part of the string value, not YAML metadata.
- **Deployment template labels not deduplicated:** The `spec.template.metadata.labels` in Deployments and StatefulSets repeat the same label set but cannot be inherited via `$extends` from the shared metadata base without contaminating other resource types (ServiceAccount, Service, etc.) with unwanted `spec:` fields. These remain explicit in each Deployment source file.
- **Extras not DRY-ed further:** The three extras files (`prometheus-operator.yaml`, `skywalking.yaml`, `zipkin.yaml`) have simple `app: <name>` label patterns that repeat 2–6 times each. The savings from shared bases for these would be at most 3–6 lines per component — below the ~5-line threshold, so they were split into per-document files only.
