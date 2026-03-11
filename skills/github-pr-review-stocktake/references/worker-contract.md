# Worker Contract

## PM -> Worker Input JSON

```json
{
  "task_id": "pr-review-stocktake-20260311-001",
  "repo_path": "/path/to/repo",
  "repo_slug": "owner/repo",
  "pr_numbers": [1234],
  "task_mode": "single_pr",
  "rules": {
    "queue_bucket_enum": [
      "RETURN_NOW",
      "WATCH",
      "REVIEW_NOW",
      "DONE_OR_OUT_OF_SCOPE"
    ],
    "must_not_mutate_pr": true,
    "prefer_wait_for_other_review_first": true
  },
  "return_policy_hints": [
    "CI red は返す",
    "他レビュアー未着手なら様子見"
  ]
}
```

- `task_mode` は `single_pr` 固定
- `pr_numbers` は常に1件
- worker は GitHub を更新しない
- worker は deep review に進まず、review readiness 判定だけを返す

## Worker -> PM Output JSON

トップレベル必須:

- `task_id`
- `task_mode`
- `results`（non-empty array）

`results[]` 必須:

- `pr_number`
- `queue_bucket`
- `confidence`
- `summary`
- `review_state_summary`
- `blocking_reasons`
- `recommended_action`
- `evidence`
- `size_signal`

`evidence` 必須:

- `metadata_refs`（non-empty string array）
- `status_checks_summary`（non-empty string array）
- `review_signals`（non-empty string array）

`size_signal` 必須:

- `changed_files`（integer, `>= 0`）
- `additions`（integer, `>= 0`）
- `deletions`（integer, `>= 0`）
- `hotspots`（string array, empty allowed）

追加必須:

- `RETURN_NOW`: `return_message_draft`
- `WATCH`: `wait_reason`, `recheck_hint`
- `REVIEW_NOW`: `difficulty`, `estimated_review_minutes`, `risk`, `urgency`, `priority_tier`, `risk_notes`, `effort_notes`
- `DONE_OR_OUT_OF_SCOPE`: `done_reason`

## Enum Rules

`blocking_reasons` は次から選ぶ:

- `DRAFT_PR`
- `CI_RED`
- `CI_PENDING`
- `CI_PENDING_TOO_LONG`
- `MERGE_CONFLICT`
- `WAIT_OTHER_REVIEW_FIRST`
- `CHANGES_REQUESTED_PENDING`
- `WAIT_AUTHOR_RESPONSE`
- `BLOCKED_BY_DEPENDENCY`
- `BLOCKED_BY_LABEL`
- `ALREADY_REVIEWED_BY_ME`
- `NOT_MY_SCOPE`

`difficulty`:

- `S`
- `M`
- `L`
- `XL`

`risk` / `urgency`:

- `LOW`
- `MEDIUM`
- `HIGH`
- `CRITICAL`

`priority_tier`:

- `P0`
- `P1`
- `P2`
- `P3`

## Validation Rules

1. 壊れたJSON、必須不足、enum外は reject
2. `RETURN_NOW` なのに `blocking_reasons` が空なら reject
3. `RETURN_NOW` なのに `return_message_draft` が空なら reject
4. `WATCH` なのに `wait_reason` または `recheck_hint` が空なら reject
5. `REVIEW_NOW` なのに `difficulty` / `estimated_review_minutes` / `risk` / `urgency` / `priority_tier` のいずれかが欠けたら reject
6. `estimated_review_minutes <= 0` は reject
7. `DONE_OR_OUT_OF_SCOPE` なのに `done_reason` が空なら reject
8. `status_checks_summary` に non-terminal check があるのに `DONE_OR_OUT_OF_SCOPE` を返したら reject

## Check Completion Rule

- `statusCheckRollup` に `QUEUED` / `IN_PROGRESS` / `PENDING` / `WAITING` 相当が含まれる場合、その PR は `DONE_OR_OUT_OF_SCOPE` にしない
- その場合は原則 `WATCH` にし、`blocking_reasons` に `CI_PENDING` を含める
- すでに自分が review 済みでも、check 完了待ちであれば `wait_reason` にその旨を書く

## Recommended Report Shape

PM が normalized JSON から作る最終レポートの最小形:

```text
今すぐ返す
- #1234 タイトル
  - 理由: CI_RED, MERGE_CONFLICT
  - 返却文案: CI と conflict を解消後に再度 review request をお願いします

様子見
- #1235 タイトル
  - 理由: WAIT_OTHER_REVIEW_FIRST
  - 再確認: 明日朝

今見る順番
1. #1236 タイトル | P0 | 15m | HIGH
2. #1237 タイトル | P1 | 30m | MEDIUM

役目完了 / 対象外
- #1238 タイトル
  - 理由: ALREADY_REVIEWED_BY_ME
```
