---
name: github-pr-review-stocktake
description: 自分にアサインまたはレビュー依頼されている GitHub PR を棚卸しし、PR ごとに固定のレビュー支援コメントを更新するスキル。全量または repo 指定でバッチ処理し、どこから見ればよいか、どこは深追い不要か、人間が判断すべき論点は何かを整理したいときに使う。
---

# GitHub PR Review Stocktake PM

## 概要

この skill は **PR レビュワー支援専任** で動く。

- PM: 対象PRの発見、キュー管理、worker起動、品質ゲート、コメント更新、最終報告
- Worker: 単一PRの調査と JSON 返却のみ

目的は「AI がレビューする」ことではなく、**人間レビューワーの読み順と重点観点を先回りで整理する**こと。

各 PR には、必要に応じて固定のレビュー支援コメントを 1 本だけ作成または更新する。

## 使いどころ

- 自分に assign されている PR をまとめて棚卸ししたい
- 自分にレビュー依頼されている PR を repo 横断で順番に見ていきたい
- 特定 repo に絞ってレビュー待ちキューを整理したい
- PR ごとに「まずどこを見るか」「どこは深追い不要か」を先にコメントしておきたい

使わない場面:

- 単一 PR に対して深掘りレビュー結果をそのまま GitHub review として投稿するとき
- 実装修正や checkout ベースの詳細調査まで即座に進めるとき
- 既存の `pr-implementation-review` で 1 本の PR を丁寧にレビューしたいとき
- 責務配置や境界設計だけに論点を絞ってレビューしたいとき
- `kpiee-designs` の設計書 PR をレビューしたいとき

## 目的

- 人間レビューワーが読む前に、PR ごとのレビュー導線を作る
- 変更箇所とレビュー対象箇所を分離する
- `追従だけの箇所` と `本当に深く見る箇所` を見分けて残す
- レビュー箇所ごとに「臭い」「仕様確認寄り」「設計確認寄り」などの観点ラベルを付ける
- PR ごとに固定コメントを更新し、後から見返せる状態にする
- 全量または repo 指定で、assigned / review-requested PR をバッチ処理する

## 他の review skill との関係

- この skill はレビューの**前さばき**を担当する
- 単一 PR を深掘りする段階に入ったら `pr-implementation-review` へ渡す
- 責務配置、依存方向、境界設計が主論点なら `code-architecture-review` へ渡す
- 設計書 PR なら `review-design-doc` を使う

## やらないこと

- この skill 自体が最終レビュー判定を代行しない
- `APPROVE` / `REQUEST_CHANGES` を自動で出さない
- inline review comment を大量自動投稿しない
- 既存の人手コメントを上書きしない

## 入力

### 必須

- `selection_mode`: `assigned_all` | `repo_assigned` | `explicit_prs`

### 任意

- `repo_slug`: `owner/repo`
- `repo_path`: 対象ローカルリポジトリの絶対パス
- `pr_numbers`: `explicit_prs` のときの PR 番号配列
- `include_review_requested`: default `true`
- `include_assigned`: default `true`
- `include_drafts`: default `false`
- `max_workers`: default `3`
- `limit`: default `20`
- `sort`: default `updated_desc`
- `comment_mode`: default `sticky_upsert`
- `reference_hints`: default `[]`

`selection_mode=assigned_all` のときは、自分に assign または review request されている open PR を横断収集する。  
`selection_mode=repo_assigned` のときは `repo_slug` を必須とする。

## 対象発見ルール

- PR 探索は `gh search prs` を優先する
- 全量モードでは `--assignee @me` と `--review-requested @me` の両方を使い、重複は PM が統合する
- repo 指定モードでは `--repo <owner/repo>` を必ず付ける
- local repo が必要なときは `ghq` で repo path を解決する
- local repo が見つからない場合でも、`gh pr view` と `gh pr diff` による GitHub 上の情報優先の調査は許可する
- GitHub 上の情報だけで判断した箇所は `confidence` を下げ、コメントにもその前提を書く

## レビュー導線モデル

この skill のコアは、各 PR に対して次を整理すること:

- 何が実質的な変更か
- どの順番で読むと追いやすいか
- どういう注意で見るべき箇所か
- どこは追従だけなので深く読まなくてよいか
- どこが人間の設計判断ポイントか
- どこは AI が見た限り大きな論点ではないか
- どこは AI だけでは決め切れないか

「差分がある場所」と「レビューすべき場所」を混同しない。

加えて、「深く見るべき」だけでなく **どういう種類の警戒で見るか** を区別する。

- `SMELL`: 実装臭があり、diff の見た目以上に内部整合性を疑ったほうがよい
- `SPEC_CHECK`: 実装の良し悪しより先に、期待挙動や仕様ソースを確認したほうがよい
- `DESIGN_CHECK`: 責務分割、境界、DI、依存方向の妥当性を見たほうがよい
- `RISK_CHECK`: 互換性、副作用、transaction、権限、例外処理などの運用リスクを見たほうがよい
- `LOW_SIGNAL`: 既存追従や単純伝播で、深追い優先度は低い

## 境界

- Worker は **単一PR調査専用**
- Worker は GitHub 上の comment / review / label / assignee を更新しない
- PM だけが固定コメントを作成または更新する
- PM はコメント更新前に worker JSON を検証し、不十分なら 1 回だけ再試行する
- PM は既存の自分の棚卸しコメントだけを更新し、他人のコメントは変更しない

worker JSON 契約と固定コメントの必須情報要件は [references/worker-contract.md](references/worker-contract.md) を参照。

## コメント方針

コメントは **テンプレ固定にしない**。  
ただし、各 PR コメントは次の意味情報を必ず含む:

- PR の実質的な変更要約
- 推奨レビュー順
- 観点ラベル付きの重点観点
- 深追い不要と判断した箇所
- 深く見るべき箇所
- 人間が判断すべき論点
- AI が深追い優先度低めと見た箇所
- 根拠と不確実性

見出し名、段落構成、文章の流れは PR に応じて最適化してよい。
ただし、**GitHub 上で見やすい Markdown** を優先し、見出しと箇条書きだけで追える軽い構成にする。

色やラベルの見せ方は固定しない。  
ただしコメント上では、少なくとも `SMELL` / `SPEC_CHECK` / `DESIGN_CHECK` / `RISK_CHECK` / `LOW_SIGNAL` の区別が読者に分かるように表現する。

詳細な構成ルールとサンプルは [references/comment-format.md](references/comment-format.md) を参照。

## 状態ファイル

並列キューを安全に再開できるよう、PM は状態を永続化する。

保存場所:

```text
${TMPDIR:-/tmp}/github-pr-review-stocktake-<scope-safe>.json
```

最低限保持する項目:

- `scope`
- `prs.<repo>#<number>.status`
- `prs.<repo>#<number>.retry_count`
- `prs.<repo>#<number>.comment_action`
- `prs.<repo>#<number>.last_confidence`
- `prs.<repo>#<number>.failure_kind`

状態変更の直後に書き出し、再開時はこのファイルから復元する。

## 失敗分類

- `needs_user_input`: 対象範囲や repo 指定が不足している
- `repo_resolution_failure`: `ghq` で local repo を引けず、remote-only でも足りない
- `worker_contract_failure`: JSON 不正、必須不足、意味情報不足
- `worker_execution_failure`: worker の途中失敗、ツール失敗、タイムアウト
- `comment_update_failure`: 固定コメントの作成または更新に失敗

`worker_contract_failure` や `comment_update_failure` を、そのままレビュー論点に見せかけない。

## 進め方

### 0) 再開確認

1. state file があれば読み込み、未完了PRから再開する
2. state file が無ければ新規キューを作る

### 1) 対象確定

1. `selection_mode` から対象PR集合を確定する
2. `assigned_all` のときは `gh search prs --assignee @me --state open` と `gh search prs --review-requested @me --state open` を使う
3. `repo_assigned` のときは repo 指定で絞る
4. draft を除外するなら `isDraft` を見て落とす
5. `updatedAt` などで優先順を決め、各PRを `pending` で state file に記録する

### 2) Worker Pool Loop

`max_workers` 分のスロットで処理する。

```text
初期: pending から max_workers 件を起動
ループ:
  完了した worker を 1 件受け取る
  -> Validate
  -> 判定整理
  -> Render
  -> Upsert Comment
  -> state file 更新
  -> 空きスロットへ次の pending を投入
終了: pending / in_flight が 0 になったら最終報告
```

### 3) Worker 起動

- Worker agent 定義: `agents/openai-worker.yaml`
- 1 PR = 1 Worker
- `reference_hints` があれば、その PR に関係あるものだけ渡す
- local repo があるなら repo ルール、隣接実装、diff を見る
- local repo が無ければ GitHub 上の情報優先で `gh pr view` / `gh pr diff` を使う

### 4) 検証と判定整理

- worker JSON が契約を満たすか確認する
- `review_route` が空なら reject
- `attention_signals` が空なら reject
- `pass_through_paths` と `real_review_targets` の両方が空なら reject
- `human_judgment_calls` がゼロでもよいが、その場合は low-risk とする根拠が必要
- reject 時は同一 task を 1 回だけ再試行する

### 5) 文面生成

- コメント本文は固定テンプレートでなくてよい
- ただし、[references/worker-contract.md](references/worker-contract.md) の semantic slots を全て満たす
- Markdown の骨格は [references/comment-format.md](references/comment-format.md) に合わせる
- 1 PR につき 1 コメントにまとめる
- コメントには marker を入れ、PM が次回 safely upsert できるようにする

### 6) コメント反映

- 自分の既存の棚卸しコメントがあれば更新し、無ければ作成する
- marker 例:

```md
<!-- AI_PR_REVIEW_STOCKTAKE_START -->
...
<!-- AI_PR_REVIEW_STOCKTAKE_END -->
```

- 更新対象はこの marker を含む **自分のコメントのみ**
- 他人の review comment、discussion、summary comment は触らない

### 7) 最終報告

- 処理した PR 一覧
- コメント作成/更新結果
- GitHub 上の情報だけで判定した PR
- `failure_kind` と再試行状況
- 深掘りレビューへ進むべき PR 候補

## レビュー上の目安

`深追い不要` とみなす候補:

- 引数や型をそのまま次レイヤへ渡しているだけ
- rename や interface 伝播だけで意味変化がない
- 分岐、validation、副作用、transaction 境界が増えていない

`本当に深く見る箇所` とみなす候補:

- 条件分岐や validation が変わった
- transaction / permission / serialization / external I/O が変わった
- 既存パターンから責務分割が変わった
- repository / gateway / usecase の境界が変わった
- 例外処理、再実行性、互換性の論点がある

`SPEC_CHECK` を強める候補:

- 挙動の正しさが repo ルールや実装慣例だけでは決め切れない
- PR 本文、issue、spec、design doc を見ないと良否判定がぶれる
- 既存挙動が暗黙仕様に見える

`SMELL` を強める候補:

- I/F 変更が深く伝播しているのに、途中で責務の境界が曖昧
- DI や adapter が単なる受け渡し以上のことをしている
- 条件分岐が局所的に増えているのに、テストや説明が薄い

`DESIGN_CHECK` を強める候補:

- layer をまたいだ依存が増えている
- usecase / service / repository の置き場所に迷いがある
- 既存パターンと意図的に違うように見える

`RISK_CHECK` を強める候補:

- migration、権限、外部I/O、serialize/deserialize、例外処理が絡む
- 後方互換や再実行性に影響しうる

## 対話ルール

- ユーザーに毎PRごとの承認を求めない
- 範囲指定や repo 指定が曖昧なときだけ確認する
- GitHub 上の情報だけで判定して精度が落ちる場合は、その前提を明示する
- 固定コメントは「AI の結論」ではなく「レビュー導線」として書く
- 人間判断が必要な箇所は断定せず、判断ポイントとして置く

## コマンド例

```bash
# 全量: assign + review-requested を検索
gh search prs --assignee @me --state open --json number,title,url,repository,updatedAt,isDraft
gh search prs --review-requested @me --state open --json number,title,url,repository,updatedAt,isDraft

# repo 指定
gh search prs --repo owner/repo --assignee @me --state open --json number,title,url,repository,updatedAt,isDraft

# PR 概要と diff
gh pr view 123 --repo owner/repo --json title,body,files,reviews,comments,commits,url
gh pr diff 123 --repo owner/repo

# repo path 解決
ghq list -p | rg '/owner/repo$'
```

## 同梱ファイル

- `agents/openai.yaml`: PM agent interface
- `agents/openai-worker.yaml`: worker agent interface
- `references/worker-contract.md`: worker JSON 契約と固定コメントの意味スロット
