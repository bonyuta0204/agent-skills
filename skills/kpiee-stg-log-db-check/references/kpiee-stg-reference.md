# KPIEE STG Reference

This file stores kpiee-specific connection targets.  
Use generic scripts in `scripts/` for execution, and pick concrete values from here.

## Common Hints

- Primary STG AWS account: `776591296688`
- Primary STG region: `us-west-2`
- Main cluster family: `kpiee-stg` (`stg01`/`stg02` variants exist)

## zelda-kpiee

Source repo: `/Users/yuta.nakamura/workspace/github.com/f-scratch/zelda-kpiee`

- ECS task families:
  - `kpiee-stg`, `kpiee-stg-internal`, `kpiee-stg-external`
  - `kpiee-stg01*`, `kpiee-stg02*` variants
- Major containers:
  - `kpiee-stg-rails`, `kpiee-stg-nginx`
- CloudWatch log groups:
  - `/ecs/kpiee-stg`
  - `/ecs/kpiee-stg-internal`
  - `/ecs/kpiee-stg-external`
  - `/ecs/kpiee-stg01*`, `/ecs/kpiee-stg02*` variants
- SSM parameter patterns:
  - `/kpiee-stg/db-host`
  - `/kpiee-stg/db-read-host`
  - `/kpiee-stg/vault-db-host`
- Key files:
  - `deploy/taskdef-stg.json`
  - `deploy/internal/taskdef-stg.json`
  - `deploy/external/taskdef-stg.json`
  - `config/settings/staging.yml`

## dx-kpiee

Source repo: `/Users/yuta.nakamura/workspace/github.com/f-scratch/dx-kpiee`

- ECS cluster: `kpiee-stg`
- Major services/containers:
  - `dx-kpiee-stg` / `dx-kpiee-stg-rails`
  - `dx-kpiee-stg-daemons` / `dx-kpiee-stg-rails-resque-pool`
  - `dx-kpiee-stg-internal` / `dx-kpiee-stg-rails-internal`
  - `dx-kpiee-stg-scheduler` / `dx-kpiee-stg-scheduler`
  - `dx-kpiee-stg-go` / `dx-kpiee-stg-go`
  - `dx-kpiee-stg-async-job` / `dx-kpiee-stg-polling`, `dx-kpiee-stg-worker`
- CloudWatch log groups:
  - `/ecs/dx-kpiee-stg`
  - `/ecs/dx-kpiee-stg-internal`
  - `/ecs/dx-kpiee-stg-daemons`
  - `/ecs/dx-kpiee-stg-scheduler`
  - `/ecs/dx-kpiee-stg-go`
  - `/ecs/dx-kpiee-stg-polling`
  - `/ecs/dx-kpiee-stg-worker`
  - `/ecs/dx-kpiee-stg-report-tabulate`
- SSM parameter patterns:
  - `/dx-kpiee-stg/db-host`
  - `/kpiee-stg/db-host`
  - `/kpiee-stg/db-read-host`
- Key files:
  - `.github/workflows/deploy-staging.yml`
  - `docs/cloudwatch-logs-investigation-guide.md`
  - `backend/rails/deploy/taskdef/dx-kpiee-stg.json`
  - `backend/go/deploy/taskdef/dx-kpiee-stg.json`

## atlas-kpiee

Source repo: `/Users/yuta.nakamura/workspace/github.com/f-scratch/atlas-kpiee`

- ECS cluster: `kpiee-stg`
- Major services/containers:
  - `atlas-kpiee-stg-rails`
  - `atlas-core-stg-rails`
  - `atlas-core-stg-scheduler`
  - `atlas-core-stg-provisioning`
  - `atlas-core-stg-workflow`
  - `atlas-core-stg-sfonline`
- CloudWatch log groups:
  - `/ecs/atlas-kpiee-stg`
  - `/ecs/atlas-kpiee-stg-migration`
  - `/ecs/atlas-core-stg`
  - `/ecs/atlas-core-stg-migration`
  - `/ecs/atlas-core-stg-scheduler`
  - `/ecs/atlas-core-stg-provisioning`
  - `/ecs/atlas-core-stg-workflow`
  - `/ecs/atlas-core-stg-sfonline`
- SSM parameter patterns:
  - `/dx-kpiee-stg/db-host`
  - `/kpiee-stg/db-read-host`
  - `/atlas-kpiee-stg/distribution_id`
- Key files:
  - `.github/workflows/deploy-staging.yml`
  - `backend/deploy/taskdef/atlas-kpiee-stg-rails.json`
  - `backend/deploy/taskdef/atlas-core-stg-*.json`
  - `backend/config/settings/staging.yml`

## atlas-core

Source repo: `/Users/yuta.nakamura/workspace/github.com/f-scratch/atlas-core`

- ECS cluster/service hints:
  - cluster ARN includes `kpiee-stg`
  - service ARN includes `atlas-core-stg-workflow`
- CloudWatch workflow reference exists in `CLAUDE.md`
- DB route patterns:
  - host pattern: `<project_env>-data-connector.mysql.rds.<private_domain>`
  - db pattern: `<project_env>_data_connector`
- Key files:
  - `rails/config/settings/staging.yml`
  - `.ansible/config/database.yml.j2`
  - `CLAUDE.md`

## Snowflake (`snow` CLI) Reference

### dx-kpiee (CLI query investigation baseline)

Source repo: `/Users/yuta.nakamura/workspace/github.com/f-scratch/dx-kpiee`

- Connection file:
  - `~/.snowflake/connections.toml` (example profile name: `kpiee`)
- Common commands:
  - `snow sql -c kpiee -q "SHOW SCHEMAS IN DATABASE DX_KPIEE_DEV;"`
  - `snow sql -c kpiee -q "USE SCHEMA DX_KPIEE_DEV.DEV_AC_0001; SHOW TABLES LIKE 'REPORT_%';"`
  - `snow sql -c kpiee -q "SELECT * FROM ..." --format json`
- Query history patterns:
  - near-real-time: `TABLE(information_schema.query_history(...))`
  - long-term analysis: `snowflake.account_usage.query_history`
- Environment DB/schema naming:
  - `DEV -> DX_KPIEE_DEV -> DEV_AC_%04d`
  - `IT -> DX_KPIEE_IT -> IT_AC_%04d`
  - `STG01 -> DX_KPIEE_STG01 -> STG01_AC_%04d`
  - `STG02 -> DX_KPIEE_STG02 -> STG02_AC_%04d`
  - `STG -> DX_KPIEE_STG -> STG_AC_%04d`
  - `PRD -> DX_KPIEE_PRD -> PRD_AC_%04d`
- Key files:
  - `CLAUDE.md` (Snowflake Query Investigation section)
  - `backend/go/.env.local.sample` (Snowflake env var names)

### atlas-kpiee (runtime connection hints)

Source repo: `/Users/yuta.nakamura/workspace/github.com/f-scratch/atlas-kpiee`

- STG Rails task hints:
  - `SETTINGS__SNOWFLAKE__DB_NAME=DX_KPIEE_STG`
  - `SETTINGS__SNOWFLAKE__WAREHOUSE=SHARE_XS`
  - account/role/user/private-key are injected via SSM secrets
- STG sfonline worker hints:
  - container: `atlas-core-stg-sfonline`
  - log group: `/ecs/atlas-core-stg-sfonline`
  - env/secrets include `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_ROLE`, `SNOWFLAKE_PRIVATE_KEY_PEM`
- Operational behavior docs:
  - sfonline uses Redis queue `snowflake_request_id`, executes Snowflake asynchronously, and publishes completion via AnyCable channel
- Key files:
  - `backend/deploy/taskdef/atlas-core-stg-rails.json`
  - `backend/deploy/taskdef/atlas-core-stg-sfonline.json`
  - `frontend/llms/sfonline.md`
  - `frontend/llms/use_sfonline.md`

## Refresh Procedure

1. Resolve repo paths with `ghq`.
2. Re-scan deployment/taskdef/docs files listed above.
3. Update this file with confirmed names only.
4. Keep scripts generic; never hardcode kpiee-specific defaults in `scripts/`.
