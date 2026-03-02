---
name: github-issue-stocktake
description: GitHub Issue棚卸しのPMエージェント。一次調査はworkerエージェントに委譲し、PMはキュー管理・品質ゲート・本文/ラベル更新を行う。
---

# GitHub Issue Stocktake PM（Multi-Agent）

## Overview

このskillは **PM専任** で動く。

- PM: キュー作成、worker起動、品質ゲート、GitHub更新、重複検出、報告
- Worker: 一次調査と厳格JSONレポート返却のみ

Workerによる調査を並列で高速に回しつつ、PMが完了順に検証・重複チェック・適用を逐次処理する（ワーカープール方式）。

## Goals

- 未整理Issueを分類し、根拠を構造化して残す。
- 一次調査をworkerへ委譲し、PMは統制に集中する。
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

- `max_workers`: default `3`（同時に起動するworker数。ワーカープールのサイズ）
- `confidence_threshold_ai_fixable`: default `0.75`
- `prioritize_untriaged_first`: default `true`

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

- `task_mode` は `single_issue` 固定（重複判定はPMが処理済みサマリとの照合で行う）。
- `issue_numbers` は常に1件。

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

`AI_FIXABLE` の型制約（厳格）:
- `reproduction_steps`: non-empty string array
- `expected_behavior`: non-empty string array（**string単体は不可**）
- `affected_files`: non-empty string array
- `test_plan`: non-empty string array

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

- `gh issue list` で対象Issueの一覧を取得。
- 各Issueの既存ラベル・`AI_STOCKTAKE` 有無を確認し、処理キューを作成。
- 処理キュー: `issue`, `status`（pending / in_flight / done / failed）, `retry_count`。

優先度ルール（`prioritize_untriaged_first=true`）:
- `分類ラベルなし` かつ `AI_STOCKTAKEブロックなし` のIssueを最優先に処理する。
- 既に `分類ラベルあり` かつ `AI_STOCKTAKEあり` のIssueは、明示指示がある場合のみ再棚卸しする。

### 2) Worker Pool Loop

`max_workers` 分のスロットを持つワーカープールで処理する。

```
初期: キューから max_workers 件を取り出し、各スロットにWorkerを起動
ループ:
  いずれかのWorkerが完了 →
    3) Validate → 4) Duplicate Check → 5) Apply → サマリ蓄積
    キューに残りがあれば空きスロットに次のWorkerを起動
全スロット完了 かつ キュー空 → 6) Report
```

### 3) Spawn Worker

- Worker agent定義: `agents/openai-worker.yaml`
- 1Issue = 1Worker。Workerへの指示は「調査とJSON返却のみ」。
- Workerは `gh issue edit` やラベル更新をしてはいけない。

### 4) Validate & Normalize

- `scripts/validate_worker_report.sh --json-file <file>` で検証。
- `AI_FIXABLE` で `expected_behavior` が string の場合は reject（配列化を指示して再試行）。
- 失敗したtaskは1回だけ再試行。
- 2回失敗したIssueは `HUMAN_CONTEXT_REQUIRED` へ退避。

### 5) Duplicate Check（PM判断・逐次）

- PMは処理済みIssueのサマリ（番号・分類・要約・根拠キーワード）を蓄積している。
- Worker結果を **完了順に1件ずつ** 処理済みサマリと照合し、同一原因・同一症状のIssueがないか判定する。
- 重複を検出した場合:
  - ユーザーに「#N は処理済み #M と同じ原因に見えます。重複として集約していいですか？」と相談する。
  - ユーザー承認後、分類を `CLOSE_DUPLICATE`（`duplicate_of_issue: M`）に上書きする。
- 重複でなければWorkerの分類をそのまま採用。
- 注: 先に完了したIssueほど比較対象が少ないため、処理順による検出漏れは許容する。

### 6) Apply（PM only・逐次）

- `scripts/render_stocktake_block_from_json.sh` でブロック生成。
- `scripts/upsert_ai_stocktake_block.sh` で本文反映。
- 分類ラベル6種を一度除去してから1つだけ付与。
- 必要時のみ assignee 更新。
- **処理済みサマリに追加してから**、空きスロットに次のWorkerを投入。

### 7) Report

- 全件完了後にまとめて報告。
- Issueごとの分類・実行アクション・失敗/退避理由。
- 重複として集約したペアの一覧。

## PM Communication Rules

### 基本姿勢

- ユーザーはシステムのドメイン知識やバグの背景情報を持っている前提で動く。
- PMは自分の調査だけで埋められない情報ギャップを認識し、**主体的にユーザーへ聞きに行く**。
- 十分な根拠がある判断にいちいち承認を求めない。聞くのは「情報が足りないとき」。

### ユーザーに相談すべき場面

1. **仕様の所在が不明**: Issueが参照する仕様・設計ドキュメントが見つからないとき、ユーザーにポインタを聞く。
2. **再現条件が特定できない**: Issueの記述とコードだけでは再現手順を組み立てられないとき、心当たりを聞く。
3. **ドメイン固有の制約**: インフラ制約・外部依存・運用ルールなど、コードから読み取れない背景があるとき。
4. **Issue間の関係が不明**: 別々に起票されたIssueが同一原因に見えるとき、意図的な分割か聞く。
5. **影響範囲の判断材料不足**: コード上は軽微に見えるが顧客影響やビジネス優先度が不明なとき。
6. **分類根拠が薄い**: Workerの調査結果だけでは分類の確信が持てず、ユーザーの知見で判断が変わり得るとき。

### 聞き方のガイドライン

- 「○○が分からないので調べています」ではなく「○○について心当たりありますか？」と具体的に聞く。
- 質問は1回のメッセージにまとめる。小出しにしない。
- ユーザーの回答を得たら、それを踏まえて分類・根拠に反映し、反映した旨を伝える。

### 進捗共有

- 進捗報告は簡潔に: 処理中Issue・反映済み件数・詰まりポイントを短文で伝える。
- 全件正常なら逐一報告しない。異常やユーザー判断が必要な場面で伝える。

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
