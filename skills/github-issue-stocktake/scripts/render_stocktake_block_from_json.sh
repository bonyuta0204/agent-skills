#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  render_stocktake_block_from_json.sh \
    --json-file <path> \
    --issue <issue-number> \
    --out-file <path>

Description:
  Render AI_STOCKTAKE markdown block for one issue from worker report JSON.
USAGE
}

JSON_FILE=""
ISSUE=""
OUT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json-file)
      JSON_FILE="$2"
      shift 2
      ;;
    --issue)
      ISSUE="$2"
      shift 2
      ;;
    --out-file)
      OUT_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$JSON_FILE" || -z "$ISSUE" || -z "$OUT_FILE" ]]; then
  usage >&2
  exit 1
fi

if [[ ! -f "$JSON_FILE" ]]; then
  echo "json file not found: $JSON_FILE" >&2
  exit 1
fi

if ! jq -e . "$JSON_FILE" >/dev/null 2>&1; then
  echo "invalid JSON: $JSON_FILE" >&2
  exit 1
fi

matches="$(jq -r --arg issue "$ISSUE" '[.results[] | select((.issue_number|tostring) == $issue)] | length' "$JSON_FILE")"
if [[ "$matches" -eq 0 ]]; then
  echo "issue not found in results: $ISSUE" >&2
  exit 1
fi
if [[ "$matches" -gt 1 ]]; then
  echo "multiple results matched issue: $ISSUE" >&2
  exit 1
fi

tmp_result="$(mktemp)"
trap 'rm -f "$tmp_result"' EXIT
jq -c --arg issue "$ISSUE" '.results[] | select((.issue_number|tostring) == $issue)' "$JSON_FILE" > "$tmp_result"

classification="$(jq -r '.classification' "$tmp_result")"
confidence="$(jq -r '.confidence' "$tmp_result")"
summary="$(jq -r '.summary' "$tmp_result")"
gap="$(jq -r '.gap_analysis' "$tmp_result")"

classification_label=""
case "$classification" in
  CLOSE_DONE)
    classification_label="クローズ可（解消）"
    ;;
  CLOSE_DUPLICATE)
    classification_label="クローズ可（重複）"
    ;;
  AI_FIXABLE)
    classification_label="AI改修可能"
    ;;
  HUMAN_SPEC_REQUIRED)
    classification_label="要仕様確認"
    ;;
  HUMAN_REPRO_REQUIRED)
    classification_label="要再現確認"
    ;;
  HUMAN_CONTEXT_REQUIRED)
    classification_label="要起票者確認"
    ;;
  *)
    echo "unknown classification: $classification" >&2
    exit 1
    ;;
esac

{
  echo "<!-- AI_STOCKTAKE_START -->"
  echo "## AI_STOCKTAKE"
  echo
  echo "### 分類"
  echo "- ${classification_label} (\`${classification}\`)"
  echo
  echo "### 判断信頼度"
  printf -- '- %.2f\n' "$confidence"
  echo
  echo "### 要約"
  echo "- ${summary}"
  echo
  echo "### 根拠"
  echo "- 再現結果:"
  jq -r '.evidence.repro_notes' "$tmp_result" | sed 's/^/  /'
  echo "- 実装確認:"
  jq -r '.evidence.implementation_refs[]?' "$tmp_result" | sed 's/^/  - /'
  echo "- 仕様確認:"
  jq -r '.evidence.spec_refs[]?' "$tmp_result" | sed 's/^/  - /'
  echo
  echo "### 差分 / ギャップ"
  echo "- ${gap}"

  if [[ "$classification" == "AI_FIXABLE" ]]; then
    echo
    echo "### 改修方針（\`AI_FIXABLE\` のとき）"
    jq -r '.suspected_root_cause' "$tmp_result" | sed 's/^/- /'
    echo
    echo "### 改修エージェント入力（\`AI_FIXABLE\` のとき）"
    echo "- 原因候補 (\`suspected_root_cause\`):"
    jq -r '.suspected_root_cause' "$tmp_result" | sed 's/^/  /'
    echo "- 再現手順 (\`reproduction_steps\`):"
    jq -r '.reproduction_steps[]?' "$tmp_result" | sed 's/^/  - /'
    echo "- 期待挙動 (\`expected_behavior\`):"
    jq -r '.expected_behavior[]?' "$tmp_result" | sed 's/^/  - /'
    echo "- 影響ファイル (\`affected_files\`):"
    jq -r '.affected_files[]?' "$tmp_result" | sed 's/^/  - /'
    echo "- テスト方針 (\`test_plan\`):"
    jq -r '.test_plan[]?' "$tmp_result" | sed 's/^/  - /'
  fi

  if [[ "$classification" == "CLOSE_DUPLICATE" ]]; then
    echo
    echo "### 重複集約先"
    echo "- #$(jq -r '.duplicate_of_issue' "$tmp_result")"
  fi

  if [[ "$classification" == HUMAN_* ]]; then
    echo
    echo "### 人間アクション（\`HUMAN_*\` のとき）"
    echo "- 依頼先: $(jq -r '.human_action_owner' "$tmp_result")"
    echo "- 次アクション種別: \`$(jq -r '.human_next_action_type' "$tmp_result")\`"
    echo "- 確認事項:"
    jq -r '.human_action_items[]?' "$tmp_result" | sed 's/^/  - /'
  fi

  echo
  echo "<!-- AI_STOCKTAKE_END -->"
} > "$OUT_FILE"

echo "rendered: $OUT_FILE"
