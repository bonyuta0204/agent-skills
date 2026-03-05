#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 2 ]]; then
  echo "usage: $0 <task_id> <local_script.rb> [runner_arg ...]" >&2
  echo "env: ECS_CLUSTER=<cluster> ECS_CONTAINER=<container> AWS_REGION=<region(optional)>" >&2
  exit 1
fi

TASK_ID="$1"
LOCAL_SCRIPT="$2"
shift 2
RUNNER_ARGS=("$@")

if [[ ! -f "$LOCAL_SCRIPT" ]]; then
  echo "script not found: $LOCAL_SCRIPT" >&2
  exit 1
fi

resolve_region() {
  if [[ -n "${AWS_REGION:-}" ]]; then
    printf '%s\n' "$AWS_REGION"
    return 0
  fi

  local configured
  configured="$(aws configure get region 2>/dev/null || true)"
  if [[ -n "$configured" ]]; then
    printf '%s\n' "$configured"
    return 0
  fi

  printf '%s\n' "us-east-1"
}

REGION="$(resolve_region)"
CLUSTER="${ECS_CLUSTER:-}"
CONTAINER="${ECS_CONTAINER:-}"

if [[ -z "$CLUSTER" || -z "$CONTAINER" ]]; then
  echo "ECS_CLUSTER and ECS_CONTAINER must be set." >&2
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "aws command not found" >&2
  exit 1
fi

payload="$(base64 < "$LOCAL_SCRIPT" | tr -d '\n')"
remote_base="codex_runner_$(date +%s)_$$"
remote_rb="/tmp/${remote_base}.rb"
remote_log="/tmp/${remote_base}.log"
remote_code="/tmp/${remote_base}.code"

payload_esc="$(printf '%q' "$payload")"
runner_args_esc=""
for a in "${RUNNER_ARGS[@]}"; do
  runner_args_esc+=" $(printf '%q' "$a")"
done

exec_in_ecs() {
  local cmd="$1"
  local cmd_esc
  cmd_esc="$(printf '%q' "$cmd")"
  aws ecs execute-command \
    --region "$REGION" \
    --cluster "$CLUSTER" \
    --task "$TASK_ID" \
    --container "$CONTAINER" \
    --interactive \
    --command "bash -lc ${cmd_esc}"
}

run_cmd="set -euo pipefail; printf %s ${payload_esc} | base64 -d > ${remote_rb}; set +e; bundle exec rails runner ${remote_rb} --${runner_args_esc} > ${remote_log} 2>&1; rc=\$?; set -e; printf %s \"\$rc\" > ${remote_code}"
fetch_cmd="set -euo pipefail; rc=\$(cat ${remote_code} 2>/dev/null || echo 255); echo __RUNNER_EXIT_CODE__:\${rc}; cat ${remote_log} 2>/dev/null || true"
cleanup_cmd="set -euo pipefail; rm -f ${remote_rb} ${remote_log} ${remote_code}"

exec_in_ecs "$run_cmd" >/dev/null
result="$(exec_in_ecs "$fetch_cmd" 2>&1 || true)"

# Print logs without marker line.
echo "$result" | tr -d '\r' | sed '/__RUNNER_EXIT_CODE__:/d'

code="$(echo "$result" | tr -d '\r' | sed -n 's/.*__RUNNER_EXIT_CODE__:\([0-9][0-9]*\).*/\1/p' | tail -n1)"
if [[ -z "${code:-}" ]]; then
  # Session EOF などで marker が欠落した場合は code だけ再取得する。
  recovery_result="$(exec_in_ecs "set -euo pipefail; rc=\$(cat ${remote_code} 2>/dev/null || echo 255); echo __RUNNER_EXIT_CODE__:\${rc}" 2>&1 || true)"
  code="$(echo "$recovery_result" | tr -d '\r' | sed -n 's/.*__RUNNER_EXIT_CODE__:\([0-9][0-9]*\).*/\1/p' | tail -n1)"
fi

exec_in_ecs "$cleanup_cmd" >/dev/null 2>&1 || true

if [[ -z "${code:-}" ]]; then
  echo "failed to parse runner exit code" >&2
  echo "fetch result:" >&2
  echo "$result" >&2
  exit 1
fi

exit "$code"
