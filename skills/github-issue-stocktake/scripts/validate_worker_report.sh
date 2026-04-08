#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  validate_worker_report.sh --json-file <path> [--confidence-threshold <0..1>]

Description:
  Validate worker report JSON for github-issue-stocktake PM workflow.
USAGE
}

JSON_FILE=""
CONFIDENCE_THRESHOLD="0.75"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json-file)
      JSON_FILE="$2"
      shift 2
      ;;
    --confidence-threshold)
      CONFIDENCE_THRESHOLD="$2"
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

if [[ -z "$JSON_FILE" ]]; then
  usage >&2
  exit 1
fi

if [[ ! -f "$JSON_FILE" ]]; then
  echo "json file not found: $JSON_FILE" >&2
  exit 1
fi

if ! [[ "$CONFIDENCE_THRESHOLD" =~ ^0(\.[0-9]+)?$|^1(\.0+)?$ ]]; then
  echo "invalid --confidence-threshold: $CONFIDENCE_THRESHOLD" >&2
  exit 1
fi

if ! jq -e . "$JSON_FILE" >/dev/null 2>&1; then
  echo "invalid JSON: $JSON_FILE" >&2
  exit 1
fi

errors="$(
  jq -r --argjson threshold "$CONFIDENCE_THRESHOLD" '
    def is_nonempty_string($v):
      ($v | type == "string") and (($v | gsub("\\s+"; "") | length) > 0);
    def is_nonempty_string_array($v):
      ($v | type == "array") and (($v | length) > 0) and all($v[]; is_nonempty_string(.));
    def valid_classification($v):
      $v == "CLOSE_DONE" or
      $v == "AI_FIXABLE" or
      $v == "HUMAN_SPEC_REQUIRED" or
      $v == "HUMAN_REPRO_REQUIRED" or
      $v == "HUMAN_CONTEXT_REQUIRED";
    def valid_human_next_action_type($v):
      $v == "ANSWER_SPEC_QUESTION" or
      $v == "PROVIDE_REPRO_STEPS" or
      $v == "PROVIDE_BUSINESS_CONTEXT" or
      $v == "MAKE_SCOPE_DECISION" or
      $v == "ROUTE_TO_OWNER";
    def issue_number_ok($r):
      (($r.issue_number | type) == "number") or is_nonempty_string($r.issue_number);
    def string_array($v):
      ($v | type == "array") and all($v[]?; (. | type) == "string");
    def evidence_ok($r):
      (($r.evidence | type) == "object") and
      is_nonempty_string_array($r.evidence.implementation_refs) and
      string_array($r.evidence.spec_refs) and
      is_nonempty_string($r.evidence.repro_notes);
    def base_ok($r):
      issue_number_ok($r) and
      valid_classification($r.classification) and
      (($r.confidence | type) == "number") and ($r.confidence >= 0) and ($r.confidence <= 1) and
      is_nonempty_string($r.summary) and
      is_nonempty_string($r.gap_analysis) and
      evidence_ok($r);
    def ai_fixable_ok($r):
      is_nonempty_string($r.suspected_root_cause) and
      is_nonempty_string_array($r.reproduction_steps) and
      is_nonempty_string_array($r.expected_behavior) and
      is_nonempty_string_array($r.affected_files) and
      is_nonempty_string_array($r.test_plan);
    def human_ok($r):
      is_nonempty_string($r.human_action_owner) and
      valid_human_next_action_type($r.human_next_action_type) and
      is_nonempty_string_array($r.human_action_items);
    def check_result($idx; $r; $threshold):
      if (base_ok($r) | not) then
        "results[\($idx)] missing or invalid base fields"
      elif ($r.classification == "AI_FIXABLE") and (ai_fixable_ok($r) | not) then
        "results[\($idx)] missing AI_FIXABLE required fields"
      elif (($r.classification | startswith("HUMAN_")) and (human_ok($r) | not)) then
        "results[\($idx)] missing HUMAN_* required fields"
      elif ($r.classification == "AI_FIXABLE") and ($r.confidence < $threshold) then
        "results[\($idx)] AI_FIXABLE confidence(\($r.confidence)) is below threshold(\($threshold))"
      else
        empty
      end
    ;

    . as $root |
    (
      []
      + (if is_nonempty_string($root.task_id) then [] else ["missing task_id"] end)
      + (if ($root.task_mode == "single_issue")
         then []
         else ["missing or invalid task_mode"]
         end)
      + (if (($root.results | type) == "array" and ($root.results | length) > 0)
         then []
         else ["results must be a non-empty array"]
         end)
      + (if (($root.results | type) == "array")
         then [ $root.results | to_entries[] | check_result(.key; .value; $threshold) ] | map(select(. != ""))
         else []
         end)
    )[] 
  ' "$JSON_FILE"
)"

if [[ -n "$errors" ]]; then
  echo "validation failed:"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    echo "- $line"
  done <<< "$errors"
  exit 1
fi

echo "OK"
