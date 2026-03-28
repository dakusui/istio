#!/usr/bin/env bash
# Usage:
#   generate.sh [OUT_DIR]
#
# Assembles .refactored/ sources into OUT_DIR (default: ../.sandbox).
# _-prefixed keys (private jq++ variables) are stripped from all output files.
#
# Typical workflow:
#   generate.sh                       # build into .sandbox (default)
#   diff -r ../.sandbox ../.generated # compare with committed baseline
#   generate.sh ../.generated         # promote to .generated when satisfied

set -euo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"
SKILL_BIN="${REPO_ROOT}/.claude/skills/refactor-sample/bin"
SAMPLE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${1:-${SAMPLE_DIR}/.sandbox}"
export JF_PATH="${SAMPLE_DIR}/.refactored/shared:${REPO_ROOT}/samples/shared"

# ── assemble ──────────────────────────────────────────────────────────────────
"${SKILL_BIN}/yjoin" --out-dir "${OUT_DIR}/skaffold" "${SAMPLE_DIR}/.refactored/skaffold"

# ── strip private _-prefixed keys ─────────────────────────────────────────────
while IFS= read -r f; do
  tmp="$(mktemp)"
  "${SKILL_BIN}/ystrip" "${f}" > "${tmp}"
  mv "${tmp}" "${f}"
done < <(find "${OUT_DIR}" -name "*.yaml" | sort)
