---
name: github-pr-stockgtake
description: 自分が author の open PR を repo 横断または repo 指定で棚卸しし、概要・状況・ネクストアクションを整理したうえで、安全なものだけ AI で自動対応まで進めるスキル。
---

# GitHub PR Stockgtake PM

## Overview

この skill は **PR author support 専任** で動く。

- PM: 対象PRの発見、キュー管理、worker起動、実行可否判定、最終報告
- Worker: 単一PRの状況調査と action proposal 返却

目的は、**自分が author の PR 群を一気に棚卸しし、AI が人手なしで進められるものだけ前に進める** こと。

reviewer 向けの導線整理ではなく、author 視点で次を揃える。

- PR が何をしているか
- いま何で止まっているか
- 次に author が何をすべきか
- AI がその場で代行できるか

## When To Use

- 自分が author の open PR を repo 横断で棚卸ししたい
- PR ごとに `概要 / 状況 / next action` を短く整理したい
- 単純な review 指摘、lint failure、pending CI、再 review 依頼などを AI に進めさせたい
- stale な PR を revive / close 候補として仕分けたい

使わない場面:

- 単一 PR の深い実装レビューをしたいとき
- reviewer 向けの読み順や注目点を整理したいとき
- 複雑な conflict 解消や大きい設計変更まで一気にやりたいとき
- 自分が author ではない PR を棚卸ししたいとき

reviewer 視点の整理は `github-pr-review-stocktake` を使う。

## Goals

- author の open PR を横断で見える化する
- PR ごとに `概要 / 状況 / next action` を短く揃える
- `AI で即対応できるもの` と `人が判断すべきもの` を分ける
- 安全な自動対応だけを実行し、危険な判断は人へ返す
- 中断しても state file から再開できるようにする

## Non-Goals

- merge / close の最終判断を AI が勝手に行わない
- 大きな仕様変更や PR スコープ変更を AI が勝手に行わない
- 複雑な conflict を自動解消しない
- 他人の review comment や issue comment を更新しない

## Inputs

### Required

- `selection_mode`: `author_all` | `repo_author` | `explicit_prs`

### Optional

- `repo_slug`
- `repo_path`
- `pr_numbers`
- `include_drafts`: default `true`
- `limit`: default `20`
- `sort`: default `updated_desc`
- `max_workers`: default `3`
- `auto_act`: default `false`
- `safe_mode`: `report_only` | `safe_actions`
- `reference_hints`: default `[]`

`selection_mode=author_all` のときは、自分が author の open PR を repo 横断で集める。  
`selection_mode=repo_author` のときは `repo_slug` を必須とする。

## Discovery Rules

- PR 探索は `gh search prs --author @me --state open` を優先する
- 詳細取得は `gh pr view --json ...` を使う
- local repo が必要なときは `ghq` で path を解決する
- local repo がなくても remote-first で調査は継続してよい
- remote-only の判断は `confidence` を下げる

## Status Model

各 PR を author 視点で次の category に正規化する。

- `ready_waiting_review`
- `waiting_for_author_changes`
- `failing_checks`
- `waiting_ci`
- `conflicting`
- `draft_wip`
- `stale_needs_decision`

判定ルールと `ai_actionability` は [references/status-model.md](references/status-model.md) を参照。

## Auto Action Boundary

`auto_act=true` でも、AI が実行してよいのは **safe action** のみ。

具体例:

- lint / test failure の再現と局所修正
- 単純な review 指摘への対応
- conflict なしの branch 同期
- pending / waiting check の再実行
- `dx-kpiee` の `test` environment 承認待ち解除
- 自分の PR への補足コメント追加
- reviewer 再依頼コメントの投稿

やってはいけないこと:

- close / merge の最終判断
- 複雑な conflict 解消
- PR の目的変更
- milestone や release 判断の意味決め

詳細は [references/safe-auto-actions.md](references/safe-auto-actions.md) を参照。

## Worker Contract

worker は単一 PR 専用で、次を返す。

- `summary`
- `status_category`
- `blocking_facts`
- `next_action`
- `ai_actionability`
- `auto_action_candidates`
- `needs_human_decision`
- `confidence`

契約の詳細は [references/worker-contract.md](references/worker-contract.md) を参照。

## State File

保存場所:

```text
${TMPDIR:-/tmp}/github-pr-stockgtake-<scope-safe>.json
```

最低限保持する項目:

- `scope`
- `prs.<repo>#<number>.status`
- `prs.<repo>#<number>.status_category`
- `prs.<repo>#<number>.ai_actionability`
- `prs.<repo>#<number>.attempt_count`
- `prs.<repo>#<number>.execution_result`
- `prs.<repo>#<number>.failure_kind`

## Workflow

### 0) Resume Check

1. state file があれば読み込み、未完了PRから再開する
2. なければ新規キューを作る

### 1) Intake

1. `selection_mode` から対象 PR を確定する
2. `author_all` では `gh search prs --author @me --state open` を使う
3. draft の扱いを `include_drafts` で決める
4. `updatedAt` 順で優先度を付ける

### 2) Inspect

1. repo ごと、または PR ごとに worker を並列起動する
2. worker は `gh pr view`, `gh pr checks`, 必要なら local repo を見る
3. `概要 / 状況 / next action / ai_actionability` を返す

### 3) Normalize

1. `status_category` を正規化する
2. `ai_actionability` を `auto_fixable | auto_retryable | human_decision | human_review_needed` へ寄せる
3. 低 confidence のものには理由を残す

### 4) Auto Act

`auto_act=false` ならこの段階はスキップする。

`auto_act=true` のとき:

1. `auto_fixable` / `auto_retryable` のみ実行候補にする
2. safe action か検証する
3. 実行前に local で再現できるものは再現する
4. 実行後に PR 状態を再取得して結果を記録する
5. 危険なら `needs_human` に落とす

### 5) Report

最終報告では最低限次を返す。

- repo 横断の要約
- PR ごとの `概要 / 状況 / next action`
- AI が実施した action と結果
- 人の判断が必要な PR
- 今すぐ触る順

## Reporting Style

- 基本は短い日本語
- PR ごとに長文の history を書かず、現状に絞る
- `概要 / 状況 / ネクストアクション` の 3 点を優先する
- user が望まない限り、GitHub への大量コメント更新はしない

## Failure Taxonomy

- `needs_user_input`
- `repo_resolution_failure`
- `worker_execution_failure`
- `worker_contract_failure`
- `auto_action_blocked`
- `auto_action_failed`

`auto_action_blocked` は失敗ではなく、安全側に倒した結果として扱う。
