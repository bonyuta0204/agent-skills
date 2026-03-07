# Worker Contract

## PM -> Worker Input JSON

```json
{
  "task_id": "stocktake-20260302-001",
  "repo_path": "/path/to/repo",
  "repo_slug": "owner/repo",
  "issue_numbers": [1234],
  "task_mode": "single_issue",
  "reference_hints": [
    "https://notion.so/...",
    "#1201"
  ],
  "rules": {
    "classification_enum": [
      "CLOSE_DONE",
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

- `task_mode` は `single_issue` 固定
- `issue_numbers` は常に1件
- `reference_hints` は空配列でよい
- worker は `CLOSE_DUPLICATE` を返さない

## Worker -> PM Output JSON

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
- `spec_refs`（string array, empty allowed）
- `repro_notes`（non-empty string）

追加必須:

- `AI_FIXABLE`: `suspected_root_cause`, `reproduction_steps`, `expected_behavior`, `affected_files`, `test_plan`
- `HUMAN_*`: `human_action_owner`, `human_next_action_type`, `human_action_items`

`AI_FIXABLE` の型制約:

- `reproduction_steps`: non-empty string array
- `expected_behavior`: non-empty string array
- `affected_files`: non-empty string array
- `test_plan`: non-empty string array

`HUMAN_*` の型制約:

- `human_action_owner`: non-empty string
- `human_next_action_type`: one of `ANSWER_SPEC_QUESTION`, `PROVIDE_REPRO_STEPS`, `PROVIDE_BUSINESS_CONTEXT`, `MAKE_SCOPE_DECISION`, `ROUTE_TO_OWNER`
- `human_action_items`: non-empty string array

`human_action_owner` は単一の人または役割を1つだけ書く。  
`human_next_action_type` は「次にその責任者が何をするか」を表し、Issue分類そのものではない。

## Validation Rules

1. 壊れたJSON、必須不足、enum外分類は reject
2. `AI_FIXABLE && confidence < threshold` は reject
3. `expected_behavior` が string 単体なら reject
4. `spec_refs` は空配列を許可する
5. duplicate 判定は validator 対象外。PMが後段で正規化する

## AI_STOCKTAKE Block Format

PM が duplicate 判定や補正を済ませた **normalized JSON** から block を生成する。

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
- 次アクション種別: `ANSWER_SPEC_QUESTION`
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

### 重複集約先（`CLOSE_DUPLICATE` のとき）
- #1234

<!-- AI_STOCKTAKE_END -->
```
