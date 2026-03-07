#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 2 || "$#" -gt 3 ]]; then
  echo "usage: $0 <cluster> <service> [region]" >&2
  exit 1
fi

CLUSTER="$1"
SERVICE="$2"

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

REGION="${3:-$(resolve_region)}"

for c in aws jq; do
  if ! command -v "$c" >/dev/null 2>&1; then
    echo "command not found: $c" >&2
    exit 1
  fi
done

task_arns_json="$(aws ecs list-tasks \
  --region "$REGION" \
  --cluster "$CLUSTER" \
  --service-name "$SERVICE" \
  --desired-status RUNNING \
  --output json)"

if [[ "$(echo "$task_arns_json" | jq '.taskArns | length')" -eq 0 ]]; then
  echo "No running tasks found for cluster=${CLUSTER} service=${SERVICE}" >&2
  exit 0
fi

mapfile -t task_arns < <(echo "$task_arns_json" | jq -r '.taskArns[]')

aws ecs describe-tasks \
  --region "$REGION" \
  --cluster "$CLUSTER" \
  --tasks "${task_arns[@]}" \
  --output json \
  | jq -r '
    .tasks[]
    | {
        task_id: (.taskArn | split("/") | last),
        last_status: (.lastStatus // ""),
        desired_status: (.desiredStatus // ""),
        started_at: (.startedAt // ""),
        containers: ((.containers // []) | map(.name) | join(",")),
        task_definition: (.taskDefinitionArn | split("/") | last)
      }
    | @json
  '
