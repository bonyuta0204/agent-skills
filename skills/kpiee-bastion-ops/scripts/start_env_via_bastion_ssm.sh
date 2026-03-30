#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage:
  start_env_via_bastion_ssm.sh <it|stg|stg01|stg02> [options]

options:
  --region <region>                    AWS region (default: AWS_REGION, aws config, or us-west-2)
  --bastion-instance <instance-id>     Explicit bastion instance ID
  --wait-seconds <seconds>             Max seconds to wait for post-check (default: 900)
  --poll-interval-seconds <seconds>    Poll interval seconds for post-check (default: 15)
  --skip-preflight                     Skip local dependency / AWS identity checks
  -h, --help                           Show this help

env fallbacks:
  AWS_REGION
  BASTION_INSTANCE_ID
  DEFAULT_BASTION_INSTANCE_ID
USAGE
}

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

  printf '%s\n' "us-west-2"
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || {
    echo "required file not found: $path" >&2
    exit 1
  }
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFLIGHT_SCRIPT="${SCRIPT_DIR}/preflight.sh"
RUNNER_SCRIPT="${SCRIPT_DIR}/run_command_via_bastion_ssm.sh"

require_file "$PREFLIGHT_SCRIPT"
require_file "$RUNNER_SCRIPT"

DEFAULT_BASTION_INSTANCE_ID="${DEFAULT_BASTION_INSTANCE_ID:-i-05cb1b41cda7e3806}"
BASTION_INSTANCE_ID="${BASTION_INSTANCE_ID:-$DEFAULT_BASTION_INSTANCE_ID}"
WAIT_SECONDS=900
POLL_INTERVAL_SECONDS=15
SKIP_PREFLIGHT=0
REGION=""

TARGET_ENV="${1:-}"
if [[ -z "$TARGET_ENV" ]]; then
  usage
  exit 1
fi
shift

case "$TARGET_ENV" in
  it|stg|stg01|stg02)
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    echo "unsupported env: $TARGET_ENV" >&2
    usage
    exit 1
    ;;
esac

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --region)
      REGION="${2:-}"
      shift 2
      ;;
    --bastion-instance)
      BASTION_INSTANCE_ID="${2:-}"
      shift 2
      ;;
    --wait-seconds)
      WAIT_SECONDS="${2:-}"
      shift 2
      ;;
    --poll-interval-seconds)
      POLL_INTERVAL_SECONDS="${2:-}"
      shift 2
      ;;
    --skip-preflight)
      SKIP_PREFLIGHT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

REGION="${REGION:-$(resolve_region)}"

if ! [[ "$WAIT_SECONDS" =~ ^[0-9]+$ ]] || ! [[ "$POLL_INTERVAL_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "wait / poll values must be non-negative integers." >&2
  exit 1
fi

run_remote_script() {
  local comment="$1"
  local force_mode="$2"
  local script_body="$3"
  local tmp_script
  local output

  tmp_script="$(mktemp "${TMPDIR:-/tmp}/kpiee-start-env-XXXXXX.sh")"
  printf '%s\n' "$script_body" > "$tmp_script"

  if [[ "$force_mode" == "force" ]]; then
    output="$("$RUNNER_SCRIPT" \
      --bastion-instance "$BASTION_INSTANCE_ID" \
      --region "$REGION" \
      --comment "$comment" \
      --timeout-seconds 1800 \
      --force \
      --script-file "$tmp_script")"
  else
    output="$("$RUNNER_SCRIPT" \
      --bastion-instance "$BASTION_INSTANCE_ID" \
      --region "$REGION" \
      --comment "$comment" \
      --timeout-seconds 1800 \
      --script-file "$tmp_script")"
  fi

  rm -f "$tmp_script"
  printf '%s\n' "$output"
}

print_json_result() {
  local title="$1"
  local json="$2"

  echo "== ${title} =="
  echo "status: $(echo "$json" | jq -r '.status')"

  local stdout_content
  stdout_content="$(echo "$json" | jq -r '.stdout')"
  if [[ -n "$stdout_content" ]]; then
    echo "$stdout_content"
  fi

  local stderr_content
  stderr_content="$(echo "$json" | jq -r '.stderr')"
  if [[ -n "$stderr_content" ]]; then
    echo "-- stderr --"
    echo "$stderr_content"
  fi

  echo
}

ensure_success() {
  local title="$1"
  local json="$2"
  local status
  status="$(echo "$json" | jq -r '.status')"

  if [[ "$status" != "Success" ]]; then
    print_json_result "$title" "$json"
    exit 1
  fi
}

count_wait_lines() {
  local json="$1"
  local stdout_content
  stdout_content="$(echo "$json" | jq -r '.stdout')"
  printf '%s\n' "$stdout_content" | grep -Ec '^(RDS_WAIT|ECS_WAIT)\b' || true
}

if [[ "$SKIP_PREFLIGHT" -ne 1 ]]; then
  AWS_REGION="$REGION" "$PREFLIGHT_SCRIPT"
  echo
fi

UTC_NOW="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "target_env=${TARGET_ENV}"
echo "region=${REGION}"
echo "bastion_instance=${BASTION_INSTANCE_ID}"
echo "utc_started_at=${UTC_NOW}"
echo

read -r -d '' INSPECT_TARGETS_SCRIPT <<EOF || true
set -euo pipefail

env_name="${TARGET_ENV}"

echo "[rds_targets]"
sed -n '1,120p' "/opt/work/infra/script/\${env_name}/rds/target_db_instance_lists.txt"
echo
echo "[ecs_targets]"
sed -n '1,120p' "/opt/work/infra/script/\${env_name}/ecs/target_service_lists.txt"
EOF

read -r -d '' START_RDS_SCRIPT <<EOF || true
set -uo pipefail

env_name="${TARGET_ENV}"
region="${REGION}"
target_file="/opt/work/infra/script/\${env_name}/rds/target_db_instance_lists.txt"
errors=0

while IFS= read -r raw_db || [[ -n "\$raw_db" ]]; do
  db=\$(printf '%s' "\$raw_db" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [[ -n "\$db" ]] || continue
  [[ "\$db" =~ ^# ]] && continue

  if ! status=\$(aws rds describe-db-instances --region "\$region" --db-instance-identifier "\$db" --query 'DBInstances[0].DBInstanceStatus' --output text 2>&1); then
    echo "RDS_ERROR db=\$db step=describe-status message=\$(printf '%s' "\$status" | tr '\n' ' ')"
    errors=1
    continue
  fi

  if ! source_db=\$(aws rds describe-db-instances --region "\$region" --db-instance-identifier "\$db" --query 'DBInstances[0].ReadReplicaSourceDBInstanceIdentifier' --output text 2>&1); then
    echo "RDS_ERROR db=\$db step=describe-source message=\$(printf '%s' "\$source_db" | tr '\n' ' ')"
    errors=1
    continue
  fi

  if ! replica_count=\$(aws rds describe-db-instances --region "\$region" --db-instance-identifier "\$db" --query 'length(DBInstances[0].ReadReplicaDBInstanceIdentifiers)' --output text 2>&1); then
    echo "RDS_ERROR db=\$db step=describe-replicas message=\$(printf '%s' "\$replica_count" | tr '\n' ' ')"
    errors=1
    continue
  fi

  if [[ "\$source_db" == "None" ]]; then
    source_db=""
  fi

  if [[ -n "\$source_db" || "\$replica_count" != "0" ]]; then
    echo "RDS_SKIP db=\$db reason=read-replica-topology status=\$status"
    continue
  fi

  case "\$status" in
    available|starting)
      echo "RDS_NOOP db=\$db status=\$status"
      ;;
    stopped)
      if ! start_output=\$(aws rds start-db-instance --region "\$region" --db-instance-identifier "\$db" --query 'DBInstance.[DBInstanceIdentifier,DBInstanceStatus]' --output text 2>&1); then
        echo "RDS_ERROR db=\$db step=start message=\$(printf '%s' "\$start_output" | tr '\n' ' ')"
        errors=1
        continue
      fi
      echo "RDS_START db=\$db result=\$(printf '%s' "\$start_output" | tr '\t' '/' | tr '\n' ' ')"
      ;;
    *)
      echo "RDS_SKIP db=\$db reason=unsupported-state status=\$status"
      ;;
  esac
done < "\$target_file"

exit "\$errors"
EOF

read -r -d '' START_ECS_SCRIPT <<EOF || true
set -uo pipefail

env_name="${TARGET_ENV}"
region="${REGION}"
cluster="kpiee-\${env_name}"
target_file="/opt/work/infra/script/\${env_name}/ecs/target_service_lists.txt"
errors=0

while IFS= read -r raw_service || [[ -n "\$raw_service" ]]; do
  service=\$(printf '%s' "\$raw_service" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [[ -n "\$service" ]] || continue
  [[ "\$service" =~ ^# ]] && continue

  if ! desired=\$(aws ecs describe-services --region "\$region" --cluster "\$cluster" --services "\$service" --query 'services[0].desiredCount' --output text 2>&1); then
    echo "ECS_ERROR service=\$service step=describe-desired message=\$(printf '%s' "\$desired" | tr '\n' ' ')"
    errors=1
    continue
  fi

  if ! running=\$(aws ecs describe-services --region "\$region" --cluster "\$cluster" --services "\$service" --query 'services[0].runningCount' --output text 2>&1); then
    echo "ECS_ERROR service=\$service step=describe-running message=\$(printf '%s' "\$running" | tr '\n' ' ')"
    errors=1
    continue
  fi

  if [[ "\$desired" == "1" ]]; then
    echo "ECS_NOOP service=\$service desired=\$desired running=\$running"
    continue
  fi

  if ! update_output=\$(aws ecs update-service --region "\$region" --cluster "\$cluster" --service "\$service" --desired-count 1 --query 'service.[serviceName,desiredCount,runningCount]' --output text 2>&1); then
    echo "ECS_ERROR service=\$service step=update-service message=\$(printf '%s' "\$update_output" | tr '\n' ' ')"
    errors=1
    continue
  fi

  echo "ECS_START service=\$service result=\$(printf '%s' "\$update_output" | tr '\t' '/' | tr '\n' ' ')"
done < "\$target_file"

exit "\$errors"
EOF

read -r -d '' VERIFY_RDS_SCRIPT <<EOF || true
set -uo pipefail

env_name="${TARGET_ENV}"
region="${REGION}"
target_file="/opt/work/infra/script/\${env_name}/rds/target_db_instance_lists.txt"

while IFS= read -r raw_db || [[ -n "\$raw_db" ]]; do
  db=\$(printf '%s' "\$raw_db" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [[ -n "\$db" ]] || continue
  [[ "\$db" =~ ^# ]] && continue

  status=\$(aws rds describe-db-instances --region "\$region" --db-instance-identifier "\$db" --query 'DBInstances[0].DBInstanceStatus' --output text)
  source_db=\$(aws rds describe-db-instances --region "\$region" --db-instance-identifier "\$db" --query 'DBInstances[0].ReadReplicaSourceDBInstanceIdentifier' --output text)
  replica_count=\$(aws rds describe-db-instances --region "\$region" --db-instance-identifier "\$db" --query 'length(DBInstances[0].ReadReplicaDBInstanceIdentifiers)' --output text)

  if [[ "\$source_db" == "None" ]]; then
    source_db=""
  fi

  if [[ -n "\$source_db" || "\$replica_count" != "0" ]]; then
    echo "RDS_SKIP db=\$db reason=read-replica-topology status=\$status"
    continue
  fi

  if [[ "\$status" == "available" ]]; then
    echo "RDS_READY db=\$db status=\$status"
  else
    echo "RDS_WAIT db=\$db status=\$status"
  fi
done < "\$target_file"
EOF

read -r -d '' VERIFY_ECS_SCRIPT <<EOF || true
set -uo pipefail

env_name="${TARGET_ENV}"
region="${REGION}"
cluster="kpiee-\${env_name}"
target_file="/opt/work/infra/script/\${env_name}/ecs/target_service_lists.txt"

while IFS= read -r raw_service || [[ -n "\$raw_service" ]]; do
  service=\$(printf '%s' "\$raw_service" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [[ -n "\$service" ]] || continue
  [[ "\$service" =~ ^# ]] && continue

  desired=\$(aws ecs describe-services --region "\$region" --cluster "\$cluster" --services "\$service" --query 'services[0].desiredCount' --output text)
  running=\$(aws ecs describe-services --region "\$region" --cluster "\$cluster" --services "\$service" --query 'services[0].runningCount' --output text)
  pending=\$(aws ecs describe-services --region "\$region" --cluster "\$cluster" --services "\$service" --query 'services[0].pendingCount' --output text)

  if [[ "\$desired" =~ ^[0-9]+$ && "\$running" =~ ^[0-9]+$ && "\$desired" == "1" && "\$pending" == "0" && "\$running" -ge "\$desired" ]]; then
    echo "ECS_READY service=\$service desired=\$desired running=\$running pending=\$pending"
  else
    echo "ECS_WAIT service=\$service desired=\$desired running=\$running pending=\$pending"
  fi
done < "\$target_file"
EOF

inspect_json="$(run_remote_script "inspect ${TARGET_ENV} targets" readonly "$INSPECT_TARGETS_SCRIPT")"
ensure_success "inspect-targets" "$inspect_json"
print_json_result "inspect-targets" "$inspect_json"

rds_start_json="$(run_remote_script "start ${TARGET_ENV} rds" force "$START_RDS_SCRIPT")"
ensure_success "start-rds" "$rds_start_json"
print_json_result "start-rds" "$rds_start_json"

ecs_start_json="$(run_remote_script "start ${TARGET_ENV} ecs" force "$START_ECS_SCRIPT")"
ensure_success "start-ecs" "$ecs_start_json"
print_json_result "start-ecs" "$ecs_start_json"

deadline_epoch=$(( $(date +%s) + WAIT_SECONDS ))
attempt=1

while true; do
  rds_verify_json="$(run_remote_script "verify ${TARGET_ENV} rds" readonly "$VERIFY_RDS_SCRIPT")"
  ensure_success "verify-rds-attempt-${attempt}" "$rds_verify_json"

  ecs_verify_json="$(run_remote_script "verify ${TARGET_ENV} ecs" readonly "$VERIFY_ECS_SCRIPT")"
  ensure_success "verify-ecs-attempt-${attempt}" "$ecs_verify_json"

  print_json_result "verify-rds-attempt-${attempt}" "$rds_verify_json"
  print_json_result "verify-ecs-attempt-${attempt}" "$ecs_verify_json"

  wait_count=$(( $(count_wait_lines "$rds_verify_json") + $(count_wait_lines "$ecs_verify_json") ))
  if [[ "$wait_count" -eq 0 ]]; then
    echo "start_env_via_bastion_ssm: verification completed successfully."
    exit 0
  fi

  if [[ "$(date +%s)" -ge "$deadline_epoch" ]]; then
    echo "start_env_via_bastion_ssm: verification timed out with ${wait_count} pending resources." >&2
    exit 1
  fi

  echo "pending_resources=${wait_count}; sleep ${POLL_INTERVAL_SECONDS}s before retry"
  echo
  sleep "$POLL_INTERVAL_SECONDS"
  attempt=$((attempt + 1))
done
