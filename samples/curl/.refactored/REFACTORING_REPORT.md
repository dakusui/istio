# Refactoring Report: curl

## Metrics

| | Original | Refactored sources | Change |
|---|---|---|---|
| Lines | 66 | 61 | −5 (−8%) |
| Words | 181 | 101 | −80 (−44%) |

## Verification

**PASS** — semantic diff (sorted JSON via `yq -S '.'`) confirms all documents match.

## Findings

The curl sample is structurally identical to sleep: ServiceAccount, Service, and Deployment,
all named "curl". The same three shared bases and same three variant-file pattern applies,
differing only in name, mount path (`/etc/curl/tls`), and secret name (`curl-secret`).

The metrics are identical to sleep (−8% lines, −44% words) since the files are the same size.

One observation: the original `curl.yaml` has a 14-line Apache license header comment block.
Comments are stripped during the jq++ → yq round-trip (JSON has no comment syntax), so
the generated `.generated/curl.yaml` omits the license header. This is a known limitation.
If preserving license headers is required, they should be prepended separately in `generate.sh`.
