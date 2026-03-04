#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 3 || "$#" -gt 5 ]]; then
  echo "usage: $0 <log_group> <start_utc_iso8601> <end_utc_iso8601> [query_string] [region]" >&2
  exit 1
fi

LOG_GROUP="$1"
START_ISO="$2"
END_ISO="$3"
QUERY_STRING="${4:-fields @timestamp, @logStream, @message | sort @timestamp desc | limit 100}"
REGION="${5:-${AWS_REGION:-us-west-2}}"

to_epoch() {
  python3 - "$1" <<'PY'
import datetime, sys
print(int(datetime.datetime.fromisoformat(sys.argv[1].replace('Z', '+00:00')).timestamp()))
PY
}

START_TS="$(to_epoch "$START_ISO")"
END_TS="$(to_epoch "$END_ISO")"

QID="$(aws logs start-query \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP" \
  --start-time "$START_TS" \
  --end-time "$END_TS" \
  --query-string "$QUERY_STRING" \
  --query queryId \
  --output text)"

STATUS=""
for _ in $(seq 1 30); do
  STATUS="$(aws logs get-query-results --region "$REGION" --query-id "$QID" --query status --output text)"
  if [[ "$STATUS" == "Complete" ]]; then
    break
  fi
  sleep 1
done

if [[ "$STATUS" != "Complete" ]]; then
  echo "query status: $STATUS" >&2
fi

aws logs get-query-results --region "$REGION" --query-id "$QID" --output json \
  | jq -r '.results[] | (map({(.field): .value}) | add) | "[" + (."@timestamp" // "") + "] [" + (."@logStream" // "") + "] " + (."@message" // "")'
