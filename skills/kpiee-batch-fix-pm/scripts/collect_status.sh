#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  collect_status.sh --repo <owner/repo> --prs <comma_separated_pr_numbers>

Example:
  collect_status.sh --repo f-scratch/dx-kpiee --prs 12371,12372,12373
USAGE
}

REPO=""
PRS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --prs) PRS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$REPO" || -z "$PRS" ]]; then
  usage >&2
  exit 1
fi

classify_checks() {
  local checks="$1"
  if printf '%s' "$checks" | rg -q '\bfail\b|\berror\b'; then
    echo "fail"
  elif printf '%s' "$checks" | rg -q '\bpending\b|\bwaiting\b'; then
    echo "in_progress"
  elif printf '%s' "$checks" | rg -q '\bpass\b'; then
    echo "pass"
  else
    echo "unknown"
  fi
}

echo "pr,status,title,url"
IFS=',' read -r -a PR_ARRAY <<< "$PRS"
for pr in "${PR_ARRAY[@]}"; do
  pr="$(echo "$pr" | xargs)"
  [[ -z "$pr" ]] && continue

  info="$(gh pr view "$pr" --repo "$REPO" --json title,url --jq '[.title,.url] | @tsv')"
  title="$(echo "$info" | cut -f1)"
  url="$(echo "$info" | cut -f2)"
  checks="$(gh pr checks "$pr" --repo "$REPO" 2>&1 || true)"
  status="$(classify_checks "$checks")"

  echo "${pr},${status},\"${title}\",${url}"
done

