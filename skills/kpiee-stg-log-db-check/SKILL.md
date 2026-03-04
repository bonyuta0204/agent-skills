---
name: kpiee-stg-log-db-check
description: Perform generic investigation for kpiee STG by collecting evidence from ECS Exec, Rails/DB queries, bastion-routed direct MySQL, and CloudWatch Logs Insights. Use when users ask to verify behavior in STG for any feature, troubleshoot workspace-specific issues, confirm data existence/timestamps, or correlate DB records with runtime logs.
---

# Kpiee STG Log Db Check

## Overview

Investigate STG behavior with live evidence. Use a fixed workflow to gather reproducible outputs from ECS, DB, and CloudWatch, then summarize with explicit UTC/JST timestamps.

## Workflow

1. Run local preflight checks.
2. Identify target ECS cluster/service/task/container.
3. Run arbitrary Ruby scripts in ECS via `rails runner`.
4. (Optional) Discover AWS network route for bastion-routed DB access.
5. (Optional) Run direct `mysql` query from bastion via SSM.
6. Query CloudWatch logs for the same time window.
7. Correlate DB and logs and report evidence.

## Step 1: Preflight

Run:

```bash
scripts/preflight.sh
```

Checks:
- Required commands: `aws`, `gh`, `jq`, `session-manager-plugin`
- AWS authentication (`aws sts get-caller-identity`)
- Region (`AWS_REGION` or default `us-west-2`)

## Step 2: Identify ECS Target

List clusters/services/tasks and choose the target service for the issue domain.

Examples:

```bash
aws ecs list-clusters --region us-west-2
aws ecs list-services --region us-west-2 --cluster kpiee-stg
aws ecs list-tasks --region us-west-2 --cluster kpiee-stg --service-name <service-name> --desired-status RUNNING
```

For general Rails-side investigation, `kpiee-stg-ecs-exec` + container `kpiee-stg-rails` is usually the safest entry point.

## Step 3: Run Arbitrary Ruby Scripts in ECS

Use helper:

```bash
scripts/run_ruby_script_in_ecs.sh <task_id> <local_script.rb> [runner_arg ...]
```

Defaults (override via env):
- `ECS_CLUSTER=kpiee-stg`
- `ECS_CONTAINER=kpiee-stg-rails`
- `AWS_REGION=us-west-2`

Example:

```bash
scripts/run_ruby_script_in_ecs.sh e2d82fcda8bd45e2a5e4bdab1cb7c358 \
  scripts/check_workspace_data.rb \
  394 2026-03-04T15:20:52Z messages,notifications,push_deliveries
```

The helper uploads local `.rb` content (base64) into the target container, executes it with `bundle exec rails runner`, then returns script logs and propagates runner exit code to local shell.

## Ruby Script Authoring Tips

### Recommended structure

- Parse arguments explicitly from `ARGV`.
- Normalize time inputs to UTC (`Time.parse(...).utc`).
- Output structured JSON (`JSON.pretty_generate`) instead of free text.
- Wrap risky blocks with `begin/rescue` and include actionable error context.
- Limit row output (`limit`) and include aggregate counts.

### DB access patterns

- For workspace/account DB: use `AccountRecord.connect(account_id: workspace_id) do ... end`.
- For shared DB: query `PrimaryBase`-backed models directly.
- Before raw SQL against optional tables, guard with `connection.data_source_exists?`.

### Safety guardrails (important)

- Keep scripts read-only (`SELECT` only).
- Do not call `save`, `update`, `destroy`, `delete_all`, migration/rake mutation tasks.
- Do not print secrets/token full values in output.
- If no data exists in the target window, report that explicitly.

### Minimal template

```ruby
require "json"
require "time"

workspace_id = Integer(ARGV.fetch(0))
issue_opened_at = ARGV[1] ? Time.parse(ARGV[1]).utc : nil

out = { workspace_id: workspace_id, issue_opened_at_utc: issue_opened_at&.iso8601, errors: [] }

begin
  AccountRecord.connect(account_id: workspace_id) do
    out[:account_db] = AccountRecord.connection.current_database
    out[:latest_message_created_at] = Message.maximum(:created_at)&.utc&.iso8601
  end
rescue => e
  out[:errors] << { scope: "account", error: "#{e.class}: #{e.message}" }
end

puts JSON.pretty_generate(out)
```

## Step 4: Discover Bastion-to-DB Route (Optional)

When DB is private and direct local access is blocked, inspect route candidates first.

```bash
scripts/discover_db_route.sh <rds_instance_identifier>
```

Example:

```bash
scripts/discover_db_route.sh kpiee-stg-2024-09-04
```

Outputs include:
- RDS endpoint/port/public flag/VPC/subnets
- RDS SG inbound rules for TCP 3306
- Online SSM-managed EC2 instances (bastion candidates)

## Step 5: Run Direct MySQL Query via Bastion (Optional)

Use SSM RunCommand on a bastion EC2 where `mysql` is installed.

```bash
scripts/mysql_query_via_bastion_ssm.sh \
  --rds-instance <db_instance_id> \
  --database <db_name> \
  --sql 'SELECT NOW()'
```

Or with SQL file:

```bash
scripts/mysql_query_via_bastion_ssm.sh \
  --rds-instance <db_instance_id> \
  --database <db_name> \
  --sql-file ./query.sql
```

Useful options:
- `--bastion-instance <ec2_instance_id>`: force specific bastion
- `--host <db_endpoint>` / `--port 3306`: bypass RDS identifier resolution
- `--user <db_user>`: pass explicit MySQL user
- `--defaults-file <path_on_bastion>`: use bastion-side client credentials
- `--force`: allow non-read-only SQL (default blocks write-like SQL)

Defaults (env fallback):
- `AWS_REGION=us-west-2`
- `RDS_INSTANCE_ID`, `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`, `MYSQL_DATABASE`, `BASTION_INSTANCE_ID`, `MYSQL_DEFAULTS_FILE`

## Step 6: Query CloudWatch Logs

Run generic Logs Insights query:

```bash
scripts/cloudwatch_logs_query.sh \
  /ecs/kpiee-stg \
  2026-03-05T00:00:00Z \
  2026-03-05T01:00:00Z \
  'fields @timestamp, @logStream, @message | filter @message like /394/ | sort @timestamp asc | limit 100'
```

For delivery-daemon domains, switch log group explicitly (example: `/ecs/kpiee-stg-delivery-daemons`).

## Step 7: Reporting Format

Always report:
- Target workspace and time window (UTC/JST)
- ECS target used (cluster/service/task/container)
- Account DB name and key table counts/latest timestamps
- If bastion-direct query was used: RDS instance/endpoint + bastion instance + executed SQL intent
- CloudWatch log group and concrete matched lines (stream + timestamp)
- Whether evidence exists after issue timestamp
- Gaps/limitations (no records in window, missing log stream, permission limits)

## Resources

- `scripts/preflight.sh`: local prerequisite checks
- `scripts/run_ruby_script_in_ecs.sh`: execute arbitrary local Ruby scripts in ECS
- `scripts/check_workspace_data.rb`: generic workspace/table probe script
- `scripts/discover_db_route.sh`: inspect private DB connectivity route and bastion candidates
- `scripts/mysql_query_via_bastion_ssm.sh`: run SQL on private DB through bastion (SSM)
- `scripts/cloudwatch_logs_query.sh`: generic CloudWatch Logs Insights runner
