---
name: kpiee-local-smoke-check
description: kpiee の localhost 動作確認や local E2E 切り分けを進める skill。repo の役割、起動方法、port、log、認証付き API アクセス、DB 前提、HTTP 最小再現を整理し、ローカル確認を一貫した runbook として進めたいときに使う。
---

# KPIEE Local Smoke Check

## Overview

この skill は、kpiee のローカル確認を「場当たり的な調査」ではなく、再利用しやすい runbook として進めるための toolkit です。

- どの repo をどの port で起動するか迷いたくない
- 認証付き API をどう叩くのがよいか毎回考えたくない
- 500 や 403 がコード起因かローカル環境起因かを早く切り分けたい
- review worktree の差分を localhost で確かめたい
- 権限制御や IP 制限が DB 前提不足で見えていないのかを確かめたい

これは単発の incident memo ではなく、kpiee ローカル確認の共通入口です。
repo の役割、起動、認証、観測、DB 前提、再現方法を先に固定し、その上で個別 playbook に進む前提で使います。

## Scope

対象:

- `dx-kpiee` / `zelda-kpiee` の localhost 動作確認
- `ghq` 管理 repo と review worktree をまたいだ切り分け
- local API / browser / DB seed / schema / auth / log の切り分け

対象外:

- non-prod 環境の AWS / ECS / CloudWatch / Snowflake 調査
  - それは `kpiee-stg-log-db-check` を使う
- bastion に入って確認する作業
  - それは `kpiee-bastion-ops` を使う

## Structure

- `references/repo-and-startup-map.md`
  - repo の役割、主要 directory、起動コマンド、port の地図
- `references/authenticated-api-access.md`
  - 認証付き API アクセスの基本方針、token source、curl pattern
- `references/local-observability.md`
  - process ownership、log、port、ヘルスチェック、ログの読み方
- `references/data-prerequisites.md`
  - schema drift、DB seed、multi DB の前提、確認不足でハマりやすい点
- `references/ip-restriction-playbook.md`
  - IP 制限や許可 IP 系の確認軸、データ前提、比較方法

## Operating Rules

- 最初に repo の役割と「どの process がどの path から起動しているか」を確定する
- `ghq` 側 repo と review worktree の役割を混ぜない
- browser より先に、認証付き HTTP 最小再現を作る
- DB 依存の制御は、レコード有無を見ずに結論を出さない
- `.env.local` と schema drift は、コード不具合と同列の第一容疑者として扱う
- 報告では、repo path、起動 process、叩いた endpoint、auth source、関連 DB 状態、決定打ログを必ずセットで出す

## Entry Point

まず次の順で読む。

1. `references/repo-and-startup-map.md`
2. `references/local-observability.md`
3. `references/authenticated-api-access.md`
4. `references/data-prerequisites.md`

その後、症状に応じて必要な reference だけ読む。

- IP 制限、許可 IP、ヘッダ解釈が怪しい:
  - `references/ip-restriction-playbook.md`

## Default Runbook

迷ったらこの順に進める。

1. repo / directory / startup command を確定する
2. 対象 port と process ownership を確定する
3. `.env.local` と auth 初期化を確認する
4. unauth / auth の HTTP 最小再現を作る
5. schema drift と DB 前提を確認する
6. 症状別 playbook で再現条件を詰める
7. 必要なら browser E2E で UI 経路も確認する

## Reporting Contract

結果報告には最低限これを含める。

- どの repo / worktree を使ったか
- どう起動したか
- どの process / port を見たか
- 叩いた endpoint
- auth source
- 関連 DB レコードの有無
- HTTP status の比較結果
- 決定打になったログまたは SQL
