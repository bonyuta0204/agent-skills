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

  return 1
}

missing=0
for c in aws jq python3 session-manager-plugin; do
  if command -v "$c" >/dev/null 2>&1; then
    echo "cmd:$c OK"
  else
    echo "cmd:$c NG"
    missing=1
  fi
done

for c in snow; do
  if command -v "$c" >/dev/null 2>&1; then
    echo "cmd:$c optional:OK"
  else
    echo "cmd:$c optional:NG"
  fi
done

if [[ "$missing" -ne 0 ]]; then
  echo "Missing required commands." >&2
  exit 1
fi

if REGION="$(resolve_region)"; then
  echo "region:${REGION}"
else
  echo "region:NG" >&2
  echo "Set AWS_REGION or configure an AWS CLI default region." >&2
  exit 1
fi

aws --version
aws sts get-caller-identity --output json >/dev/null
echo "aws-auth:OK"
