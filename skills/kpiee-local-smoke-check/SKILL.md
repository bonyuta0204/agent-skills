---
name: kpiee-local-smoke-check
description: kpiee の localhost 動作確認や local E2E 切り分けを進める skill。`dx-kpiee` / `zelda-kpiee` の ghq 管理 repo と review worktree を使い分け、起動中 process、`.env.local`、schema drift、auth、DB seed、HTTP 最小再現のどこで詰まっているかを順番に切り分けたいときに使う。
---

# KPIEE Local Smoke Check

## Overview

この skill は、kpiee のローカル確認で次のような詰まり方を短時間で切り分けるための toolkit です。

- review worktree の差分を localhost で確かめたい
- 画面では 500 だが、コードの問題か環境の問題か分からない
- `.env.local` や auth 初期化が壊れていそう
- IP 制限や権限制御が DB seed 不足で見えていないか確かめたい

これは「今回の 1 件の調査ログ」ではなく、kpiee ローカル調査の共通入口です。
固定の長い手順を毎回なぞるのではなく、最初に runtime ownership を確定し、その後は症状に応じた playbook だけを読む前提で使います。

## Scope

対象:

- `dx-kpiee` / `zelda-kpiee` の localhost 動作確認
- `ghq` 管理 repo と review worktree をまたいだ切り分け
- local API / browser / DB seed / schema / auth の切り分け

対象外:

- non-prod 環境の AWS / ECS / CloudWatch / Snowflake 調査
  - それは `kpiee-stg-log-db-check` を使う
- bastion に入って確認する作業
  - それは `kpiee-bastion-ops` を使う

## Structure

- `references/runtime-and-preflight.md`
  - repo path、起動中 process、`.env.local`、schema drift を最初に潰す
- `references/http-and-auth-checks.md`
  - unauth / auth / browser session / curl 最小再現の組み立て
- `references/ip-restriction-playbook.md`
  - IP 制限や許可 IP 系の確認軸、seed、比較方法

## Operating Rules

- 最初に「どの process がどの path から起動しているか」を確定する
- `ghq` 側 repo と review worktree の役割を混ぜない
- browser より先に、HTTP 最小再現を作る
- DB 依存の制御は、レコード有無を見ずに結論を出さない
- `.env.local` と schema drift は、コード不具合と同列の第一容疑者として扱う
- 報告では、repo path、起動 process、叩いた endpoint、auth source、関連 DB 状態、決定打ログを必ずセットで出す

## Entry Point

まず `references/runtime-and-preflight.md` を開いて、次を確定する。

1. repo path
2. 実際に listen している process
3. `ghq` 側と review worktree の `.env.local` 差分
4. schema drift の有無

その後、症状に応じて必要な reference だけ読む。

- 認証や localhost API 疎通が怪しい:
  - `references/http-and-auth-checks.md`
- IP 制限、許可 IP、ヘッダ解釈が怪しい:
  - `references/ip-restriction-playbook.md`

## Default Debug Order

迷ったらこの順に潰す。

1. repo discovery と runtime ownership
2. `.env.local` 差分
3. schema drift
4. unauth / auth の基本疎通
5. DB seed / 対象レコードの存在確認
6. curl での最小再現
7. browser E2E

## Reporting Contract

結果報告には最低限これを含める。

- どの repo / worktree を使ったか
- どの process / port を見たか
- 叩いた endpoint
- auth source
- 関連 DB レコードの有無
- HTTP status の比較結果
- 決定打になったログまたは SQL
