#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage:
  count_dx_account_table_rows.sh --env <it|stg|stg01|stg02> --table <table> [options]

options:
  --env <name>                    Target env: it, stg, stg01, stg02
  --table <name>                  Table name to count per dx-kpiee account DB
  --limit <n>                     Max rows to return (default: 20)
  --with-workspace-names          Join zelda_kpiee workspaces.name by account_id
  --region <region>               AWS region (default: AWS_REGION or aws config)
  -h, --help                      Show this help

examples:
  count_dx_account_table_rows.sh --env stg --table data_files --limit 20
  count_dx_account_table_rows.sh --env stg --table data_files --limit 20 --with-workspace-names
USAGE
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || { echo "command not found: $cmd" >&2; exit 1; }
}

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

fetch_ssm_parameter() {
  local region="$1"
  local name="$2"
  aws ssm get-parameter \
    --region "$region" \
    --name "$name" \
    --with-decryption \
    --query 'Parameter.Value' \
    --output text
}

env_name=""
table_name=""
limit=20
with_workspace_names=0
region=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --env)
      env_name="${2:-}"
      shift 2
      ;;
    --table)
      table_name="${2:-}"
      shift 2
      ;;
    --limit)
      limit="${2:-}"
      shift 2
      ;;
    --with-workspace-names)
      with_workspace_names=1
      shift
      ;;
    --region)
      region="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_cmd aws
require_cmd awk
require_cmd python3

if [[ -z "$env_name" || -z "$table_name" ]]; then
  usage
  exit 1
fi

if [[ ! "$env_name" =~ ^(it|stg|stg01|stg02)$ ]]; then
  echo "--env must be one of: it, stg, stg01, stg02" >&2
  exit 1
fi

if [[ ! "$table_name" =~ ^[A-Za-z0-9_]+$ ]]; then
  echo "--table must match ^[A-Za-z0-9_]+$" >&2
  exit 1
fi

if [[ ! "$limit" =~ ^[0-9]+$ ]] || [[ "$limit" -le 0 ]]; then
  echo "--limit must be a positive integer" >&2
  exit 1
fi

if [[ -z "$region" ]]; then
  region="$(resolve_region)"
fi

case "$env_name" in
  it)
    zelda_database="zelda_kpiee_integration"
    ;;
  stg)
    zelda_database="zelda_kpiee_staging"
    ;;
  stg01)
    zelda_database="zelda_kpiee_staging01"
    ;;
  stg02)
    zelda_database="zelda_kpiee_staging02"
    ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mysql_helper="${script_dir}/mysql_query_via_bastion_ssm.sh"

tmp_dir="$(mktemp -d /tmp/codex-dx-account-table-count-XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

dx_host="$(fetch_ssm_parameter "$region" "/dx-kpiee-${env_name}/db-host")"
dx_user="$(fetch_ssm_parameter "$region" "/dx-kpiee-${env_name}/db-username")"
dx_password="$(fetch_ssm_parameter "$region" "/dx-kpiee-${env_name}/db-password")"

schema_sql_file="${tmp_dir}/list_schemas.sql"
cat > "$schema_sql_file" <<SQL
SELECT schema_name
FROM schemata
WHERE schema_name REGEXP '^${env_name}_dx_kpiee_[0-9]{4}$'
  AND EXISTS (
    SELECT 1
    FROM tables
    WHERE table_schema = schema_name
      AND table_name = '${table_name}'
  )
ORDER BY schema_name;
SQL

schema_output="$(
  AWS_REGION="$region" MYSQL_PASSWORD="$dx_password" "$mysql_helper" \
    --host "$dx_host" \
    --port 4000 \
    --database information_schema \
    --user "$dx_user" \
    --sql-file "$schema_sql_file"
)"

schemas_file="${tmp_dir}/schemas.txt"
printf '%s\n' "$schema_output" | tail -n +2 > "$schemas_file"

if [[ ! -s "$schemas_file" ]]; then
  echo "No matching dx-kpiee account schemas found for env=${env_name} table=${table_name}" >&2
  exit 1
fi

count_sql_file="${tmp_dir}/count_rows.sql"
{
  printf 'SELECT * FROM (\n'
  first=1
  while IFS= read -r schema_name; do
    [[ -z "$schema_name" ]] && continue
    account_id=$((10#${schema_name##*_}))
    if [[ "$first" -eq 0 ]]; then
      printf 'UNION ALL\n'
    fi
    printf "SELECT '%s' AS schema_name, %d AS account_id, COUNT(*) AS row_count FROM %s.%s\n" \
      "$schema_name" \
      "$account_id" \
      "$schema_name" \
      "$table_name"
    first=0
  done < "$schemas_file"
  printf ') AS counts\nORDER BY row_count DESC, account_id ASC\nLIMIT %d;\n' "$limit"
} > "$count_sql_file"

count_output="$(
  AWS_REGION="$region" MYSQL_PASSWORD="$dx_password" "$mysql_helper" \
    --host "$dx_host" \
    --port 4000 \
    --database information_schema \
    --user "$dx_user" \
    --sql-file "$count_sql_file"
)"

if [[ "$with_workspace_names" -eq 0 ]]; then
  printf '%s\n' "$count_output" | awk -F '\t' '
    BEGIN { OFS = "\t" }
    NR == 1 { print "rank", "account_id", "row_count", "schema_name"; next }
    { print NR - 1, $2, $3, $1 }
  '
  exit 0
fi

account_ids_csv="$(
  printf '%s\n' "$count_output" | awk -F '\t' '
    NR == 1 { next }
    { print $2 }
  ' | paste -sd, -
)"

if [[ -z "$account_ids_csv" ]]; then
  echo "No account ids were returned from the count query" >&2
  exit 1
fi

kpiee_host="$(fetch_ssm_parameter "$region" "/kpiee-${env_name}/db-read-host")"
kpiee_user="$(fetch_ssm_parameter "$region" "/kpiee-${env_name}/db-read-username")"
kpiee_password="$(fetch_ssm_parameter "$region" "/kpiee-${env_name}/db-read-password")"

workspace_sql_file="${tmp_dir}/workspace_names.sql"
cat > "$workspace_sql_file" <<SQL
SELECT id, name
FROM ${zelda_database}.workspaces
WHERE id IN (${account_ids_csv});
SQL

workspace_output="$(
  AWS_REGION="$region" MYSQL_PASSWORD="$kpiee_password" "$mysql_helper" \
    --host "$kpiee_host" \
    --port 3306 \
    --database information_schema \
    --user "$kpiee_user" \
    --sql-file "$workspace_sql_file"
)"

workspace_names_file="${tmp_dir}/workspace_names.tsv"
printf '%s\n' "$workspace_output" > "$workspace_names_file"

awk -F '\t' '
  BEGIN { OFS = "\t" }
  NR == FNR {
    if (FNR == 1) {
      next
    }
    workspace_name[$1] = $2
    next
  }
  FNR == 1 {
    print "rank", "account_id", "workspace_name", "row_count", "schema_name"
    next
  }
  {
    print FNR - 1, $2, workspace_name[$2], $3, $1
  }
' "$workspace_names_file" <(printf '%s\n' "$count_output")
