#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="${SKILL_DIR}/memory/learning-log.md"

TYPE=""
SIGNAL=""
ACTION=""
SCOPE=""
EVIDENCE=""

usage() {
  cat <<'EOF'
Usage:
  ./scripts/record_learning.sh \
    --type <workflow|governance|risk|communication> \
    --signal "<what happened>" \
    --action "<what changed>" \
    --scope "<where it applies>" \
    --evidence "<proof>"
EOF
}

while (($# > 0)); do
  case "$1" in
    --type) TYPE="${2:-}"; shift 2 ;;
    --signal) SIGNAL="${2:-}"; shift 2 ;;
    --action) ACTION="${2:-}"; shift 2 ;;
    --scope) SCOPE="${2:-}"; shift 2 ;;
    --evidence) EVIDENCE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "${TYPE}" || -z "${SIGNAL}" || -z "${ACTION}" || -z "${SCOPE}" || -z "${EVIDENCE}" ]]; then
  echo "Missing required argument." >&2
  usage
  exit 1
fi

NOW="$(date '+%Y-%m-%dT%H:%M:%S%z')"
NOW_FMT="${NOW:0:22}:${NOW:22:2}"

{
  echo
  echo "## ${NOW_FMT}"
  echo "- type: ${TYPE}"
  echo "- signal: ${SIGNAL}"
  echo "- action: ${ACTION}"
  echo "- scope: ${SCOPE}"
  echo "- evidence: ${EVIDENCE}"
} >> "${LOG_FILE}"

echo "Appended learning to ${LOG_FILE}"
