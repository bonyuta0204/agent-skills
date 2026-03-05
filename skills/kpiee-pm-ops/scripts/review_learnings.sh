#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="${SKILL_DIR}/memory/learning-log.md"

if [[ ! -f "${LOG_FILE}" ]]; then
  echo "learning log not found: ${LOG_FILE}" >&2
  exit 1
fi

echo "== Type Frequency =="
grep -E "^- type: " "${LOG_FILE}" | sed 's/^- type: //' | sort | uniq -c | sort -nr || true
echo
echo "== Signal Frequency =="
grep -E "^- signal: " "${LOG_FILE}" | sed 's/^- signal: //' | sort | uniq -c | sort -nr | head -n 20 || true
