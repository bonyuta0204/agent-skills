#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage:
  run_command_via_bastion_ssm.sh [options]

options:
  --cmd <command>                Single shell command to run on bastion
  --script-file <path>           Local shell script to upload and run on bastion
  --bastion-instance <instance>  Explicit SSM-managed EC2 instance ID
  --discover-bastion             Skip default bastion and resolve by heuristic first
  --region <region>              AWS region (default: AWS_REGION or aws configure region)
  --comment <text>               SSM command comment
  --timeout-seconds <seconds>    SSM command timeout (default: 600)
  --force                        Allow commands that look write/destructive
  -h, --help                     Show this help

env fallbacks:
  AWS_REGION, BASTION_INSTANCE_ID, DEFAULT_BASTION_NAME
USAGE
}

require_cmd() {
  local c="$1"
  command -v "$c" >/dev/null 2>&1 || {
    echo "command not found: $c" >&2
    exit 1
  }
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

  echo "AWS region is not set. Export AWS_REGION or configure aws region." >&2
  exit 1
}

is_likely_read_only_shell() {
  local src="$1"
  local lowered
  lowered="$(printf '%s' "$src" | tr '\n' ' ' | tr '[:upper:]' '[:lower:]')"

  if printf '%s' "$lowered" | grep -Eiq '(^|[;&|[:space:]])(sudo|rm|mv|cp|mkdir|rmdir|touch|chmod|chown|ln|install|dd|truncate|kill|pkill|killall|systemctl|service)[[:space:]]'; then
    return 1
  fi

  if printf '%s' "$lowered" | grep -Eiq '(^|[;&|[:space:]])(sed[[:space:]]+-i|perl[[:space:]]+-pi)\b'; then
    return 1
  fi

  if printf '%s' "$lowered" | grep -Eq '(^|[^<])>>?|2>|&>'; then
    return 1
  fi

  if printf '%s' "$lowered" | grep -Eiq '/opt/work/infra/script/.*/(restart|stop)_(ecs|rds|ec2)\.sh\b'; then
    return 1
  fi

  if printf '%s' "$lowered" | grep -Eiq '\b(aws[[:space:]]+ecs[[:space:]]+update-service|aws[[:space:]]+rds[[:space:]]+(start-db-instance|stop-db-instance)|aws[[:space:]]+ec2[[:space:]]+(start-instances|stop-instances))\b'; then
    return 1
  fi

  return 0
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
    echo ""
    return 0
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
    echo ""
    return 0
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

run_ssm_script() {
  local region="$1"
  local bastion_instance="$2"
  local comment="$3"
  local timeout_seconds="$4"
  local script_body="$5"

  local script_b64 script_b64_esc remote_cmd payload command_id invocation_json
  script_b64="$(printf '%s' "$script_body" | base64 | tr -d '\n')"
  script_b64_esc="$(printf '%q' "$script_b64")"

  remote_cmd="set -euo pipefail; tmp_script=\$(mktemp /tmp/codex-bastion-XXXXXX.sh); trap 'rm -f \"\$tmp_script\"' EXIT; printf %s ${script_b64_esc} | base64 -d > \"\$tmp_script\"; chmod +x \"\$tmp_script\"; bash \"\$tmp_script\""
  payload="$(jq -cn --arg cmd "$remote_cmd" '{commands: [$cmd]}')"

  if ! command_id="$(aws ssm send-command \
    --region "$region" \
    --instance-ids "$bastion_instance" \
    --document-name AWS-RunShellScript \
    --comment "$comment" \
    --timeout-seconds "$timeout_seconds" \
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

require_cmd aws
require_cmd jq

DEFAULT_BASTION_NAME="${DEFAULT_BASTION_NAME:-kpiee-infra-dev}"
region="$(resolve_region)"
script_body=""
script_file=""
bastion_instance="${BASTION_INSTANCE_ID:-}"
discover_bastion=0
force=0
comment="codex bastion command"
timeout_seconds=600
selected_route=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --cmd)
      script_body="${2:-}"
      shift 2
      ;;
    --script-file)
      script_file="${2:-}"
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
    --region)
      region="${2:-}"
      shift 2
      ;;
    --comment)
      comment="${2:-}"
      shift 2
      ;;
    --timeout-seconds)
      timeout_seconds="${2:-}"
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
      echo "unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -n "$script_body" && -n "$script_file" ]]; then
  echo "Use either --cmd or --script-file." >&2
  exit 1
fi

if [[ -z "$script_body" && -z "$script_file" ]]; then
  echo "Either --cmd or --script-file is required." >&2
  exit 1
fi

if [[ -n "$script_file" ]]; then
  [[ -f "$script_file" ]] || {
    echo "script file not found: $script_file" >&2
    exit 1
  }
  script_body="$(cat "$script_file")"
fi

if [[ "$force" -ne 1 ]] && ! is_likely_read_only_shell "$script_body"; then
  echo "Command looks write/destructive. Re-run with --force if intentional." >&2
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
    selected_route="discovered"
  fi
fi

if [[ -z "$bastion_instance" ]]; then
  echo "Failed to resolve bastion instance. Set --bastion-instance or use --discover-bastion." >&2
  exit 1
fi

result_json="$(run_ssm_script \
  "$region" \
  "$bastion_instance" \
  "$comment" \
  "$timeout_seconds" \
  "$script_body")"

status="$(echo "$result_json" | jq -r '.status')"
if [[ "$status" != "Success" && "$selected_route" == "default:${DEFAULT_BASTION_NAME}" ]]; then
  fallback_bastion="$(discover_bastion_instance "$region")"
  if [[ -n "$fallback_bastion" && "$fallback_bastion" != "$bastion_instance" ]]; then
    echo "[route] default bastion ${bastion_instance} failed; retrying with discovered bastion ${fallback_bastion}" >&2
    bastion_instance="$fallback_bastion"
    selected_route="discovered-after-default-failure"
    result_json="$(run_ssm_script \
      "$region" \
      "$bastion_instance" \
      "$comment" \
      "$timeout_seconds" \
      "$script_body")"
  fi
fi

echo "[route] type=${selected_route} region=${region} bastion=${bastion_instance}" >&2

echo "$result_json" | jq -c --arg route_type "$selected_route" --arg region "$region" '
  . + {
    route_type: $route_type,
    region: $region
  }
'
