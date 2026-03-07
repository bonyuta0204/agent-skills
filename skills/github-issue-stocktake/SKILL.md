---
name: github-issue-stocktake
description: GitHub Issueの棚卸し・triageをPMとして進めるスキル。未整理Issueを分類し、`AI_STOCKTAKE` ブロックと排他ラベルを更新したいときに使う。一次調査はworkerへ委譲し、PMはキュー管理・品質ゲート・重複判定・GitHub更新を担当する。
---

# GitHub Issue Stocktake PM

## Overview

このskillは **PM専任** で動く。

- PM: 対象Issueの確定、キュー管理、worker起動、品質ゲート、重複判定、GitHub更新、最終報告
- Worker: 単一Issueの一次調査とJSON返却のみ

並列で worker を回しつつ、PM が完了順に検証・重複チェック・適用を逐次処理する。

## When To Use

- GitHub Issue を棚卸しして、未整理Issueに分類を付けたい
- `AI_STOCKTAKE` ブロックを本文へ安全に反映したい
- `AI_FIXABLE` と `HUMAN_*` を次工程へ引き渡せる形に標準化したい

使わない場面:
- PR作成や修正実装まで進めるとき
- 単一Issueを自分で読んでその場で直すだけのとき

## Goals

- 未整理Issueを分類し、根拠を構造化して残す
- 一次調査をworkerへ委譲し、PMは統制に集中する
- `AI_FIXABLE` の改修引き渡し情報を標準化する
- `HUMAN_*` の次アクションを明確化する
- タイムラインを汚さず、Issue本文 `AI_STOCKTAKE` ブロックを唯一の標準更新面にする

## Non-Goals

- Stocktake PM/WorkerはPRを作成しない
- Stocktake PM/WorkerはIssueをクローズしない
- ユーザー明示指示がない限り新規Issue起票をしない

## Inputs

### Required

- `repo_path`: 対象ローカルリポジトリの絶対パス
- `repo_slug`: `owner/repo`
- `issues`: Issue番号の配列または範囲

`issues` がこのskillの処理対象を決める。`gh issue list` はこの集合を広げるためではなく、**指定済みIssueの現在状態を取得するためだけ**に使う。

### Optional

- `max_workers`: default `3`
- `confidence_threshold_ai_fixable`: default `0.75`
- `prioritize_untriaged_first`: default `true`
- `reference_hints`: default `[]`

`reference_hints` は仕様URLや関連Issue番号など、PMがworkerへ渡してよい補助参照。無ければ空配列でよい。

## Classification

最終分類は以下の排他6種:

- `CLOSE_DONE`
- `CLOSE_DUPLICATE`
- `AI_FIXABLE`
- `HUMAN_SPEC_REQUIRED`
- `HUMAN_REPRO_REQUIRED`
- `HUMAN_CONTEXT_REQUIRED`

`AI_FIXABLE` は `confidence >= 0.75` を満たす場合のみ許可。

ラベル対応:

- `CLOSE_DONE` -> `クローズ可（解消）`
- `CLOSE_DUPLICATE` -> `クローズ可（重複）`
- `AI_FIXABLE` -> `AI改修可能`
- `HUMAN_SPEC_REQUIRED` -> `要仕様確認`
- `HUMAN_REPRO_REQUIRED` -> `要再現確認`
- `HUMAN_CONTEXT_REQUIRED` -> `要起票者確認`

## Boundaries

- Workerは **単一Issue調査専用**。`task_mode` は常に `single_issue`
- Workerは `CLOSE_DUPLICATE` を返さない。重複判定はPM専有
- Workerは `gh issue edit`、ラベル変更、assignee変更、コメント投稿をしない
- PMだけが本文更新、ラベル排他更新、必要時assignee更新を行う

worker JSONの厳格契約、PM正規化後に使う `AI_STOCKTAKE` block format、validation rules は [references/worker-contract.md](references/worker-contract.md) を参照。

## State File

並列キューを安全に再開できるよう、PMは状態をファイルへ永続化する。

保存場所:

```text
${TMPDIR:-/tmp}/github-issue-stocktake-<repo-slug-safe>.json
```

最低限保持する項目:

- `repo_slug`
- `issues.<issue>.status`
- `issues.<issue>.retry_count`
- `issues.<issue>.classification_candidate`
- `issues.<issue>.failure_kind`
- `processed_summaries`

`processed_summaries` には、重複照合に使う `issue_number`, `classification`, `summary`, `keywords` を保持する。状態変更の直後に書き出し、再開時はこのファイルからキューと重複判定履歴を復元する。

## Failure Taxonomy

分類と失敗理由を混同しない。

- `needs_user_input`: 仕様・再現条件・ドメイン背景が足りない
- `worker_contract_failure`: 壊れたJSON、必須不足、enum外など
- `worker_execution_failure`: workerの途中失敗、ツール失敗、タイムアウト

`needs_user_input` のときだけ `HUMAN_*` へ寄せることを検討する。`worker_contract_failure` や `worker_execution_failure` を、そのまま `HUMAN_CONTEXT_REQUIRED` に変換しない。

## Workflow

### 0) Resume Check

1. state file があれば読み込み、未完了Issueから再開する
2. state file が無ければ新規キューを作る

### 1) Intake

1. `issues` で指定されたIssueだけを対象にする
2. `gh issue view` または必要最小限の `gh issue list` で各Issueの現在状態を取得する
3. `分類ラベルなし` かつ `AI_STOCKTAKE` なしを優先しつつ、対象キューを確定する
4. 各Issueを `pending` で state file に記録する

### 2) Worker Pool Loop

`max_workers` 分のスロットで処理する。

```text
初期: pending から max_workers 件を起動
ループ:
  完了した worker を 1 件受け取る
  -> Validate
  -> Normalize
  -> Duplicate Check
  -> Apply
  -> processed_summaries 更新
  -> 空きスロットへ次の pending を投入
終了: pending / in_flight が 0 になったら Report
```

### 3) Spawn Worker

- Worker agent定義: `agents/openai-worker.yaml`
- 1Issue = 1Worker
- 指示内容は「調査とJSON返却のみ」
- `reference_hints` があれば、そのIssueに関係あるものだけ渡す

### 4) Validate & Normalize

- `scripts/validate_worker_report.sh --json-file <file>` で worker 出力を検証する
- `AI_FIXABLE` で `expected_behavior` が string の場合は reject
- `spec_refs` は空配列を許可する。ただし、仕様が見つからないなら `gap_analysis` に不足情報を書く
- reject 時は同一taskを1回だけ再試行する
- 2回失敗した場合は state file に `failure_kind` を残し、最終報告へ回す

### 5) Duplicate Check

- PM は `processed_summaries` と照合して重複を判断する
- 重複疑いが高いときだけユーザーへ確認する
- ユーザー承認後、PMが分類を `CLOSE_DUPLICATE` と `duplicate_of_issue` 付きで上書きする
- 重複でなければ worker の分類を採用する

### 6) Apply

- `scripts/render_stocktake_block_from_json.sh` で block を生成する
- `scripts/upsert_ai_stocktake_block.sh` で本文に反映する
- 分類ラベル6種を一度除去してから1つだけ付与する
- 本文更新では `AI_STOCKTAKE` block の追加/置換以外を変更しない
- 適用成功後に `processed_summaries` と Issue状態を state file へ書き戻す

### 7) Report

- Issueごとの最終分類
- 実行アクション
- `failure_kind` と再試行状況
- 重複として集約したペア

## Communication Rules

- ユーザーはドメイン知識や背景情報を持っている前提で動く
- 十分な根拠がある判断に承認を求めない
- 情報不足で分類がぶれるときだけ、質問を1回にまとめて聞く
- 重複集約はユーザー運用に影響しやすいため、**このケースだけは明示確認を優先する**

ユーザーに相談すべき場面:

1. 仕様の所在が不明
2. 再現条件が特定できない
3. ドメイン固有の制約がある
4. Issue間の関係が不明
5. 影響範囲の判断材料が足りない
6. 分類根拠が薄い

## Command Patterns

```bash
# 1) worker出力検証
skills/github-issue-stocktake/scripts/validate_worker_report.sh \
  --json-file /tmp/worker-task-001.json

# 2) issueごとのAI_STOCKTAKE block生成
skills/github-issue-stocktake/scripts/render_stocktake_block_from_json.sh \
  --json-file /tmp/normalized-task-001.json \
  --issue 1234 \
  --out-file /tmp/issue-1234-stocktake.md

# 3) 既存bodyへ安全反映
gh issue view 1234 --repo owner/repo --json body -q .body > /tmp/issue-1234-body.md

skills/github-issue-stocktake/scripts/upsert_ai_stocktake_block.sh \
  --body-file /tmp/issue-1234-body.md \
  --block-file /tmp/issue-1234-stocktake.md \
  --out-file /tmp/issue-1234-new-body.md

gh issue edit 1234 --repo owner/repo --body-file /tmp/issue-1234-new-body.md
```

`normalized-task-001.json` は、worker生JSONまたはPMが duplicate 判定後に正規化したJSONどちらでもよい。

## Bundled Files

- `agents/openai.yaml`: PM agent interface
- `agents/openai-worker.yaml`: worker agent interface
- `references/worker-contract.md`: worker JSON契約、AI_STOCKTAKE block format、validation rules
- `scripts/validate_worker_report.sh`: worker JSON検証
- `scripts/render_stocktake_block_from_json.sh`: AI_STOCKTAKE block生成
- `scripts/upsert_ai_stocktake_block.sh`: 既存bodyへの安全反映
