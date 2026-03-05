---
name: kpiee-stg-log-db-check
description: Investigate STG behavior with generic AWS tooling (CloudWatch Logs, ECS Exec, DB checks) and use kpiee-specific connection targets from references.
---

# KPIEE STG Investigation Toolkit

## Overview

This skill is organized into:

1. Generic tools in `scripts/` for ECS, logs, and DB investigation.
2. kpiee-specific connection targets in `references/`.

Use this separation to keep execution logic reusable while maintaining concrete environment mapping for kpiee.

## Structure

- `scripts/`: reusable investigation tools (no kpiee-specific hardcoded target names)
- `references/kpiee-stg-reference.md`: kpiee STG ECS/log/DB target mapping collected from related repos

## Standard Workflow

1. Run preflight.
2. Pick target cluster/service/container/log-group/DB route from `references/kpiee-stg-reference.md`.
3. Execute investigation via generic scripts.
4. Correlate ECS output, DB output, and log output by UTC timestamp.
5. Report evidence and gaps.

## Step 1: Preflight

```bash
scripts/preflight.sh
```

Checks:
- required commands (`aws`, `jq`, `session-manager-plugin`)
- AWS auth (`aws sts get-caller-identity`)
- effective region (`AWS_REGION` -> aws config -> fallback)

## Step 2: Select Targets from Reference

Open:

```bash
cat references/kpiee-stg-reference.md
```

Pick concrete values:
- ECS cluster / service / container
- CloudWatch log group
- SSM parameter namespace / DB host route

## Step 3: ECS Exec + Rails Runner

Run arbitrary local Ruby script in ECS:

```bash
ECS_CLUSTER=<cluster> ECS_CONTAINER=<container> \
scripts/run_ruby_script_in_ecs.sh <task_id> <local_script.rb> [runner_arg ...]
```

Example:

```bash
ECS_CLUSTER=kpiee-stg ECS_CONTAINER=dx-kpiee-stg-rails \
scripts/run_ruby_script_in_ecs.sh \
  <task_id> \
  scripts/check_workspace_data.rb \
  394 2026-03-04T15:20:52Z messages,notifications,push_deliveries
```

## Step 4: DB Route Discovery (Optional)

```bash
scripts/discover_db_route.sh <rds_instance_identifier> [region]
```

Use when DB is private and bastion route must be identified first.

## Step 5: Direct MySQL Query via Bastion (Optional)

```bash
scripts/mysql_query_via_bastion_ssm.sh \
  --rds-instance <db_instance_id> \
  --database <db_name> \
  --sql 'SELECT NOW()'
```

Notes:
- read-only SQL is enforced by default
- use `--force` only when intentionally running non-read-only statements

## Step 6: CloudWatch Logs Insights

```bash
scripts/cloudwatch_logs_query.sh \
  <log_group> \
  <start_utc_iso8601> \
  <end_utc_iso8601> \
  'fields @timestamp, @logStream, @message | sort @timestamp asc | limit 100'
```

## Step 7: Snowflake Investigation with `snow` CLI (Optional)

Use this when the issue domain includes report/tabulate/sfonline or Snowflake query latency.

See concrete environment mapping in:

```bash
cat references/kpiee-stg-reference.md
```

Minimal flow:

```bash
# 1) Verify connection profile
snow connection list

# 2) Check available schemas for target DB (example: STG)
snow sql -c kpiee -q "SHOW SCHEMAS IN DATABASE DX_KPIEE_STG;"

# 3) Inspect account schema tables (example: account_id=172 -> STG_AC_0172)
snow sql -c kpiee -q "USE SCHEMA DX_KPIEE_STG.STG_AC_0172; SHOW TABLES LIKE 'REPORT_%';"

# 4) Get result in JSON for correlation with app logs
snow sql -c kpiee -q "SELECT * FROM DX_KPIEE_STG.STG_AC_0172.REPORT_... LIMIT 20;" --format json
```

Performance history (choose based on freshness):

```bash
# near-real-time
snow sql -c kpiee -q "
SELECT query_id, total_elapsed_time, compilation_time, execution_time
FROM TABLE(information_schema.query_history(
  dateadd('hours', -24, current_timestamp()),
  current_timestamp(),
  result_limit => 100
))
WHERE schema_name = 'STG_AC_0172'
ORDER BY total_elapsed_time DESC;
"

# long-term (latency up to ~45 min)
snow sql -c kpiee -q "
SELECT query_id, total_elapsed_time, rows_produced, bytes_scanned
FROM snowflake.account_usage.query_history
WHERE schema_name = 'STG_AC_0172'
  AND start_time >= DATEADD(day, -3, CURRENT_TIMESTAMP())
ORDER BY total_elapsed_time DESC
LIMIT 30;
"
```

## Reporting Contract

Always report:

- investigation target (workspace/feature) and UTC time window
- selected ECS cluster/service/container/task
- selected DB route (RDS/bastion/SQL intent) when DB query is used
- selected log group and matched lines (timestamp + stream)
- if Snowflake was used: connection profile, DB/schema, and query history source (`information_schema` or `account_usage`)
- evidence after issue timestamp (`found` / `not found`)
- gaps and limitations (permission, missing streams, no rows in window, etc.)

## Guardrails

- keep scripts and SQL read-only by default
- avoid secret/token dumps in outputs
- include exact timestamps in UTC in every evidence block
- do not treat assumptions as facts; cite reference source file when naming targets

## Resources

- `scripts/preflight.sh`
- `scripts/run_ruby_script_in_ecs.sh`
- `scripts/check_workspace_data.rb`
- `scripts/discover_db_route.sh`
- `scripts/mysql_query_via_bastion_ssm.sh`
- `scripts/cloudwatch_logs_query.sh`
- `references/kpiee-stg-reference.md`
