#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION:-us-west-2}"

missing=0
for c in aws gh jq session-manager-plugin; do
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
