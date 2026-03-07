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
  --bastion-instance <instance>   SSM-managed EC2 instance ID
  --discover-bastion              Heuristically choose a bastion if none is provided
  --defaults-file <path>          MySQL defaults file path on bastion
  --region <region>               AWS region (default: AWS_REGION or aws configure region)
  --force                         Allow non-read-only SQL
  -h, --help                      Show this help

env fallbacks:
  AWS_REGION, RDS_INSTANCE_ID, MYSQL_HOST, MYSQL_PORT, MYSQL_DATABASE,
  MYSQL_USER, BASTION_INSTANCE_ID, MYSQL_DEFAULTS_FILE
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

discover_bastion_instance() {
  local region="$1"
  local online_ids
  online_ids="$(aws ssm describe-instance-information \
    --region "$region" \
    --output json \
    | jq -r '.InstanceInformationList[] | select(.PingStatus == "Online" and .ResourceType == "EC2") | .InstanceId')"

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

sql_arg=""
sql_file=""
region="$(resolve_region)"
rds_instance="${RDS_INSTANCE_ID:-}"
mysql_host="${MYSQL_HOST:-}"
mysql_port="${MYSQL_PORT:-3306}"
mysql_database="${MYSQL_DATABASE:-}"
mysql_user="${MYSQL_USER:-}"
bastion_instance="${BASTION_INSTANCE_ID:-}"
mysql_defaults_file="${MYSQL_DEFAULTS_FILE:-}"
force=0
discover_bastion=0

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

if [[ -z "$bastion_instance" && "$discover_bastion" -eq 1 ]]; then
  bastion_instance="$(discover_bastion_instance "$region")"
fi

if [[ -z "$bastion_instance" ]]; then
  echo "Bastion instance is required. Set --bastion-instance or opt in to --discover-bastion." >&2
  exit 1
fi

if [[ "$force" -ne 1 ]]; then
  if ! is_likely_read_only_sql "$sql_arg"; then
    echo "Blocked potentially mutating SQL. Re-run with --force only when intentional." >&2
    exit 1
  fi
fi

sql_b64="$(printf '%s' "$sql_arg" | base64 | tr -d '\n')"
sql_b64_esc="$(printf '%q' "$sql_b64")"
host_esc="$(printf '%q' "$mysql_host")"
port_esc="$(printf '%q' "$mysql_port")"
db_esc="$(printf '%q' "$mysql_database")"

mysql_cmd="mysql"
if [[ -n "$mysql_defaults_file" ]]; then
  defaults_esc="$(printf '%q' "$mysql_defaults_file")"
  mysql_cmd+=" --defaults-extra-file=${defaults_esc}"
fi
mysql_cmd+=" --batch --raw"
mysql_cmd+=" --host=${host_esc} --port=${port_esc}"
if [[ -n "$mysql_user" ]]; then
  user_esc="$(printf '%q' "$mysql_user")"
  mysql_cmd+=" --user=${user_esc}"
fi
mysql_cmd+=" ${db_esc}"

remote_cmd="set -euo pipefail; tmp_sql=\$(mktemp /tmp/codex-mysql-XXXXXX.sql); trap 'rm -f \"\$tmp_sql\"' EXIT; printf %s ${sql_b64_esc} | base64 -d > \"\$tmp_sql\"; ${mysql_cmd} < \"\$tmp_sql\""

payload="$(jq -cn --arg cmd "$remote_cmd" '{commands: [$cmd]}')"

command_id="$(aws ssm send-command \
  --region "$region" \
  --instance-ids "$bastion_instance" \
  --document-name AWS-RunShellScript \
  --comment "codex mysql query via bastion" \
  --parameters "$payload" \
  --query 'Command.CommandId' \
  --output text)"

aws ssm wait command-executed \
  --region "$region" \
  --command-id "$command_id" \
  --instance-id "$bastion_instance" || true

invocation_json="$(aws ssm get-command-invocation \
  --region "$region" \
  --command-id "$command_id" \
  --instance-id "$bastion_instance" \
  --output json)"

status="$(echo "$invocation_json" | jq -r '.Status')"
stdout="$(echo "$invocation_json" | jq -r '.StandardOutputContent // ""')"
stderr="$(echo "$invocation_json" | jq -r '.StandardErrorContent // ""')"

echo "[route] region=${region} bastion=${bastion_instance} host=${mysql_host} port=${mysql_port} db=${mysql_database}" >&2
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
