---
name: kpiee-stg-log-db-check
description: Investigate kpiee non-production environments (`it`, `stg`, `stg01`, `stg02`) with reusable AWS/Snowflake tools and target references. Choose only the tools needed for the case.
---

# KPIEE Non-PRD Investigation Toolkit

This skill is a toolkit, not a fixed workflow.
Its live environment scope is:

- `it`
- `stg`
- `stg01`
- `stg02`

Do not force a sequence like ECS Exec -> DB -> logs.
Pick only the tools that match the signal you already have:

- Logs when you have timestamps, request IDs, job IDs, account IDs, or error strings
- ECS Exec when you need runtime app state or Rails-side inspection
- DB checks when you need record presence/absence or routing confirmation
- Snowflake when the issue domain is report/tabulate/sfonline or query latency

## Structure

- `scripts/`: reusable investigation tools without kpiee-specific defaults
- `references/kpiee-stg-reference.md`: kpiee non-production target mapping and repo hints

## Operating Rules

- Always set `AWS_REGION` explicitly for the current investigation unless your local AWS config is already correct.
- For kpiee non-production, start from `us-west-2` unless the reference says otherwise.
- Pick the target env first: `it`, `stg`, `stg01`, or `stg02`.
- Choose the minimum toolset needed for the question at hand.
- Treat reference data as hints. Re-confirm live targets when the choice matters.
- Keep everything read-only by default.
- Report evidence with exact UTC timestamps.

## Preflight

Run this before using the toolkit:

```bash
scripts/preflight.sh
```

What it checks:

- required local commands: `aws`, `jq`, `python3`, `session-manager-plugin`
- optional local command: `snow`
- AWS auth: `aws sts get-caller-identity`
- effective region: `AWS_REGION` or AWS config

If region resolution fails, set it explicitly:

```bash
export AWS_REGION=us-west-2
```

## Target Selection

Open the reference and pick the concrete target only for the tool you need:

```bash
cat references/kpiee-stg-reference.md
```

Typical target types:

- ECS cluster, service, container, task family
- CloudWatch log group
- RDS instance identifier or DB host route
- Snowflake DB/schema naming pattern

## Tool: CloudWatch Logs Insights

Use this when you already have a time window, identifiers, or an error signature.

```bash
scripts/cloudwatch_logs_query.sh \
  <log_group> \
  <start_utc_iso8601> \
  <end_utc_iso8601> \
  'fields @timestamp, @logStream, @message | sort @timestamp asc | limit 100'
```

Output is JSONL so structured fields are preserved.

Prefer exact-match style filters to avoid partial hits.

Example:

```bash
scripts/cloudwatch_logs_query.sh \
  /ecs/dx-kpiee-stg-go \
  2026-03-04T00:00:00Z \
  2026-03-05T00:00:00Z \
  'fields @timestamp, @logStream, @message, account_id, report_id, severity \
   | filter account_id = 420 and report_id in [76, 77] \
   | sort @timestamp asc \
   | limit 200'
```

Fallback when structured fields are unavailable:

```bash
scripts/cloudwatch_logs_query.sh \
  /ecs/dx-kpiee-stg-go \
  2026-03-04T00:00:00Z \
  2026-03-05T00:00:00Z \
  'fields @timestamp, @logStream, @message \
   | filter @message like /\"account_id\":420/ and @message like /\"report_id\":(76|77)([^0-9]|$)/ \
   | sort @timestamp asc \
   | limit 200'
```

## Tool: ECS Task Discovery

Use this when you know the service but not the concrete task ID yet.

```bash
scripts/list_ecs_tasks.sh <cluster> <service> [region]
```

Example:

```bash
scripts/list_ecs_tasks.sh kpiee-stg dx-kpiee-stg
```

Pick a running task ID from the output, then use ECS Exec if needed.

## Tool: ECS Exec + Rails Runner

Use this when logs alone are not enough and you need runtime inspection.

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

Assumptions:

- ECS Exec is enabled for the target task
- the target container has `bash`
- the target container can run `bundle exec rails runner`

## Tool: DB Route Discovery

Use this when the default DB route fails, or when you need to inspect the network path explicitly.

```bash
scripts/discover_db_route.sh <rds_instance_identifier> [region]
```

This is a discovery tool. It shows:

- RDS summary
- relevant security groups
- SSM-managed EC2 bastion candidates

In the normal path you should not need this first. The MySQL helper tries the shared non-prod bastion `kpiee-infra-dev` first and only falls back to discovery when that fixed route fails.

## Tool: Direct MySQL Query via Bastion

Use this only when direct DB evidence is necessary.

Connection quick rules:

- `dx-kpiee` app-owned DB parameters (`/dx-kpiee-{env}/db-*`) point to TiDB. Use port `4000`.
- `kpiee` read-side DB parameters (`/kpiee-{env}/db-read-*`) point to MySQL/RDS. Use port `3306`.
- When the SQL is longer than a one-liner, prefer `--sql-file`. This avoids shell quoting breakage with backticks, quotes, and cross-schema `UNION ALL`.

Default behavior:

- try the shared non-prod bastion `kpiee-infra-dev` first
- if that route fails, discover another SSM-managed bastion and retry once

Minimal usage:

```bash
scripts/mysql_query_via_bastion_ssm.sh \
  --rds-instance <db_instance_id> \
  --database <db_name> \
  --sql 'SELECT NOW()'
```

If you need to force a specific bastion, override it explicitly:

```bash
scripts/mysql_query_via_bastion_ssm.sh \
  --rds-instance <db_instance_id> \
  --database <db_name> \
  --bastion-instance <instance_id> \
  --sql 'SELECT NOW()'
```

When the password comes from SSM, prefer `MYSQL_PASSWORD` over embedding it in the shell command:

```bash
DX_HOST="$(aws ssm get-parameter --name /dx-kpiee-stg/db-host --with-decryption --query 'Parameter.Value' --output text)"
DX_USER="$(aws ssm get-parameter --name /dx-kpiee-stg/db-username --with-decryption --query 'Parameter.Value' --output text)"
DX_PASS="$(aws ssm get-parameter --name /dx-kpiee-stg/db-password --with-decryption --query 'Parameter.Value' --output text)"

MYSQL_PASSWORD="$DX_PASS" scripts/mysql_query_via_bastion_ssm.sh \
  --host "$DX_HOST" \
  --port 4000 \
  --database information_schema \
  --user "$DX_USER" \
  --sql-file /path/to/query.sql
```

Notes:

- as of 2026-03-07, the fixed shared bastion is `kpiee-infra-dev` and SSM execution was verified on that host
- read-only protection is heuristic, not a formal guarantee
- `--discover-bastion` is still available when you want to skip the fixed route and inspect the heuristic path first
- use `--force` only when you intentionally need to bypass the default block

## Tool: dx-kpiee Account DB Row Counts

Use this when you need the top accounts by row count for one table across `dx-kpiee` account DBs.

```bash
scripts/count_dx_account_table_rows.sh \
  --env stg \
  --table data_files \
  --limit 20 \
  --with-workspace-names
```

This helper:

- fetches `dx-kpiee` DB credentials from SSM
- queries `information_schema` to find matching account DBs
- builds the cross-schema count query into a temp SQL file
- optionally joins `zelda_kpiee_*.workspaces` to resolve account names

## Tool: Snowflake Investigation

Use this when the issue domain includes report/tabulate/sfonline or Snowflake query latency.

See concrete environment mapping in:

```bash
cat references/kpiee-stg-reference.md
```

Minimal flow:

```bash
snow connection list
snow sql -c <profile> -q "SHOW SCHEMAS IN DATABASE DX_KPIEE_STG;"
snow sql -c <profile> -q "USE SCHEMA DX_KPIEE_STG.STG_AC_0172; SHOW TABLES LIKE 'REPORT_%';"
snow sql -c <profile> -q "SELECT * FROM DX_KPIEE_STG.STG_AC_0172.REPORT_... LIMIT 20;" --format json
```

Do not assume the profile is always `kpiee`. Confirm the local profile first.

## Reporting Contract

Always report:

- investigation target and UTC time window
- which tools were used and why
- selected ECS cluster, service, container, and task when ECS was used
- selected DB route, bastion, DB name, and SQL intent when DB query was used
- selected log group and matching records when logs were used
- selected Snowflake profile, DB/schema, and history source when Snowflake was used
- evidence after the issue timestamp as `found` or `not found`
- gaps and limitations such as permission issues, missing streams, or empty windows

## Resources

- `scripts/preflight.sh`
- `scripts/cloudwatch_logs_query.sh`
- `scripts/list_ecs_tasks.sh`
- `scripts/run_ruby_script_in_ecs.sh`
- `scripts/check_workspace_data.rb`
- `scripts/discover_db_route.sh`
- `scripts/mysql_query_via_bastion_ssm.sh`
- `references/kpiee-stg-reference.md`
