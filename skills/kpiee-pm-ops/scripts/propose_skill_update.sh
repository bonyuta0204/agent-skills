#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROPOSAL_FILE="${SKILL_DIR}/memory/update-proposals.md"

TITLE=""
REASON=""
CHANGE=""
STATUS="proposed"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/propose_skill_update.sh \
    --title "<proposal title>" \
    --reason "<why now>" \
    --change "<proposed change>" \
    [--status proposed|approved|rejected|done]
EOF
}

while (($# > 0)); do
  case "$1" in
    --title) TITLE="${2:-}"; shift 2 ;;
    --reason) REASON="${2:-}"; shift 2 ;;
    --change) CHANGE="${2:-}"; shift 2 ;;
    --status) STATUS="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "${TITLE}" || -z "${REASON}" || -z "${CHANGE}" ]]; then
  echo "Missing required argument." >&2
  usage
  exit 1
fi

TODAY="$(date '+%Y-%m-%d')"

{
  echo
  echo "## ${TODAY}"
  echo "- title: ${TITLE}"
  echo "- reason: ${REASON}"
  echo "- proposed_change: ${CHANGE}"
  echo "- status: ${STATUS}"
} >> "${PROPOSAL_FILE}"

echo "Added proposal to ${PROPOSAL_FILE}"
