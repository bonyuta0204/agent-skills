#!/usr/bin/env bash
set -euo pipefail

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

missing=0
for c in aws jq session-manager-plugin; do
  if command -v "$c" >/dev/null 2>&1; then
    echo "cmd:$c OK"
  else
    echo "cmd:$c NG"
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  echo "Missing required commands." >&2
  exit 1
fi

echo "region:${REGION}"
aws --version
aws sts get-caller-identity --output json >/dev/null
echo "aws-auth:OK"
