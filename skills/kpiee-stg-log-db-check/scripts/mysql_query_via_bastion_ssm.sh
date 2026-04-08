#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage:
  mysql_query_via_bastion_ssm.sh [options]

options:
  --sql <sql>                     SQL string to run
  --sql-file <path>               SQL file to run
  --rds-instance <identifier>     Resolve DB host from RDS instance identifier
  --host <endpoint>               DB endpoint (if not using --rds-instance)
  --port <port>                   DB port (default: 3306)
  --database <name>               Database name
  --user <name>                   MySQL user (optional)
  --password <value>              MySQL password (prefer MYSQL_PASSWORD env)
  --bastion-instance <instance>   SSM-managed EC2 instance ID
  --discover-bastion              Force heuristic bastion discovery first
  --defaults-file <path>          MySQL defaults file path on bastion
  --region <region>               AWS region (default: AWS_REGION or aws configure region)
  --force                         Allow non-read-only SQL
  -h, --help                      Show this help

env fallbacks:
  AWS_REGION, RDS_INSTANCE_ID, MYSQL_HOST, MYSQL_PORT, MYSQL_DATABASE,
  MYSQL_USER, MYSQL_PASSWORD, BASTION_INSTANCE_ID, MYSQL_DEFAULTS_FILE
USAGE
}

require_cmd() {
  local c="$1"
  command -v "$c" >/dev/null 2>&1 || { echo "command not found: $c" >&2; exit 1; }
}

is_likely_read_only_sql() {
  local sql="$1"
  local lowered
  lowered="$(printf '%s' "$sql" | tr '\n' ' ' | tr '[:upper:]' '[:lower:]')"

  # Reject obvious write/admin statements. Conservative by design.
  if printf '%s' "$lowered" | grep -Eiq '\b(insert|update|delete|replace|alter|drop|truncate|create|rename|grant|revoke|lock|unlock|analyze|optimize|repair|call)\b'; then
    return 1
  fi

  return 0
}

DEFAULT_BASTION_NAME="${DEFAULT_BASTION_NAME:-kpiee-infra-dev}"

resolve_region() {
  if [[ -n "${AWS_REGION:-}" ]]; then
    printf '%s\n' "$AWS_REGION"
    return 0
  fi

  if ! command -v aws >/dev/null 2>&1; then
    echo "aws command not found and AWS_REGION is not set" >&2
    exit 1
  fi

  local configured
  configured="$(aws configure get region 2>/dev/null || true)"
  if [[ -n "$configured" ]]; then
    printf '%s\n' "$configured"
    return 0
  fi

  echo "AWS region is not set. Export AWS_REGION or configure aws region." >&2
  exit 1
}

resolve_named_bastion_instance() {
  local region="$1"
  local name="$2"
  local online_ids
  online_ids="$(aws ssm describe-instance-information \
    --region "$region" \
    --output json \
    | jq -r '.InstanceInformationList[] | select(.PingStatus == "Online" and (.ResourceType | startswith("EC2"))) | .InstanceId')"

  if [[ -z "$online_ids" ]]; then
    echo "" && return 0
  fi

  # shellcheck disable=SC2206
  local ids=( $online_ids )
  local ec2_json
  ec2_json="$(aws ec2 describe-instances --region "$region" --instance-ids "${ids[@]}" --output json)"

  echo "$ec2_json" | jq -r --arg name "$name" '
    [
      .Reservations[].Instances[]
      | {
          id: .InstanceId,
          state: .State.Name,
          name: ((.Tags // [] | map(select(.Key == "Name") | .Value) | .[0]) // "")
        }
      | select(.state == "running" and .name == $name)
    ]
    | .[0].id // ""
  '
}

discover_bastion_instance() {
  local region="$1"
  local online_ids
  online_ids="$(aws ssm describe-instance-information \
    --region "$region" \
    --output json \
    | jq -r '.InstanceInformationList[] | select(.PingStatus == "Online" and (.ResourceType | startswith("EC2"))) | .InstanceId')"

  if [[ -z "$online_ids" ]]; then
    echo "" && return 0
  fi

  # shellcheck disable=SC2206
  local ids=( $online_ids )
  local ec2_json
  ec2_json="$(aws ec2 describe-instances --region "$region" --instance-ids "${ids[@]}" --output json)"

  echo "$ec2_json" | jq -r '
    [
      .Reservations[].Instances[]
      | {
          id: .InstanceId,
          state: .State.Name,
          name: ((.Tags // [] | map(select(.Key == "Name") | .Value) | .[0]) // "")
        }
      | select(.state == "running")
    ]
    | sort_by((.name | test("(?i)(bastion|jump|infra|ops|admin)") | not), .name, .id)
    | .[0].id // ""
  '
}

run_ssm_mysql_query() {
  local region="$1"
  local bastion_instance="$2"
  local mysql_host="$3"
  local mysql_port="$4"
  local mysql_database="$5"
  local mysql_user="$6"
  local mysql_password="$7"
  local mysql_defaults_file="$8"
  local sql_arg="$9"

  local sql_b64 sql_b64_esc host_esc port_esc db_esc mysql_cmd remote_cmd payload command_id invocation_json
  local password_b64="" password_b64_esc="" use_temp_defaults=0
  sql_b64="$(printf '%s' "$sql_arg" | base64 | tr -d '\n')"
  sql_b64_esc="$(printf '%q' "$sql_b64")"
  host_esc="$(printf '%q' "$mysql_host")"
  port_esc="$(printf '%q' "$mysql_port")"
  db_esc="$(printf '%q' "$mysql_database")"

  if [[ -n "$mysql_password" && -z "$mysql_defaults_file" ]]; then
    password_b64="$(printf '%s' "$mysql_password" | base64 | tr -d '\n')"
    password_b64_esc="$(printf '%q' "$password_b64")"
    use_temp_defaults=1
  fi

  mysql_cmd="mysql"
  if [[ "$use_temp_defaults" -eq 1 ]]; then
    mysql_cmd+=" --defaults-extra-file=\"\$tmp_defaults\""
  elif [[ -n "$mysql_defaults_file" ]]; then
    local defaults_esc
    defaults_esc="$(printf '%q' "$mysql_defaults_file")"
    mysql_cmd+=" --defaults-extra-file=${defaults_esc}"
  fi
  mysql_cmd+=" --batch --raw"
  mysql_cmd+=" --host=${host_esc} --port=${port_esc}"
  if [[ -n "$mysql_user" ]]; then
    local user_esc
    user_esc="$(printf '%q' "$mysql_user")"
    mysql_cmd+=" --user=${user_esc}"
  fi
  mysql_cmd+=" ${db_esc}"

  remote_cmd="set -euo pipefail; tmp_sql=\$(mktemp /tmp/codex-mysql-XXXXXX.sql);"
  if [[ "$use_temp_defaults" -eq 1 ]]; then
    remote_cmd+=" tmp_defaults=\$(mktemp /tmp/codex-mysql-XXXXXX.cnf); trap 'rm -f \"\$tmp_sql\" \"\$tmp_defaults\"' EXIT; chmod 600 \"\$tmp_defaults\"; { printf '[client]\\n'; printf 'password='; printf %s ${password_b64_esc} | base64 -d; printf '\\n'; } > \"\$tmp_defaults\";"
  else
    remote_cmd+=" trap 'rm -f \"\$tmp_sql\"' EXIT;"
  fi
  remote_cmd+=" printf %s ${sql_b64_esc} | base64 -d > \"\$tmp_sql\"; ${mysql_cmd} < \"\$tmp_sql\""
  payload="$(jq -cn --arg cmd "$remote_cmd" '{commands: [$cmd]}')"

  if ! command_id="$(aws ssm send-command \
    --region "$region" \
    --instance-ids "$bastion_instance" \
    --document-name AWS-RunShellScript \
    --comment "codex mysql query via bastion" \
    --parameters "$payload" \
    --query 'Command.CommandId' \
    --output text 2>&1)"; then
    jq -cn \
      --arg bastion "$bastion_instance" \
      --arg command_id "" \
      --arg status "SendCommandFailed" \
      --arg stdout "" \
      --arg stderr "$command_id" \
      '{bastion: $bastion, command_id: $command_id, status: $status, stdout: $stdout, stderr: $stderr}'
    return 0
  fi

  aws ssm wait command-executed \
    --region "$region" \
    --command-id "$command_id" \
    --instance-id "$bastion_instance" || true

  if ! invocation_json="$(aws ssm get-command-invocation \
    --region "$region" \
    --command-id "$command_id" \
    --instance-id "$bastion_instance" \
    --output json 2>&1)"; then
    jq -cn \
      --arg bastion "$bastion_instance" \
      --arg command_id "$command_id" \
      --arg status "GetInvocationFailed" \
      --arg stdout "" \
      --arg stderr "$invocation_json" \
      '{bastion: $bastion, command_id: $command_id, status: $status, stdout: $stdout, stderr: $stderr}'
    return 0
  fi

  jq -cn \
    --arg bastion "$bastion_instance" \
    --arg command_id "$command_id" \
    --arg status "$(echo "$invocation_json" | jq -r '.Status')" \
    --arg stdout "$(echo "$invocation_json" | jq -r '.StandardOutputContent // ""')" \
    --arg stderr "$(echo "$invocation_json" | jq -r '.StandardErrorContent // ""')" \
    '{bastion: $bastion, command_id: $command_id, status: $status, stdout: $stdout, stderr: $stderr}'
}

sql_arg=""
sql_file=""
region="$(resolve_region)"
rds_instance="${RDS_INSTANCE_ID:-}"
mysql_host="${MYSQL_HOST:-}"
mysql_port="${MYSQL_PORT:-3306}"
mysql_database="${MYSQL_DATABASE:-}"
mysql_user="${MYSQL_USER:-}"
mysql_password="${MYSQL_PASSWORD:-}"
bastion_instance="${BASTION_INSTANCE_ID:-}"
mysql_defaults_file="${MYSQL_DEFAULTS_FILE:-}"
force=0
discover_bastion=0
selected_route=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --sql)
      sql_arg="${2:-}"
      shift 2
      ;;
    --sql-file)
      sql_file="${2:-}"
      shift 2
      ;;
    --rds-instance)
      rds_instance="${2:-}"
      shift 2
      ;;
    --host)
      mysql_host="${2:-}"
      shift 2
      ;;
    --port)
      mysql_port="${2:-}"
      shift 2
      ;;
    --database)
      mysql_database="${2:-}"
      shift 2
      ;;
    --user)
      mysql_user="${2:-}"
      shift 2
      ;;
    --password)
      mysql_password="${2:-}"
      shift 2
      ;;
    --bastion-instance)
      bastion_instance="${2:-}"
      shift 2
      ;;
    --discover-bastion)
      discover_bastion=1
      shift
      ;;
    --defaults-file)
      mysql_defaults_file="${2:-}"
      shift 2
      ;;
    --region)
      region="${2:-}"
      shift 2
      ;;
    --force)
      force=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_cmd aws
require_cmd jq

if [[ -n "$sql_arg" && -n "$sql_file" ]]; then
  echo "Specify only one of --sql or --sql-file" >&2
  exit 1
fi

if [[ -n "$sql_file" ]]; then
  if [[ ! -f "$sql_file" ]]; then
    echo "SQL file not found: $sql_file" >&2
    exit 1
  fi
  sql_arg="$(cat "$sql_file")"
fi

if [[ -z "$sql_arg" ]]; then
  echo "--sql or --sql-file is required" >&2
  exit 1
fi

if [[ -z "$mysql_host" && -n "$rds_instance" ]]; then
  mysql_host="$(aws rds describe-db-instances \
    --region "$region" \
    --db-instance-identifier "$rds_instance" \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text)"
fi

if [[ -z "$mysql_host" ]]; then
  echo "DB host is required. Set --host or --rds-instance." >&2
  exit 1
fi

if [[ -z "$mysql_database" ]]; then
  echo "Database name is required. Set --database or MYSQL_DATABASE." >&2
  exit 1
fi

if [[ -n "$bastion_instance" ]]; then
  selected_route="explicit"
elif [[ "$discover_bastion" -eq 1 ]]; then
  bastion_instance="$(discover_bastion_instance "$region")"
  selected_route="discovered"
else
  bastion_instance="$(resolve_named_bastion_instance "$region" "$DEFAULT_BASTION_NAME")"
  if [[ -n "$bastion_instance" ]]; then
    selected_route="default:${DEFAULT_BASTION_NAME}"
  else
    bastion_instance="$(discover_bastion_instance "$region")"
    selected_route="fallback-discovered"
  fi
fi

if [[ -z "$bastion_instance" ]]; then
  echo "Failed to resolve bastion instance. Set --bastion-instance or use --discover-bastion." >&2
  exit 1
fi

if [[ "$force" -ne 1 ]]; then
  if ! is_likely_read_only_sql "$sql_arg"; then
    echo "Blocked potentially mutating SQL. Re-run with --force only when intentional." >&2
    exit 1
  fi
fi

result_json="$(run_ssm_mysql_query \
  "$region" \
  "$bastion_instance" \
  "$mysql_host" \
  "$mysql_port" \
  "$mysql_database" \
  "$mysql_user" \
  "$mysql_password" \
  "$mysql_defaults_file" \
  "$sql_arg")"

status="$(echo "$result_json" | jq -r '.status')"
stdout="$(echo "$result_json" | jq -r '.stdout')"
stderr="$(echo "$result_json" | jq -r '.stderr')"
command_id="$(echo "$result_json" | jq -r '.command_id')"

if [[ "$status" != "Success" && "$selected_route" == "default:${DEFAULT_BASTION_NAME}" ]]; then
  fallback_bastion="$(discover_bastion_instance "$region")"
  if [[ -n "$fallback_bastion" && "$fallback_bastion" != "$bastion_instance" ]]; then
    echo "[route] default bastion ${bastion_instance} failed; retrying with discovered bastion ${fallback_bastion}" >&2
    bastion_instance="$fallback_bastion"
    selected_route="fallback-discovered"
    result_json="$(run_ssm_mysql_query \
      "$region" \
      "$bastion_instance" \
      "$mysql_host" \
      "$mysql_port" \
      "$mysql_database" \
      "$mysql_user" \
      "$mysql_password" \
      "$mysql_defaults_file" \
      "$sql_arg")"
    status="$(echo "$result_json" | jq -r '.status')"
    stdout="$(echo "$result_json" | jq -r '.stdout')"
    stderr="$(echo "$result_json" | jq -r '.stderr')"
    command_id="$(echo "$result_json" | jq -r '.command_id')"
  fi
fi

echo "[route] type=${selected_route} region=${region} bastion=${bastion_instance} host=${mysql_host} port=${mysql_port} db=${mysql_database}" >&2
echo "[ssm] command_id=${command_id} status=${status}" >&2

if [[ -n "$stdout" ]]; then
  printf '%s\n' "$stdout"
fi

if [[ -n "$stderr" ]]; then
  printf '%s\n' "$stderr" >&2
fi

if [[ "$status" != "Success" ]]; then
  exit 1
fi
