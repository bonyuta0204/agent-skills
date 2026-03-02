---
name: github-issue-stocktake
description: GitHub Issue棚卸しのPMエージェント。一次調査はworkerエージェントに委譲し、PMはキュー管理・品質ゲート・本文/ラベル更新を行う。
---

# GitHub Issue Stocktake PM（Multi-Agent）

## Overview

このskillは **PM専任** で動く。

- PM: キュー作成、worker起動、品質ゲート、GitHub更新、バッチ報告
- Worker: 一次調査と厳格JSONレポート返却のみ

責務分離により、調査の並列性と運用ガバナンス（No-Noise、分類排他、信頼度閾値）を同時に満たす。

## Goals

- 未整理Issueを分類し、根拠を構造化して残す。
- 一次調査をworkerへ並列委譲し、PMは統制に集中する。
- `AI_FIXABLE` の改修引き渡し情報を標準化する。
- `HUMAN_*` の次アクションを明確化する。
- タイムラインを汚さず、Issue本文 `AI_STOCKTAKE` ブロックを唯一の更新面にする。

## Non-Goals

- Stocktake PM/WorkerはPRを作成しない。
- Stocktake PM/WorkerはIssueをクローズしない。
- ユーザー明示指示がない限り新規Issue起票をしない。

## Required Inputs

- `repo_path`: 対象ローカルリポジトリの絶対パス
- `repo_slug`: `owner/repo`
- `issues`: Issue番号の配列または範囲

## Optional Inputs / Defaults

- `batch_size`: default `5`
- `max_parallel_agents`: default `3`
- `allow_duplicate_cluster_task`: default `true`
- `confidence_threshold_ai_fixable`: default `0.75`

## Classification（Exclusive）

- `CLOSE_DONE`
- `CLOSE_DUPLICATE`
- `AI_FIXABLE`
- `HUMAN_SPEC_REQUIRED`
- `HUMAN_REPRO_REQUIRED`
- `HUMAN_CONTEXT_REQUIRED`

`AI_FIXABLE` は `confidence >= 0.75` を満たす場合のみ許可。

## Label Mapping

- `CLOSE_DONE` -> `クローズ可（解消）`
- `CLOSE_DUPLICATE` -> `クローズ可（重複）`
- `AI_FIXABLE` -> `AI改修可能`
- `HUMAN_SPEC_REQUIRED` -> `要仕様確認`
- `HUMAN_REPRO_REQUIRED` -> `要再現確認`
- `HUMAN_CONTEXT_REQUIRED` -> `要起票者確認`

分類ラベルは排他運用（6種から1つのみ残す）。

## Multi-Agent Contract

### PM -> Worker Input JSON

```json
{
  "task_id": "stocktake-20260302-001",
  "repo_path": "/path/to/repo",
  "repo_slug": "owner/repo",
  "issue_numbers": [1234],
  "task_mode": "single_issue",
  "references": [
    "https://notion.so/...",
    "https://figma.com/..."
  ],
  "rules": {
    "classification_enum": [
      "CLOSE_DONE",
      "CLOSE_DUPLICATE",
      "AI_FIXABLE",
      "HUMAN_SPEC_REQUIRED",
      "HUMAN_REPRO_REQUIRED",
      "HUMAN_CONTEXT_REQUIRED"
    ],
    "confidence_threshold_ai_fixable": 0.75,
    "must_not_mutate_issue": true
  }
}
```

- `task_mode` は `single_issue` または `duplicate_cluster`
- `issue_numbers` は通常1件。重複疑いクラスタ時のみ複数件可。

### Worker -> PM Output JSON（Strict）

トップレベル必須:
- `task_id`
- `task_mode`
- `results`（non-empty array）

`results[]` 必須:
- `issue_number`
- `classification`
- `confidence`
- `summary`
- `evidence`
- `gap_analysis`

`evidence` 必須:
- `implementation_refs`（non-empty string array）
- `spec_refs`（non-empty string array）
- `repro_notes`（non-empty string）

追加必須:
- `AI_FIXABLE`: `suspected_root_cause`, `reproduction_steps`, `expected_behavior`, `affected_files`, `test_plan`
- `CLOSE_DUPLICATE`: `duplicate_of_issue`
- `HUMAN_*`: `human_action_owner`, `human_action_items`

## PM Quality Gate

1. 壊れたJSON、必須不足、enum外分類は reject。
2. `AI_FIXABLE && confidence < threshold` は reject（受理不可）。
3. reject時は同一taskを1回だけ再試行。
4. 再試行でも失敗したIssueは `HUMAN_CONTEXT_REQUIRED` に退避し、理由を `AI_STOCKTAKE` に記録。

## No-Noise Policy

- コメント連投を避けるため、通常はIssue本文の `AI_STOCKTAKE` ブロックのみ更新。
- 判定変更時のみ補足コメント1件を許可。
- `AI_STOCKTAKE` マーカー片側欠損は更新中止（手動修復に回す）。

## Body Update Safety Rules

- `<!-- AI_STOCKTAKE_START -->` と `<!-- AI_STOCKTAKE_END -->` の間のみ置換。
- 両方とも存在しない場合だけ本文末尾に追記。
- 片側のみ存在、または複数ペア存在はエラーで中止。
- `AI_STOCKTAKE` ブロック以外は変更しない。

## PM Workflow

### 1) Intake

- `gh issue view <issue> --comments` で既存文脈を確認。
- 既存 `AI_STOCKTAKE` を見て再実行優先度を決める。
- 重複疑いが強いものをクラスタ化（`allow_duplicate_cluster_task=true` の場合）。
- 実行ボードを作る: `issue`, `lane`, `task_mode`, `status`, `retry_count`。

### 2) Assignment

- 既定 `max_parallel_agents=3`。
- 通常Issueは `1Issue=1Worker`。
- 重複クラスタは `duplicate_cluster` でまとめて1Workerに委譲可。

### 3) Spawn Workers

- Worker agent定義: `agents/openai-worker.yaml`
- Workerへの指示は「調査とJSON返却のみ」。
- Workerは `gh issue edit` やラベル更新をしてはいけない。

### 4) Validate & Normalize

- `scripts/validate_worker_report.sh --json-file <file>` で検証。
- 失敗したtaskは1回だけ再試行。
- 2回失敗したIssueは `HUMAN_CONTEXT_REQUIRED` へ退避。

### 5) Apply（PM only）

- `scripts/render_stocktake_block_from_json.sh --json-file <file> --issue <n> --out-file <block>`
- `scripts/upsert_ai_stocktake_block.sh` で本文反映。
- 分類ラベル6種を一度除去してから1つだけ付与。
- 必要時のみ assignee 更新。

### 6) Batch Report

- Issueごとの分類
- 実行アクション（本文/ラベル/アサイン）
- 失敗理由、退避理由
- 次バッチ候補

## AI_STOCKTAKE Block Format（Mandatory）

```md
<!-- AI_STOCKTAKE_START -->
## AI_STOCKTAKE

### 分類
- AI改修可能 (`AI_FIXABLE`)

### 判断信頼度
- 0.84

### 要約
- ...

### 根拠
- 再現結果: ...
- 実装確認:
  - `path/to/file.ts:123`
- 仕様確認:
  - https://notion.so/...

### 差分 / ギャップ
- ...

### 改修方針（`AI_FIXABLE` のとき）
- ...

### 人間アクション（`HUMAN_*` のとき）
- 依頼先: ...
- 確認事項:
  - ...

### 改修エージェント入力（`AI_FIXABLE` のとき）
- 原因候補 (`suspected_root_cause`): ...
- 再現手順 (`reproduction_steps`):
  - ...
- 期待挙動 (`expected_behavior`):
  - ...
- 影響ファイル (`affected_files`):
  - ...
- テスト方針 (`test_plan`):
  - ...

<!-- AI_STOCKTAKE_END -->
```

## Command Patterns

```bash
# 1) worker出力検証
skills/github-issue-stocktake/scripts/validate_worker_report.sh \
  --json-file /tmp/worker-task-001.json

# 2) issueごとのAI_STOCKTAKEブロック生成
skills/github-issue-stocktake/scripts/render_stocktake_block_from_json.sh \
  --json-file /tmp/worker-task-001.json \
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

## Execution Rules

- PMはGitHub更新責務を独占する。
- Workerは調査とJSON返却以外を行わない。
- Issueクローズは常に人間判断。
- 1Issue 1PRの次工程管理は別skill（改修PM側）で扱う。

## Bundled Files

- `agents/openai.yaml`: PM agent interface
- `agents/openai-worker.yaml`: worker agent interface
- `scripts/validate_worker_report.sh`: worker JSON検証
- `scripts/render_stocktake_block_from_json.sh`: AI_STOCKTAKE block生成
- `scripts/upsert_ai_stocktake_block.sh`: 既存bodyへの安全反映
