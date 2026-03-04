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

## Refresh Procedure

1. Resolve repo paths with `ghq`.
2. Re-scan deployment/taskdef/docs files listed above.
3. Update this file with confirmed names only.
4. Keep scripts generic; never hardcode kpiee-specific defaults in `scripts/`.
