# KPIEE Non-PRD Reference

This file stores kpiee-specific investigation targets for the non-production environments:

- `it`
- `stg`
- `stg01`
- `stg02`

It is intended for the `kpiee-stg-log-db-check` skill even though the actual scope is broader than `stg`.

Verification scope for the current contents:

- AWS account confirmed on 2026-03-07: `776591296688`
- AWS region confirmed on 2026-03-07: `us-west-2`
- Live AWS resources checked on 2026-03-07:
  - ECS clusters and services
  - CloudWatch log groups
  - SSM parameter prefixes
- Additional live checks on 2026-03-26:
  - `atlas-core-stg01` ECS services and log groups
  - `atlas_core_staging01` main DB on TiDB
  - tenant DB resolution for atlas-core via `db_connections`
- Repo sources checked on 2026-03-07:
  - `f-scratch/zelda-kpiee`
  - `f-scratch/dx-kpiee`
  - `f-scratch/atlas-kpiee`
  - `f-scratch/atlas-core`

Use generic scripts in `scripts/` for execution, and pick concrete values from here.

## Common AWS Baseline

- Confirmed ECS clusters:
  - `kpiee-it`
  - `kpiee-stg`
  - `kpiee-stg01`
  - `kpiee-stg02`
- Confirmed shared DB bastion on 2026-03-07:
  - Name: `kpiee-infra-dev`
  - Instance ID: `i-05cb1b41cda7e3806`
  - State: `running`
  - SSM `AWS-RunShellScript` execution: success
  - Route basis: its security group `sg-0e70ca6d4975dcb89` is allowed on MySQL `3306` by the RDS security groups used in `it`, `stg`, `stg01`, and `stg02`
- `kpiee-infra-stg` exists but was `stopped` on 2026-03-07 and should not be treated as the default non-prod bastion path.
- Start every investigation by fixing the target env first.
- When the target is ambiguous, do not mix `stg` with `stg01` or `stg02`. They are separate live environments.

## DB Route Quick Map

Use this before deciding which host parameters and port to use.

| target | host params | auth params | port | DB family | typical purpose |
| --- | --- | --- | ---: | --- | --- |
| `dx-kpiee` app DB | `/dx-kpiee-{env}/db-host` | `/dx-kpiee-{env}/db-username`, `/dx-kpiee-{env}/db-password` | 4000 | TiDB | account DBs like `{env}_dx_kpiee_0001`, direct checks on `data_files` and `reports` |
| `atlas-core` main DB | `/dx-kpiee-{env}/db-host` | `/dx-kpiee-{env}/db-username`, `/dx-kpiee-{env}/db-password` | 4000 | TiDB | `atlas_core_*` and `db_connections` lookup for tenant DB resolution |
| `kpiee` read DB | `/kpiee-{env}/db-read-host` | `/kpiee-{env}/db-read-username`, `/kpiee-{env}/db-read-password` | 3306 | MySQL/RDS | `zelda_kpiee_*` lookup such as `workspaces.name` or `workspace_users` |

Cross-check the logical DB names from taskdefs when you need them:

| env | dx-kpiee shared DB | kpiee shared DB |
| --- | --- | --- |
| `it` | `dx_kpiee_integration` | `zelda_kpiee_integration` |
| `stg` | `dx_kpiee_staging` | `zelda_kpiee_staging` |
| `stg01` | `dx_kpiee_staging01` | `zelda_kpiee_staging01` |
| `stg02` | `dx_kpiee_staging02` | `zelda_kpiee_staging02` |

Atlas-core main DB names:

| env | atlas-core main DB |
| --- | --- |
| `it` | `atlas_core_integration` |
| `stg` | `atlas_core_staging` |
| `stg01` | `atlas_core_staging01` |

Atlas-core data connector board / asset lookup:

1. Use `/ecs/atlas-core-{env}-workflow` logs to map dbt model to `job_id`, `account_id`, `target_type=DataBoard`, and `target_id`.
2. Query the atlas-core main DB `db_connections` table to resolve the tenant DB from `account_id`.
3. Query the tenant DB `data_boards` and `assets` tables.

Typical SQL:

```sql
SELECT account_id, host, port, `database`
FROM db_connections
WHERE account_id = <account_id>;
```

```sql
SELECT id, name, status
FROM data_boards
WHERE id = <data_board_id>;
```

```sql
SELECT id, name, asset_type, status, data_board_id
FROM assets
WHERE data_board_id = <data_board_id>
ORDER BY id;
```

Do not start by guessing tenant DB names or by searching unrelated `kpiee` databases.

## zelda-kpiee

Source repo: `f-scratch/zelda-kpiee` (resolve locally with `ghq list -p`)

AWS-confirmed core services by env pattern on 2026-03-07:

- app:
  - `kpiee-{env}`
  - `kpiee-{env}-internal`
  - `kpiee-{env}-external`
- support:
  - `kpiee-{env}-scheduler`
  - `kpiee-{env}-delivery-daemons`
  - `kpiee-{env}-import-daemons`
  - `kpiee-{env}-notification`
  - `kpiee-{env}-ecs-exec`
  - `kpiee-{env}-admin`
  - `kpiee-{env}-admin-daemons`
  - `kpiee-{env}-admin-internal`
  - `kpiee-{env}-canary`
- companion services seen in AWS:
  - `kpieecable-{env}`
  - `kpieecable-{env}-v2`
  - `kpiee-logagg-{env}` is present for `it`, `stg`, `stg01`, `stg02`

Confirmed CloudWatch log groups:

- `/ecs/kpiee-{env}`
- `/ecs/kpiee-{env}-internal`
- `/ecs/kpiee-{env}-external`
- `/ecs/kpiee-{env}-scheduler`
- `/ecs/kpiee-{env}-delivery-daemons`
- `/ecs/kpiee-{env}-import-daemons`
- `/ecs/kpiee-{env}-notification-daemons` or `/ecs/kpiee-{env}-notification`
- `/ecs/kpiee-{env}-admin`
- `/ecs/kpiee-{env}-admin-daemons`
- `/ecs/kpiee-{env}-admin-internal`
- `/ecs/kpiee-{env}-cloudwatch-exporter`
- `/ecs/kpiee-{env}-rails-prometheus-exporter`
- `/ecs/kpiee-{env}/canary`

Confirmed SSM parameter prefixes:

- `/kpiee-{env}/db-host`
- `/kpiee-{env}/db-read-host`
- `/kpiee-{env}/db-read-password`
- `/kpiee-{env}/db-read-username`
- `/kpiee-{env}/vault-db-host`
- `/kpiee-{env}/rails-master-key`
- `/kpiee-{env}/redis-host`
- `/kpiee-{env}/snowflake-private-key`

Repo files worth opening first:

- `config/settings/integration.yml`
- `config/settings/staging.yml`
- `config/settings/staging01.yml`
- `config/settings/staging02.yml`
- `deploy/taskdef-stg.json`
- `deploy/taskdef-stg01.json`
- `deploy/taskdef-stg02.json`
- `deploy/internal/taskdef-it.json`
- `deploy/internal/taskdef-stg.json`
- `deploy/internal/taskdef-stg01.json`
- `deploy/internal/taskdef-stg02.json`
- `deploy/external/taskdef-it.json`
- `deploy/external/taskdef-stg.json`
- `deploy/external/taskdef-stg01.json`
- `deploy/external/taskdef-stg02.json`

## dx-kpiee

Source repo: `f-scratch/dx-kpiee` (resolve locally with `ghq list -p`)

AWS-confirmed services by env pattern on 2026-03-07:

- Rails:
  - `dx-kpiee-{env}`
  - `dx-kpiee-{env}-daemons`
  - `dx-kpiee-{env}-internal`
  - `dx-kpiee-{env}-scheduler`
- Go:
  - `dx-kpiee-{env}-go`
  - `dx-kpiee-{env}-async-job`
  - `dx-kpiee-{env}-report-tabulate`

Confirmed CloudWatch log groups:

- Rails:
  - `/ecs/dx-kpiee-{env}`
  - `/ecs/dx-kpiee-{env}-daemons`
  - `/ecs/dx-kpiee-{env}-internal`
  - `/ecs/dx-kpiee-{env}-scheduler`
- Go:
  - `/ecs/dx-kpiee-{env}-go`
  - `/ecs/dx-kpiee-{env}-polling`
  - `/ecs/dx-kpiee-{env}-worker`
  - `/ecs/dx-kpiee-{env}-report-tabulate`
- deploy-related groups seen in AWS:
  - `/ecs/dx-kpiee-{env}-migration` exists for `it`, `stg`, `stg01`, `stg02`
  - `/ecs/dx-kpiee-{env}-ridgepole` exists for `it`, `stg`, `stg01` as of 2026-03-07; not confirmed for `stg02`

Confirmed SSM parameter prefixes:

- app-owned:
  - `/dx-kpiee-{env}/rails-master-key`
  - `/dx-kpiee-{env}/db-host`
  - `/dx-kpiee-{env}/db-password`
  - `/dx-kpiee-{env}/db-username`
  - `/dx-kpiee-{env}/redis-host`
  - `/dx-kpiee-{env}/sentry-dsn`
  - `/dx-kpiee-{env}/snowflake-account`
- shared from zelda:
  - `/kpiee-{env}/db-host`
  - `/kpiee-{env}/db-read-host`
  - `/kpiee-{env}/db-read-password`
  - `/kpiee-{env}/db-read-username`
  - `/kpiee-{env}/redis-host`
  - `/kpiee-{env}/snowflake-private-key`
  - `/kpiee-{env}/cognito-pool-id`
  - `/kpiee-{env}/cognito-client-id`
  - `/kpiee-{env}/cipher-key`

Repo files worth opening first:

- `CLAUDE.md`
- `backend/rails/deploy/taskdef/dx-kpiee-it.json`
- `backend/rails/deploy/taskdef/dx-kpiee-stg.json`
- `backend/rails/deploy/taskdef/dx-kpiee-stg01.json`
- `backend/rails/deploy/taskdef/dx-kpiee-stg02.json`
- `backend/rails/deploy/taskdef/dx-kpiee-it-internal.json`
- `backend/rails/deploy/taskdef/dx-kpiee-stg-internal.json`
- `backend/rails/deploy/taskdef/dx-kpiee-stg01-internal.json`
- `backend/rails/deploy/taskdef/dx-kpiee-stg02-internal.json`
- `backend/go/deploy/taskdef/dx-kpiee-it.json`
- `backend/go/deploy/taskdef/dx-kpiee-stg.json`
- `backend/go/deploy/taskdef/dx-kpiee-stg01.json`
- `backend/go/deploy/taskdef/dx-kpiee-stg02.json`
- `backend/go/deploy/taskdef/dx-kpiee-it-go-async-job.json`
- `backend/go/deploy/taskdef/dx-kpiee-stg-go-async-job.json`
- `backend/go/deploy/taskdef/dx-kpiee-stg01-go-async-job.json`
- `backend/go/deploy/taskdef/dx-kpiee-stg02-go-async-job.json`
- `backend/go/deploy/taskdef/dx-kpiee-it-go-report-tabulate.json`
- `backend/go/deploy/taskdef/dx-kpiee-stg-go-report-tabulate.json`
- `backend/go/deploy/taskdef/dx-kpiee-stg01-go-report-tabulate.json`
- `backend/go/deploy/taskdef/dx-kpiee-stg02-go-report-tabulate.json`

## atlas-kpiee

Source repo: `f-scratch/atlas-kpiee` (resolve locally with `ghq list -p`)

Current live scope is `it`, `stg`, and `stg01`.
`stg02` should still be treated as needs-confirmation unless the current investigation proves otherwise.

AWS-confirmed services for `it`, `stg`, and `stg01`:

- `atlas-kpiee-{env}-rails`

AWS-confirmed CloudWatch log groups for `it`, `stg`, and `stg01`:

- `/ecs/atlas-kpiee-{env}`
- `/ecs/atlas-kpiee-{env}-migration`

Confirmed SSM parameter prefixes for `it`, `stg`, and `stg01`:

- `/atlas-kpiee-{env}/db-host`
- `/atlas-kpiee-{env}/db-password`
- `/atlas-kpiee-{env}/db-username`
- `/atlas-kpiee-{env}/distribution_id`
- `/atlas-kpiee-{env}/rails-master-key`
- `/atlas-kpiee-{env}/redis-host`
- `/atlas-kpiee-{env}/sentry-dsn`

Important shared dependencies visible in taskdefs:

- write-side DB is taken from `/dx-kpiee-{env}/db-host`
- read-side DB is taken from `/kpiee-{env}/db-read-host`

Repo files worth opening first:

- `backend/deploy/taskdef/atlas-kpiee-it-rails.json`
- `backend/deploy/taskdef/atlas-kpiee-stg-rails.json`
- `backend/deploy/taskdef/atlas-kpiee-stg01-rails.json`
- `backend/deploy/taskdef/atlas-kpiee-it-rails-migration.json`
- `backend/deploy/taskdef/atlas-kpiee-stg-rails-migration.json`
- `backend/deploy/taskdef/atlas-kpiee-stg01-rails-migration.json`

## atlas-core

Source repo: `f-scratch/atlas-core` (resolve locally with `ghq list -p`)

Current live scope is `it`, `stg`, and `stg01`.
`stg02` should still be treated as needs-confirmation unless the current investigation proves otherwise.

AWS-confirmed services for `it`, `stg`, and `stg01`:

- `atlas-core-{env}-rails`
- `atlas-core-{env}-provisioning`
- `atlas-core-{env}-scheduler`
- `atlas-core-{env}-sfonline`
- `atlas-core-{env}-workflow`

AWS-confirmed CloudWatch log groups for `it`, `stg`, and `stg01`:

- `/ecs/atlas-core-{env}`
- `/ecs/atlas-core-{env}-migration`
- `/ecs/atlas-core-{env}-provisioning`
- `/ecs/atlas-core-{env}-scheduler`
- `/ecs/atlas-core-{env}-sfonline`
- `/ecs/atlas-core-{env}-workflow`

Confirmed SSM parameter prefixes for `it`, `stg`, and `stg01`:

- `/atlas-core-{env}/db-host`
- `/atlas-core-{env}/db-password`
- `/atlas-core-{env}/db-username`
- `/atlas-core-{env}/rails-master-key`
- `/atlas-core-{env}/redis-host`
- `/atlas-core-{env}/sentry-dsn`
- `/atlas-core-{env}/snowflake-user`
- `/atlas-core-{env}/snowflake-role`
- `/atlas-core-{env}/snowflake-private-key-pem`

Important shared dependencies visible in taskdefs:

- `SNOWFLAKE_ACCOUNT=/dx-kpiee-{env}/snowflake-account`
- `SNOWFLAKE_PRIVATE_KEY_PEM=/kpiee-{env}/snowflake-private-key`
- data-connector DB host pattern from repo templates:
  - `<project_env>-data-connector.mysql.rds.<private_domain>`

Repo files worth opening first:

- `rails/config/settings/integration.yml`
- `rails/config/settings/staging.yml`
- `.ansible/config/database.yml.j2`
- `CLAUDE.md`
- `backend/deploy/taskdef/atlas-core-it-rails.json`
- `backend/deploy/taskdef/atlas-core-it-provisioning.json`
- `backend/deploy/taskdef/atlas-core-it-scheduler.json`
- `backend/deploy/taskdef/atlas-core-it-sfonline.json`
- `backend/deploy/taskdef/atlas-core-it-workflow.json`
- `backend/deploy/taskdef/atlas-core-stg-rails.json`
- `backend/deploy/taskdef/atlas-core-stg-provisioning.json`
- `backend/deploy/taskdef/atlas-core-stg-scheduler.json`
- `backend/deploy/taskdef/atlas-core-stg-sfonline.json`
- `backend/deploy/taskdef/atlas-core-stg-workflow.json`
- `backend/deploy/taskdef/atlas-core-stg01-rails.json`
- `backend/deploy/taskdef/atlas-core-stg01-provisioning.json`
- `backend/deploy/taskdef/atlas-core-stg01-scheduler.json`
- `backend/deploy/taskdef/atlas-core-stg01-sfonline.json`
- `backend/deploy/taskdef/atlas-core-stg01-workflow.json`

Important note:

- A Snowflake/dbt model name such as `DC_CLEANSING_0005` is not enough by itself to derive the DataBoard name.
- You usually need workflow logs first, because the same investigation needs both `account_id` and `target_id`.

## Snowflake Reference

### dx-kpiee

Primary operational source: `f-scratch/dx-kpiee/CLAUDE.md`

Confirmed non-PRD environment mapping in repo docs:

- `IT -> DX_KPIEE_IT -> IT_AC_%04d`
- `STG -> DX_KPIEE_STG -> STG_AC_%04d`
- `STG01 -> DX_KPIEE_STG01 -> STG01_AC_%04d`
- `STG02 -> DX_KPIEE_STG02 -> STG02_AC_%04d`

Useful commands:

- `snow connection list`
- `snow sql -c <profile> -q "SHOW SCHEMAS IN DATABASE DX_KPIEE_STG;"`
- `snow sql -c <profile> -q "SHOW SCHEMAS IN DATABASE DX_KPIEE_STG01;"`
- `snow sql -c <profile> -q "SHOW SCHEMAS IN DATABASE DX_KPIEE_STG02;"`
- `snow sql -c <profile> -q "SHOW SCHEMAS IN DATABASE DX_KPIEE_IT;"`

Query history sources:

- near-real-time: `information_schema.query_history(...)`
- longer retention: `snowflake.account_usage.query_history`

### atlas-core sfonline

Confirmed in repo taskdefs:

- `it`
  - `SNOWFLAKE_ACCOUNT=/dx-kpiee-it/snowflake-account`
  - `SNOWFLAKE_USER=/atlas-core-it/snowflake-user`
  - `SNOWFLAKE_ROLE=/atlas-core-it/snowflake-role`
  - `SNOWFLAKE_PRIVATE_KEY_PEM=/kpiee-it/snowflake-private-key`
- `stg`
  - `SNOWFLAKE_ACCOUNT=/dx-kpiee-stg/snowflake-account`
  - `SNOWFLAKE_USER=/atlas-core-stg/snowflake-user`
  - `SNOWFLAKE_ROLE=/atlas-core-stg/snowflake-role`
  - `SNOWFLAKE_PRIVATE_KEY_PEM=/kpiee-stg/snowflake-private-key`
- future expansion / repo-only as of 2026-03-07:
  - `stg01`
    - `SNOWFLAKE_ACCOUNT=/dx-kpiee-stg01/snowflake-account`
    - `SNOWFLAKE_USER=/atlas-core-stg01/snowflake-user`
    - `SNOWFLAKE_ROLE=/atlas-core-stg01/snowflake-role`
    - `SNOWFLAKE_PRIVATE_KEY_PEM=/kpiee-stg01/snowflake-private-key`

## Refresh Procedure

1. Resolve repo paths with `ghq`.
2. Re-confirm AWS account and region with `aws sts get-caller-identity` and `AWS_REGION`.
3. Re-scan live ECS clusters/services, CloudWatch log groups, and SSM parameter prefixes for `it`, `stg`, `stg01`, `stg02`.
4. Re-scan repo taskdefs/docs listed above.
5. Update this file with confirmed names only.
6. Keep scripts generic; never hardcode kpiee-specific defaults in `scripts/`.
