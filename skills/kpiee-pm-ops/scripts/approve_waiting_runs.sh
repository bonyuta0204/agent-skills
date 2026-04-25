#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  approve_waiting_runs.sh --repo <owner/repo> [--commit <sha> | --run-id <id1,id2,...>] \
    [--environment-id <id>] [--comment <text>]

Options:
  --repo            GitHub repository slug (owner/repo).
  --commit          Commit SHA to find waiting runs from.
  --run-id          Explicit run IDs (comma-separated).
  --environment-id  Environment ID to approve. Default: 7773130912
  --comment         Approval comment.
USAGE
}

REPO=""
COMMIT=""
RUN_IDS=""
ENV_ID="7773130912"
COMMENT="Approve test environment for CI"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --commit) COMMIT="$2"; shift 2 ;;
    --run-id) RUN_IDS="$2"; shift 2 ;;
    --environment-id) ENV_ID="$2"; shift 2 ;;
    --comment) COMMENT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$REPO" ]]; then
  usage >&2
  exit 1
fi

if [[ -n "$COMMIT" && -n "$RUN_IDS" ]]; then
  echo "Use either --commit or --run-id, not both." >&2
  exit 1
fi

if [[ -z "$COMMIT" && -z "$RUN_IDS" ]]; then
  usage >&2
  exit 1
fi

collect_run_ids_from_commit() {
  local commit="$1"
  gh run list --repo "$REPO" --commit "$commit" --json databaseId,status --jq \
    '.[] | select(.status=="waiting") | .databaseId'
}

approve_run() {
  local run_id="$1"
  local endpoint="/repos/${REPO}/actions/runs/${run_id}/pending_deployments"

  local pending
  pending="$(gh api -X GET "$endpoint")"
  if [[ "$pending" == "[]" ]]; then
    echo "run=${run_id} status=no_pending_deployments"
    return 0
  fi

  gh api -X POST "$endpoint" --input - <<JSON >/dev/null
{"environment_ids":[${ENV_ID}],"state":"approved","comment":"${COMMENT}"}
JSON
  echo "run=${run_id} status=approved environment_id=${ENV_ID}"
}

RUN_LIST=()
if [[ -n "$COMMIT" ]]; then
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    RUN_LIST+=("$id")
  done < <(collect_run_ids_from_commit "$COMMIT")
else
  IFS=',' read -r -a RUN_LIST <<< "$RUN_IDS"
fi

if [[ "${#RUN_LIST[@]}" -eq 0 ]]; then
  echo "No waiting runs found."
  exit 0
fi

for run_id in "${RUN_LIST[@]}"; do
  run_id="$(echo "$run_id" | xargs)"
  [[ -z "$run_id" ]] && continue
  approve_run "$run_id"
done

