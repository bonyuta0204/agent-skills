---
name: github-pr-stockgtake
description: 自分が作成者の open PR を repo 横断または repo 指定で棚卸しし、概要・状況・次の一手を整理したうえで、安全なものだけ AI で自動対応まで進めるスキル。
---

# GitHub PR Stockgtake PM

## 概要

この skill は **PR 作成者支援専任** で動く。

- PM: 対象PRの発見、キュー管理、worker起動、実行可否判定、最終報告
- Worker: 単一PRの状況調査と対応案の返却

目的は、**自分が作成者の PR 群を一気に棚卸しし、AI が人手なしで進められるものだけ前に進める** こと。

レビュワー向けの導線整理ではなく、PR 作成者の視点で次を揃える。

- PR が何をしているか
- いま何で止まっているか
- 次に PR 作成者が何をすべきか
- AI がその場で代行できるか

## 使いどころ

- 自分が作成者の open PR を repo 横断で棚卸ししたい
- PR ごとに `概要 / 状況 / 次の一手` を短く整理したい
- 単純な review 指摘、lint failure、pending CI、再 review 依頼などを AI に進めさせたい
- stale な PR を revive / close 候補として仕分けたい

使わない場面:

- 単一 PR の深い実装レビューをしたいとき
- レビュワー向けの読み順や注目点を整理したいとき
- 複雑な conflict 解消や大きい設計変更まで一気にやりたいとき
- 自分が作成者ではない PR を棚卸ししたいとき

レビュワー視点の整理は `github-pr-review-stocktake` を使う。

## 目的

- 作成者として抱えている open PR を横断で見える化する
- PR ごとに `概要 / 状況 / 次の一手` を短く揃える
- `AI で即対応できるもの` と `人が判断すべきもの` を分ける
- 安全な自動対応だけを実行し、危険な判断は人へ返す
- 中断しても state file から再開できるようにする

## やらないこと

- merge / close の最終判断を AI が勝手に行わない
- 大きな仕様変更や PR スコープ変更を AI が勝手に行わない
- 複雑な conflict を自動解消しない
- 他人の review comment や issue comment を更新しない

## 入力

### 必須

- `selection_mode`: `author_all` | `repo_author` | `explicit_prs`

### 任意

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

## 対象発見ルール

- PR 探索は `gh search prs --author @me --state open` を優先する
- 詳細取得は `gh pr view --json ...` を使う
- local repo が必要なときは `ghq` で path を解決する
- local repo がなくても GitHub 上の情報優先で調査は継続してよい
- GitHub 上の情報だけでの判断は `confidence` を下げる

## 状態分類

各 PR を作成者視点で次の category に正規化する。

- `ready_waiting_review`
- `waiting_for_author_changes`
- `failing_checks`
- `waiting_ci`
- `conflicting`
- `draft_wip`
- `stale_needs_decision`

判定ルールと `ai_actionability` は [references/status-model.md](references/status-model.md) を参照。

## 自動対応の境界

`auto_act=true` でも、AI が実行してよいのは **安全に実行できる対応** のみ。

具体例:

- lint / test failure の再現と局所修正
- 単純な review 指摘への対応
- conflict なしの branch 同期
- pending / waiting check の再実行
- `dx-kpiee` の `test` environment 承認待ち解除
- 自分の PR への補足コメント追加
- レビュワーへの再依頼コメントの投稿

やってはいけないこと:

- close / merge の最終判断
- 複雑な conflict 解消
- PR の目的変更
- milestone や release 判断の意味決め

詳細は [references/safe-auto-actions.md](references/safe-auto-actions.md) を参照。

## ワーカー契約

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

## 状態ファイル

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

## 進め方

### 0) 再開確認

1. state file があれば読み込み、未完了PRから再開する
2. なければ新規キューを作る

### 1) 対象確定

1. `selection_mode` から対象 PR を確定する
2. `author_all` では `gh search prs --author @me --state open` を使う
3. draft の扱いを `include_drafts` で決める
4. `updatedAt` 順で優先度を付ける

### 2) 調査

1. repo ごと、または PR ごとに worker を並列起動する
2. worker は `gh pr view`, `gh pr checks`, 必要なら local repo を見る
3. `概要 / 状況 / 次の一手 / ai_actionability` を返す

### 3) 判定整理

1. `status_category` を正規化する
2. `ai_actionability` を `auto_fixable | auto_retryable | human_decision | human_review_needed` へ寄せる
3. 低 confidence のものには理由を残す

### 4) 自動対応

`auto_act=false` ならこの段階はスキップする。

`auto_act=true` のとき:

1. `auto_fixable` / `auto_retryable` のみ実行候補にする
2. 安全に実行できる対応か検証する
3. 実行前に local で再現できるものは再現する
4. 実行後に PR 状態を再取得して結果を記録する
5. 危険なら `needs_human` に落とす

### 5) 最終報告

最終報告では最低限次を返す。

- repo 横断の要約
- PR ごとの `概要 / 状況 / 次の一手`
- AI が実施した対応と結果
- 人の判断が必要な PR
- 今すぐ触る順

出力は **Markdown 形式** で整え、見出しと箇条書きだけで追える軽いレイアウトを使う。  
詳細な見出し構成とサンプルは [references/report-format.md](references/report-format.md) を参照。

## 報告文の方針

- 基本は短い日本語
- PR ごとに長文の history を書かず、現状に絞る
- `概要 / 状況 / ネクストアクション` の 3 点を優先する
- 生の enum や JSON をそのまま並べず、まず人が読める日本語へ言い換える
- table や過剰な装飾は避け、通常の Markdown 見出しと箇条書きを優先する
- 空の section は出さない
- user が望まない限り、GitHub への大量コメント更新はしない

## 失敗分類

- `needs_user_input`
- `repo_resolution_failure`
- `worker_execution_failure`
- `worker_contract_failure`
- `auto_action_blocked`
- `auto_action_failed`

`auto_action_blocked` は失敗ではなく、安全側に倒した結果として扱う。
