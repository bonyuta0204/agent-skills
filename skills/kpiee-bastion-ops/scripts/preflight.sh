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

  echo ""
}

required_cmds=(aws jq python3 session-manager-plugin)
optional_cmds=(mysql nc dig)

echo "== Required commands =="
for cmd in "${required_cmds[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "ok  $cmd -> $(command -v "$cmd")"
  else
    echo "ng  $cmd"
    exit 1
  fi
done

echo
echo "== Optional commands =="
for cmd in "${optional_cmds[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "ok  $cmd -> $(command -v "$cmd")"
  else
    echo "skip $cmd"
  fi
done

echo
echo "== AWS identity =="
aws sts get-caller-identity --output json

echo
echo "== Effective region =="
region="$(resolve_region)"
if [[ -n "$region" ]]; then
  echo "$region"
else
  echo "AWS region is not set. Export AWS_REGION or configure aws region." >&2
  exit 1
fi
