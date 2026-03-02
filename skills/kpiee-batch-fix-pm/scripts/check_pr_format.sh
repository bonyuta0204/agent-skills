#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  check_pr_format.sh --repo <owner/repo> --pr <number> --id <implementation_id> \
    [--base <expected_base_branch>] [--milestone <expected_milestone>]
USAGE
}

REPO=""
PR=""
ID=""
EXPECTED_BASE=""
EXPECTED_MILESTONE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --pr) PR="$2"; shift 2 ;;
    --id) ID="$2"; shift 2 ;;
    --base) EXPECTED_BASE="$2"; shift 2 ;;
    --milestone) EXPECTED_MILESTONE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$REPO" || -z "$PR" || -z "$ID" ]]; then
  usage >&2
  exit 1
fi

json="$(gh pr view "$PR" --repo "$REPO" --json title,body,baseRefName,milestone,url)"
title="$(echo "$json" | jq -r '.title')"
body="$(echo "$json" | jq -r '.body // ""')"
base_ref="$(echo "$json" | jq -r '.baseRefName')"
milestone="$(echo "$json" | jq -r '.milestone.title // ""')"
url="$(echo "$json" | jq -r '.url')"

failed=0
check() {
  local ok="$1"
  local message="$2"
  if [[ "$ok" == "1" ]]; then
    echo "[PASS] $message"
  else
    echo "[FAIL] $message"
    failed=1
  fi
}

if [[ "$title" =~ ^\[$ID\][[:space:]].+ ]]; then
  check 1 "title prefix matches [$ID]"
else
  check 0 "title prefix must start with [$ID]"
fi

if [[ -n "$EXPECTED_BASE" ]]; then
  if [[ "$base_ref" == "$EXPECTED_BASE" ]]; then
    check 1 "base branch is $EXPECTED_BASE"
  else
    check 0 "base branch mismatch (expected=$EXPECTED_BASE actual=$base_ref)"
  fi
else
  check 1 "base branch check skipped"
fi

if [[ -n "$milestone" ]]; then
  check 1 "milestone is set ($milestone)"
else
  check 0 "milestone is not set"
fi

if [[ -n "$EXPECTED_MILESTONE" ]]; then
  if [[ "$milestone" == "$EXPECTED_MILESTONE" ]]; then
    check 1 "milestone matches expected ($EXPECTED_MILESTONE)"
  else
    check 0 "milestone mismatch (expected=$EXPECTED_MILESTONE actual=$milestone)"
  fi
fi

required_headers=(
  "## 開発対象一覧ID または NG一覧ID | タイトル"
  "## INPUT"
  "## 対応内容"
  "### 事象"
  "### 原因"
  "### 解消方針"
  "## 動作確認"
  "## 影響範囲調査"
  "## 類似欠陥調査"
)

for h in "${required_headers[@]}"; do
  if printf '%s' "$body" | rg -q --fixed-strings "$h"; then
    check 1 "body contains header: $h"
  else
    check 0 "body missing header: $h"
  fi
done

if printf '%s' "$body" | rg -q 'https://github\.com/.+/.+/issues/[0-9]+'; then
  check 1 "body includes issue link"
else
  check 0 "body missing issue link"
fi

echo "PR: $url"
if [[ "$failed" -eq 1 ]]; then
  exit 1
fi

