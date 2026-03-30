---
name: kpiee-bastion-ops
description: kpiee の non-prod 環境で、踏み台 EC2 を経由した日常的な確認・調査作業を安全に進める skill。踏み台特定は共有 bastion 優先、失敗時のみ SSM online な候補へ fallback する。
---

# KPIEE Bastion Ops

## Overview

この skill は、kpiee の non-prod 環境で「踏み台に入ってちょっと確認する」を安全に回すための toolkit です。

対象は次のような日常作業です。

- ホスト名、時刻、ユーザー、稼働確認
- ファイルやディレクトリの存在確認
- process / port / DNS / route の確認
- MySQL client や各種 CLI の疎通確認
- 小さな確認 script を bastion 上で一時実行
- 定常停止している non-prod 環境の ECS / RDS の起動

この skill は bastion 作業自体のためのものです。
DB 調査や CloudWatch / ECS / Snowflake を含む広い調査は、必要に応じて `kpiee-stg-log-db-check` を使います。

## Scope

live scope は次の non-prod 環境です。

- `it`
- `stg`
- `stg01`
- `stg02`

踏み台の選び方は `kpiee-stg-log-db-check` と揃えます。

- まず共有 bastion `kpiee-infra-dev` を試す
- 使えなければ、SSM で online な EC2 のうち `bastion|jump|infra|ops|admin` に寄る名前を優先して fallback する

## Structure

- `scripts/preflight.sh`: ローカル依存と AWS 認証の確認
- `scripts/list_bastion_candidates.sh`: 候補の見える化
- `scripts/run_command_via_bastion_ssm.sh`: bastion 上で確認コマンドや script を実行
- `scripts/start_env_via_bastion_ssm.sh`: `it|stg|stg01|stg02` を引数で受け、target list 確認、RDS 起動、ECS 起動、post-check までをまとめて実行
- `references/kpiee-bastion-reference.md`: bastion 運用の前提と確認済み情報

## Operating Rules

- まず対象 env を固定する。`stg` と `stg01` / `stg02` を混ぜない。
- `AWS_REGION` は明示するか、ローカル設定を確認する。迷ったら `us-west-2` から始める。
- 既定は read-only。変更系コマンドは `--force` を付けたうえで、本当に必要なときだけ実行する。
- secret の全文表示は避ける。必要なら key 名、件数、存在有無、prefix 程度に留める。
- 長時間の常駐操作より、短い非対話コマンドを積む。
- 報告は bastion、route、UTC 時刻、実行コマンドの意図、主要な stdout / stderr をセットで出す。
- `/opt/work/infra/script/*/(restart|stop)_*.sh` の実行は変更系として扱い、必ず `--force` を付ける。

## Preflight

最初にこれを実行する。

```bash
scripts/preflight.sh
```

確認内容:

- required local commands: `aws`, `jq`, `python3`, `session-manager-plugin`
- optional local commands: `mysql`, `nc`, `dig`
- AWS auth: `aws sts get-caller-identity`
- effective region: `AWS_REGION` または AWS config

region が曖昧なら明示する。

```bash
export AWS_REGION=us-west-2
```

## Bastion Selection

候補確認だけしたいときは次を使う。

```bash
scripts/list_bastion_candidates.sh
scripts/list_bastion_candidates.sh us-west-2
```

期待する通常経路:

1. `kpiee-infra-dev` を解決する
2. その route が失敗したら heuristic candidate に切り替える

明示的に bastion を固定したいときだけ `--bastion-instance` を使う。

## Tool: Run Read-Only Command

最小の使い方:

```bash
scripts/run_command_via_bastion_ssm.sh \
  --cmd 'hostname && whoami && date -u'
```

この script は:

- 共有 bastion 優先の route を使う
- command を一時 script にして SSM `AWS-RunShellScript` で流す
- `stdout` / `stderr` / `status` / `command_id` を JSON で返す
- 既定 route が失敗したら discovered bastion に 1 回だけ retry する

## Tool: Run Local Script File

複数行の確認をしたいときは `--script-file` を使う。

```bash
cat > /tmp/check-runtime.sh <<'SH'
set -euo pipefail
hostname
date -u
ps aux | grep -E 'rails|puma|sidekiq' | grep -v grep || true
SH

scripts/run_command_via_bastion_ssm.sh \
  --script-file /tmp/check-runtime.sh
```

write 系や service 変更を含む script は、意図的に `--force` を付けない限り弾かれる。

## Common Recipes

### Host Identity

```bash
scripts/run_command_via_bastion_ssm.sh \
  --cmd 'hostname && uname -a && id && date -u'
```

### File Presence

```bash
scripts/run_command_via_bastion_ssm.sh \
  --cmd 'ls -ld /var/log /etc /home/ec2-user'
```

### Process Check

```bash
scripts/run_command_via_bastion_ssm.sh \
  --cmd 'ps aux | grep -E "mysql|redis|ssh" | grep -v grep || true'
```

### Port / DNS Check

```bash
scripts/run_command_via_bastion_ssm.sh \
  --cmd 'nc -vz example.internal 3306 && getent hosts example.internal || true'
```

### MySQL Client Reachability

DB query そのものではなく、client の有無や疎通だけ見たいとき:

```bash
scripts/run_command_via_bastion_ssm.sh \
  --cmd 'mysql --version'
```

実 DB query が目的なら、`kpiee-stg-log-db-check` の `mysql_query_via_bastion_ssm.sh` を優先する。

## Procedure: Bring Up ECS / RDS

踏み台上には、各環境の ECS / RDS を起動する既存 script がある。

- `/opt/work/infra/script/it/ecs/restart_ecs.sh`
- `/opt/work/infra/script/it/rds/restart_rds.sh`
- `/opt/work/infra/script/stg/ecs/restart_ecs.sh`
- `/opt/work/infra/script/stg/rds/restart_rds.sh`
- `/opt/work/infra/script/stg01/ecs/restart_ecs.sh`
- `/opt/work/infra/script/stg01/rds/restart_rds.sh`
- `/opt/work/infra/script/stg02/ecs/restart_ecs.sh`
- `/opt/work/infra/script/stg02/rds/restart_rds.sh`

それぞれ次の target list を読む。

- ECS: `/opt/work/infra/script/<env>/ecs/target_service_lists.txt`
- RDS: `/opt/work/infra/script/<env>/rds/target_db_instance_lists.txt`

ECS の restart script は target list にある各 service に対して `desired-count 1` を設定する。
RDS の restart script は target list にある各 DB instance に対して `aws rds start-db-instance` を実行する。

### Recommended Order

通常は次の順で進める。

1. 対象 env を固定する
2. target list を読んで、起動対象が想定どおりか確認する
3. RDS を起動する
4. ECS を起動する
5. 主要 service / DB が上がったかを確認する

この一連の手順をまとめて流したいときは、専用 wrapper を使う。

```bash
scripts/start_env_via_bastion_ssm.sh stg
scripts/start_env_via_bastion_ssm.sh stg01 --wait-seconds 1200
```

この wrapper は次を行う。

- bastion 上の target list を表示
- RDS は target list を読みつつ、read replica topology の instance を skip して、起動可能な DB だけを個別に start する
- ECS は target list の各 service に `desired-count 1` を設定する
- RDS / ECS の post-check を poll して、ready になるまで待つ

`ssm:DescribeInstanceInformation` が制限される環境でも動かしやすいように、既定では共有 bastion の instance ID を明示指定する。

### Inspect the Target List First

```bash
scripts/run_command_via_bastion_ssm.sh \
  --cmd 'sed -n "1,120p" /opt/work/infra/script/stg/rds/target_db_instance_lists.txt'

scripts/run_command_via_bastion_ssm.sh \
  --cmd 'sed -n "1,120p" /opt/work/infra/script/stg/ecs/target_service_lists.txt'
```

### Start RDS

```bash
scripts/run_command_via_bastion_ssm.sh \
  --force \
  --cmd 'bash /opt/work/infra/script/stg/rds/restart_rds.sh'
```

### Start ECS

```bash
scripts/run_command_via_bastion_ssm.sh \
  --force \
  --cmd 'bash /opt/work/infra/script/stg/ecs/restart_ecs.sh'
```

`stg` を `it` / `stg01` / `stg02` に置き換えれば他環境でも同じ。

### Post-Check Examples

RDS 側:

```bash
scripts/run_command_via_bastion_ssm.sh \
  --cmd 'aws rds describe-db-instances --region us-west-2 --db-instance-identifier kpiee-stg-2024-09-04 --query "DBInstances[0].DBInstanceStatus" --output text'
```

ECS 側:

```bash
scripts/run_command_via_bastion_ssm.sh \
  --cmd 'aws ecs describe-services --cluster kpiee-stg --services kpiee-stg dx-kpiee-stg atlas-kpiee-stg-rails --query "services[].{service:serviceName,desired:desiredCount,running:runningCount}" --output table'
```

起動失敗時は、script の stdout / stderr と対象 list をそのまま evidence に含める。

## Reporting Contract

常に次を含めて返す。

- target env
- selected route と bastion instance
- 実行した command / script の意図
- 実行時刻の UTC
- 主要な stdout / stderr
- `found` / `not found`
- 権限不足や command 不在などの制約

## Resources

- `scripts/preflight.sh`
- `scripts/list_bastion_candidates.sh`
- `scripts/run_command_via_bastion_ssm.sh`
- `references/kpiee-bastion-reference.md`
