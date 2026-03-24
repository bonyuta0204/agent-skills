# KPIEE Bastion Reference

この reference は `kpiee-bastion-ops` 用です。
踏み台の選定ルールは `kpiee-stg-log-db-check` と揃えます。

## Scope

- `it`
- `stg`
- `stg01`
- `stg02`

## Common AWS Baseline

- confirmed AWS account on 2026-03-07: `776591296688`
- confirmed AWS region on 2026-03-07: `us-west-2`

## Default Bastion

通常経路の共有 bastion:

- Name: `kpiee-infra-dev`
- Instance ID: `i-05cb1b41cda7e3806`
- State on 2026-03-07: `running`
- SSM `AWS-RunShellScript` execution: success

補足:

- `kpiee-infra-stg` は存在するが、2026-03-07 時点では `stopped`
- non-prod の既定踏み台としては扱わない

## Fallback Heuristic

既定 bastion が使えないときだけ、次の条件で候補を探す。

- SSM で online な EC2
- instance name に `bastion|jump|infra|ops|admin` を含むものを優先
- それでも複数ある場合は name, instance_id 順で安定ソートする

## Usage Notes

- 踏み台選定は hint 扱いで、重要な操作では毎回 live 状態を再確認する
- `stg` と `stg01` / `stg02` は別環境として扱う
- bastion 上では変更系より確認系を優先し、常に最小権限で進める
