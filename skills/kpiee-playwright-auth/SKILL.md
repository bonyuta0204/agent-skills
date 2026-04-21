---
name: kpiee-playwright-auth
description: kpiee を playwright-cli で調査・自動化するときの認証を安定化する skill。人間が一度ログインして作った storageState を環境別に安全に再利用する。playwright-cli の state-save / state-load を前提とする。
---

# KPIEE Playwright Auth

kpiee を `playwright-cli` で触るときに、認証を「毎回の UI ログイン」ではなく `storageState` の再利用で扱う runbook。

前提: `npm install -g @playwright/cli@latest` で `playwright-cli` が使えること。
現状の `playwright-cli 0.1.6` では `open --headed` 単独が即終了することがあるため、人間ログインが必要な step では `--persistent` または `--profile` を付ける。
auth の受け渡し artifact は persistent profile ではなく `state-save` した json を正とする。

## State Directory

```
STATE_DIR = ~/.local/state/kpiee-playwright-auth/
```

- 呼び出し元ディレクトリに依存しない固定パス。state の正本は常にここ
- なければ `mkdir -p` で作る
- repo 内 (`playwright/.auth/` 等) には置かない

### playwright-cli の allowed roots 制約

`playwright-cli` は allowed roots 外のファイルを直接読めない。
state-load / state-save では、作業ディレクトリの `.playwright-cli/` を一時置き場として使う。

- **ロード時**: `STATE_DIR` から `.playwright-cli/auth-state.json` にコピーしてから `state-load`
- **セーブ時**: `.playwright-cli/auth-state.json` に `state-save` してから `STATE_DIR` にコピー
- **作業完了時**: `.playwright-cli/auth-state.json` を削除する (正本は `STATE_DIR` のみ)

### 命名規約

`{host}_{env}_{user-or-workspace}_{用途}.json`

- 軸の区切りは `_`、軸内のハイフンは `-`
- 用途がなければ `default`

例:

- `app-kpiee_prod_userA_default.json`
- `stg-kpiee_stg_ws72_investigation.json`

## Login URLs

| 環境 | URL |
| --- | --- |
| 本番 | `https://app.kpiee.com/users/sign_in` |
| STG | `https://stg.kpiee.xyz/users/sign_in` |
| localhost | `http://localhost/users/sign_in` |

### localhost の注意事項

- ログイン後は `http://localhost/dx/workspaces/:id/dashboards/:id` にリダイレクトされる
- atlas-kpiee（データコネクタ）は `http://localhost/dc/` でアクセスする
- localhost state の命名例: `localhost_local_default_default.json`
- localhost 用 state は prod / stg と **必ず分離する**（同じファイルを使い回さない）

## Core Rules

- 認証 state の取得・更新は本作業と独立した step にする
- `storageState` は host / env / user / workspace ごとに分離する
- state が怪しいときは DOM 操作を続けず、先に auth を再生成する
- MFA や SSO を毎回 AI に突破させない
- 認証情報 (password, token) は AI に渡さない — ログイン結果の state だけを扱う
- credential を `.env` や json に平文で置かない
- local / stg / prod で同じ state file を使い回さない
- `playwright-cli open --headed` 単独では開かない。headed login は `--persistent` または `--profile` を必ず付ける
- `.playwright-cli/auth-state.json` は一時ファイル。作業完了時に必ず削除し、正本は `STATE_DIR` のみ

## Auth Capture

headed browser で人間が一度ログインし、`state-save` で state を保存する。
`--headed` 単独は使わず、現状の workaround として persistent profile を併用する。

```bash
# 1. headed で login ページを開く
playwright-cli open https://app.kpiee.com/users/sign_in --headed --persistent

# 2. 人間がブラウザ上でログインを完了する

# 3. ログイン後に state を一時ファイルに保存
playwright-cli state-save .playwright-cli/auth-state.json

# 4. 正本を STATE_DIR にコピー
cp .playwright-cli/auth-state.json ~/.local/state/kpiee-playwright-auth/app-kpiee_prod_userA_default.json

# 5. 一時ファイル削除 & セッションを閉じる
rm .playwright-cli/auth-state.json
playwright-cli close
```

STG の場合は URL を `https://stg.kpiee.xyz/users/sign_in` に変える。
`--persistent` の user data dir は headed login の workaround としてのみ使い、継続利用の前提にはしない。

## Workflow

### 1. state を確認する

`STATE_DIR` に対象環境の file があるか確認する。あればそのまま使う。なければ Auth Capture で作る。

### 2. state をロードして auth を検証する

```bash
# STATE_DIR から一時コピー
cp ~/.local/state/kpiee-playwright-auth/app-kpiee_prod_userA_default.json .playwright-cli/auth-state.json

# state をロード (ページを開く前に実行可能)
playwright-cli state-load .playwright-cli/auth-state.json

# 一時ファイル削除
rm .playwright-cli/auth-state.json

# 認証が必要なページを開く
playwright-cli open https://app.kpiee.com/

# snapshot でページ状態を確認
playwright-cli snapshot
```

snapshot の結果で以下を確認する:

- URL が login ページに redirect されていない
- workspace selector や report title など画面固有の要素が見える

失敗したら Auth Capture に戻って state を再生成する。

### 3. 本作業を実行する

認証確認後にだけ操作に進む。
1 session 1 task を基本とし、前回の状態を引きずらない。

### 4. 失効時

途中で認証切れが起きたら:

1. `playwright-cli snapshot` で login redirect / 認証エラーを確認
2. `playwright-cli close` でセッションを閉じる
3. Auth Capture で state を再生成 (人間に再ログインしてもらう)
4. 新しいセッションで `STATE_DIR` → `.playwright-cli/` コピー → `state-load` して開き直す

無限リトライしない。

## References

- [/dx 画面構成マップ](references/dx-screen-map.md): 本番環境のサイドバー構成、各ページの URL パターンと機能概要

## Reporting Contract

結果報告には最低限これを含める。

- どの host で使う認証か
- 使った state file のパスと生成/更新時刻
- 認証確認に使った URL と snapshot の結果
- 失効時に再生成したかどうか
