#!/usr/bin/env bash
set -euo pipefail

DEFAULT_BASTION_NAME="${DEFAULT_BASTION_NAME:-kpiee-infra-dev}"

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

for cmd in aws jq; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "command not found: $cmd" >&2
    exit 1
  }
done

REGION="${1:-$(resolve_region)}"

mapfile -t instance_ids < <(
  aws ssm describe-instance-information \
    --region "$REGION" \
    --output json \
    | jq -r '.InstanceInformationList[] | select(.PingStatus == "Online" and (.ResourceType | startswith("EC2"))) | .InstanceId'
)

if [[ "${#instance_ids[@]}" -eq 0 ]]; then
  echo "No online EC2 managed instances found in SSM." >&2
  exit 0
fi

aws ec2 describe-instances --region "$REGION" --instance-ids "${instance_ids[@]}" --output json \
  | jq -r --arg default_name "$DEFAULT_BASTION_NAME" '
    [
      .Reservations[].Instances[]
      | {
          instance_id: .InstanceId,
          state: .State.Name,
          name: ((.Tags // [] | map(select(.Key == "Name") | .Value) | .[0]) // ""),
          private_ip: (.PrivateIpAddress // ""),
          vpc_id: (.VpcId // ""),
          subnet_id: (.SubnetId // ""),
          sg_ids: ((.SecurityGroups // []) | map(.GroupId) | join(",")),
          is_default: (((.Tags // [] | map(select(.Key == "Name") | .Value) | .[0]) // "") == $default_name),
          likely_bastion: (((.Tags // [] | map(select(.Key == "Name") | .Value) | join(" ")) | test("(?i)(bastion|jump|infra|ops|admin)")))
        }
    ]
    | sort_by((.is_default | not), (.likely_bastion | not), .name, .instance_id)
    | .[]
    | [
        "instance_id=" + .instance_id,
        "state=" + .state,
        "name=" + .name,
        "is_default=" + (.is_default | tostring),
        "likely_bastion=" + (.likely_bastion | tostring),
        "private_ip=" + .private_ip,
        "vpc_id=" + .vpc_id,
        "subnet_id=" + .subnet_id,
        "sg_ids=" + .sg_ids
      ]
    | join(" ")
  '
