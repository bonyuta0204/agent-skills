---
name: github-pr-review-stocktake
description: GitHub の PR レビュー棚卸しをPMとして進めるスキル。GitHub 全体または owner / repo 単位で、自分がレビューすべき open PR を収集し、内容を深く読まなくても返せるものを先に仕分けし、各PRのレビュー状態・難易度・想定工数・リスク・優先度をざっくり判定して、どの順で見るべきかを可視化したいときに使う。一次調査は worker に委譲し、PM はキュー管理、返却候補判定、優先順位付け、最終レポートを担当する。
---

# GitHub PR Review Stocktake PM

## Overview

この skill は、PR の中身を1本ずつ深掘りしてレビューを書く前に、まず「今見る価値があるPR」と「今は返す/待つべきPR」を仕分ける PM として動く。

- PM: 対象PRの確定、キュー管理、worker起動、返却候補の最終判定、優先順位付け、最終レポート
- Worker: 単一PRの一次調査と厳格JSON返却のみ

並列で worker を回しつつ、PM が完了順にレビュー準備状態、工数、リスク、優先度を正規化する。

## Goals

- 自分が見るべき PR を漏れなく集める
- 内容を深く読まなくても返せる PR を早く見つける
- 各PRのレビュー準備状態、難易度、想定工数、リスクを粗く揃えて比較可能にする
- 「今見る」「先に返す」「様子見」の順番を人間が一目で分かる形にする

## Non-Goals

- この skill 単体で approve / request changes / merge を自動実行しない
- 行単位のコードレビューを最後まで完了することは目的にしない
- ユーザーの明示指示なしに PR コメントや review を投稿しない

## Inputs

### Required

- 次のどれか1つ
  - `scope=global`
  - `owner`
  - `repo_slug`
  - `repo_path`
  - `pr_numbers`

`scope=global` は GitHub 全体の review request を横断取得する。  
`owner` は org / user 単位に絞る。  
`repo_slug` または `repo_path` は単一repo対象。  
`repo_path` があり `repo_slug` が無ければ、`gh repo view --json owner,name` などで逆引きする。

### Optional

- `pr_numbers`: 明示的に棚卸ししたい PR 番号配列
- `scope`: `global` / `owner` / `repo`, default は入力から推定
- `owner`: 例 `f-scratch`
- `review_query`: default `state:open review-requested:@me`
- `max_workers`: default `4`
- `team_review_queries`: 追加の review request query 配列
- `prefer_wait_for_other_review_first`: default `true`
- `allow_comment_draft`: default `true`
- `return_policy_hints`: 例 `["CI red は返す", "他レビュアー未着手なら様子見"]`

`pr_numbers` がある場合、query で対象集合を広げない。  
`review_query` と `team_review_queries` は「自分のレビューキューを発見する」ためにだけ使う。  
一覧取得は `gh search prs`、詳細取得は各PRごとの `gh pr view` に分ける。

## Scope Resolution

棚卸しスコープは次の順で決める。

1. `pr_numbers` があれば explicit list mode
2. `repo_slug` または `repo_path` があれば `scope=repo`
3. `owner` があれば `scope=owner`
4. それ以外で「自分に来ている review request を全部見たい」なら `scope=global`

意図が曖昧でも、repo 横断棚卸しの文脈なら `scope=global` を既定にしてよい。

## Queue Buckets

各PRは最終的に次の4分類へ入れる。

- `RETURN_NOW`: いま読むより先に返すべき
- `WATCH`: まだ自分のレビュー番ではない、または待ち要因がある
- `REVIEW_NOW`: いまレビュー順序に載せる
- `DONE_OR_OUT_OF_SCOPE`: すでに自分の役目が終わっている、または自分の担当外

典型例:

- `RETURN_NOW`
  - CI failure / required check pending too long
  - merge conflict
  - draft
  - author response待ち
  - request changes 未解消
- `WATCH`
  - required checks が進行中で、まだ終端状態になっていない
  - 他レビュアーの初回レビュー待ち
  - 自分以外の gate reviewer 待ち
  - 依存PR待ち
- `REVIEW_NOW`
  - CI green
  - mergeable
  - 自分が見始めてよい状態
- `DONE_OR_OUT_OF_SCOPE`
  - 自分はすでに review 済み
  - review request が外れている
  - 担当ポリシー上、自分のレーンではない

## PM vs Worker Boundaries

### PM が担当すること

- 対象PRの確定
- worker キュー制御
- bucket の最終判定
- 返却候補コメントの最終文面調整
- 優先順位付けとレポート作成

### Worker が担当すること

- 単一PRの shallow investigation
- metadata と diff stats の取得
- JSON 契約での一次判定返却

Worker は次をしない。

- `gh pr review`
- `gh pr comment`
- label 変更
- assignee 変更
- branch 操作

worker JSON 契約は [references/worker-contract.md](references/worker-contract.md) を参照。

## Review Readiness Rules

判定は「このPRが正しいか」ではなく、「今、自分がレビュー投入すべきか」で行う。

### まず gate を見る

1. Draft か
2. CI / required checks が落ちていないか
3. merge conflict がないか
4. `CHANGES_REQUESTED` 後の author 更新があるか
5. 他レビュアー先行ルールがあるなら、その条件を満たしているか
6. 非終端の check が残っていないか

ここで止まる PR は、diff を深読みせず `RETURN_NOW` または `WATCH` に寄せる。
特に `statusCheckRollup` に `QUEUED` / `IN_PROGRESS` / `PENDING` 相当が残っている間は、`DONE_OR_OUT_OF_SCOPE` にしない。
自分が review 済みでも check 完了待ちなら `WATCH` に残し、何待ちかを明記する。

### 次に rough estimate を付ける

- `difficulty`: `S` / `M` / `L` / `XL`
- `estimated_review_minutes`
- `risk`: `LOW` / `MEDIUM` / `HIGH` / `CRITICAL`
- `urgency`: `LOW` / `MEDIUM` / `HIGH` / `CRITICAL`
- `priority_tier`: `P0` / `P1` / `P2` / `P3`

詳細 rubric は [references/priority-rubric.md](references/priority-rubric.md) を参照。

## Workflow

### 0) Resolve Scope

1. `scope` を `global` / `owner` / `repo` / `explicit list` のいずれかに確定する
2. `repo_path` しか無い repo mode では、必要なら `ghq` と `gh repo view` で `repo_slug` を補完する
3. `pr_numbers` があればその配列を対象とする
4. 無ければ `gh search prs` で対象PR一覧を作る
5. `team_review_queries` がある場合は追加検索して union を取る
6. 同一PRの重複取得は `repository.nameWithOwner + number` 相当で除外する

### 1) Intake

まず repo 横断の shallow な一覧を取る。

- PR番号
- repository
- title
- author
- isDraft
- labels
- updatedAt
- url

対象は「現在の open PR」だけに絞る。  
古い closed PR や merged PR を混ぜない。  
`gh search prs` では check 状態や size 情報が不足するため、各PRの詳細は worker 前段または worker 内で `gh pr view` から補う。

### 2) Worker Pool Loop

`max_workers` 分のスロットで回す。

```text
初期: pending から max_workers 件を起動
ループ:
  完了した worker を 1 件受け取る
  -> Validate
  -> Normalize
  -> Bucket Finalize
  -> Prioritize
  -> 空きスロットへ次の pending を投入
終了: pending / in_flight が 0 になったら Report
```

### 3) Spawn Worker

- Worker agent定義: `agents/openai-worker.yaml`
- 1PR = 1Worker
- 指示内容は「shallow investigation と JSON返却のみ」
- repo 横断一覧から渡すときは、各PRについて `repo_slug` と `pr_number` を必ずセットで渡す
- 行単位レビューや設計妥当性レビューには進ませない

### 4) Validate & Normalize

- 壊れたJSON、必須不足、enum外は reject
- `RETURN_NOW` なのに `blocking_reasons` が空なら reject
- `REVIEW_NOW` なのに `priority_tier` が無いなら reject
- `estimated_review_minutes <= 0` は reject
- 一次判定が user policy とズレる場合だけ PM が bucket を補正する

補正例:

- worker は `WATCH` にしたが、ユーザー方針では `WAIT_OTHER_REVIEW_FIRST` を `RETURN_NOW` 扱いにする
- worker は `REVIEW_NOW` にしたが、release freeze ラベルで PM が `WATCH` へ落とす
- worker は `DONE_OR_OUT_OF_SCOPE` にしたが、non-terminal check が残っているため PM が `WATCH` に補正する

### 5) Finalize Queue

PM は各PRを次の順で整理する。

1. `RETURN_NOW`
2. `WATCH`
3. `REVIEW_NOW`
4. `DONE_OR_OUT_OF_SCOPE`

`REVIEW_NOW` だけを優先順位付け対象にする。  
`RETURN_NOW` は「返す理由」と「返すならどの短文を使うか」まで揃える。  
`WATCH` は「何待ちか」を1行で書く。
未完了 check が残る PR は、review request が外れていても `WATCH` に残す。

### 6) Report

最終出力は最低でも次を含める。

- `今すぐ返す`
- `様子見`
- `今見る順番`
- `自分の役目が終わっている / 対象外`
- 全体所感

`今見る順番` は `priority_tier` と `estimated_review_minutes` が比較できる形で出す。  
大きいPRばかりが先頭に偏る場合は、`quick win` を1件だけ先に差し込む提案をしてよい。

## Reporting Shape

推奨フォーマット:

```text
今すぐ返す
- #1234 タイトル
  - 理由: CI red, merge conflict
  - 次アクション: author に CI 修正依頼
  - 返却文案: ...

様子見
- #1235 タイトル
  - 理由: 他レビュアー初回レビュー待ち
  - 再確認タイミング: 夕方 / 明日朝

今見る順番
1. #1238 タイトル | P0 | 20m | HIGH
2. #1240 タイトル | P1 | 15m | MEDIUM
3. #1239 タイトル | P1 | 45m | HIGH
```

必要なら最後に「今日ここまで見れば十分」の cut line を引く。

## Communication Rules

- レビュー本文を書く前の棚卸しであることを明示する
- 「返す」「待つ」「今見る」を混ぜずに出す
- 根拠は shallow なシグナルに限定し、深読みに見える断定を避ける
- policy が曖昧なら、`WAIT_OTHER_REVIEW_FIRST` の扱いだけユーザーへ1回確認する
- 返却文案は短く、感情を乗せず、review readiness の不足だけを書く
- `DONE_OR_OUT_OF_SCOPE` は厳格に使う。check が未完了の PR を「自分は見終わったから done」と片付けない。

## Hard Safety Rules

1. ユーザーの明示指示なしに review を submit しない
2. ユーザーの明示指示なしに PR comment を投稿しない
3. ユーザーの明示指示なしに label / assignee / project を更新しない
4. 棚卸し段階でコードの正しさを断定しない
5. branch 切り替えやローカル checkout は必要最小限に留める

## Command Patterns

```bash
# GitHub 全体で review request ベースの対象候補を取る
gh search prs \
  --review-requested @me \
  --state open \
  --json number,title,repository,author,isDraft,labels,updatedAt,url

# owner 単位に絞る
gh search prs \
  --review-requested @me \
  --state open \
  --owner f-scratch \
  --json number,title,repository,author,isDraft,labels,updatedAt,url

# 単一repoに絞る
gh search prs \
  --review-requested @me \
  --state open \
  --repo owner/repo \
  --json number,title,repository,author,isDraft,labels,updatedAt,url

# 単一PRの shallow investigation
gh pr view 1234 \
  --repo owner/repo \
  --json number,title,author,isDraft,reviewDecision,reviewRequests,reviews,latestReviews,statusCheckRollup,mergeable,mergeStateStatus,labels,updatedAt,changedFiles,additions,deletions,files,url
```

`files` は diff の全読みに行くためではなく、変更面の広さを見るためだけに使う。  
semantic review が必要なら、この skill の外で別 review skill へ渡す。
