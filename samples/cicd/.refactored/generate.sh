#!/usr/bin/env bash
# Usage:
#   generate.sh [OUT_DIR]
#
# Assembles .refactored/ sources into OUT_DIR (default: ../.generated).
# _-prefixed keys (private jq++ variables) are stripped from all output files.
#
# To compare a local edit against the current .generated/:
#   generate.sh /tmp/cicd-preview
#   diff -r /tmp/cicd-preview ../.generated/

set -euo pipefail
SKILL_BIN="$(git rev-parse --show-toplevel)/.claude/skills/refactor-sample/bin"
SAMPLE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${1:-${SAMPLE_DIR}/.generated}"

# ── assemble ──────────────────────────────────────────────────────────────────
"${SKILL_BIN}/yjoin" --out-dir "${OUT_DIR}/skaffold" "${SAMPLE_DIR}/.refactored/skaffold"

# ── strip private _-prefixed keys ─────────────────────────────────────────────
while IFS= read -r f; do
  tmp="$(mktemp)"
  "${SKILL_BIN}/ystrip" "${f}" > "${tmp}"
  mv "${tmp}" "${f}"
done < <(find "${OUT_DIR}" -name "*.yaml" | sort)
