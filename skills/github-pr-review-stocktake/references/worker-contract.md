# ワーカー契約

## PM -> Worker Input JSON

```json
{
  "task_id": "pr-review-stocktake-20260317-001",
  "repo_slug": "owner/repo",
  "repo_path": "/path/to/repo-or-null",
  "pr_number": 1234,
  "pr_url": "https://github.com/owner/repo/pull/1234",
  "analysis_mode": "remote_first",
  "reference_hints": [
    "https://notion.so/...",
    "#1201"
  ],
  "rules": {
    "must_not_mutate_pr": true,
    "must_separate_pass_through_and_real_target": true,
    "must_provide_review_route": true
  }
}
```

- `analysis_mode` は `remote_first` または `local_checkout`
- worker は PR を更新しない
- worker は review verdict を返さない

## Worker -> PM Output JSON

トップレベル必須:

- `task_id`
- `repo_slug`
- `pr_number`
- `analysis_mode`
- `summary`
- `confidence`
- `review_route`
- `attention_signals`
- `pass_through_paths`
- `real_review_targets`
- `human_judgment_calls`
- `low_attention_areas`
- `evidence`

### `review_route[]`

各要素の必須:

- `step`
- `why_this_order`
- `refs`
- `question_to_answer`

`refs` は file path, PR section, spec URL などの string array。

### `attention_signals[]`

各要素の必須:

- `ref`
- `signal_type`
- `why_this_signal`

任意:

- `suggested_focus`

`signal_type` は次のいずれか:

- `SMELL`
- `SPEC_CHECK`
- `DESIGN_CHECK`
- `RISK_CHECK`
- `LOW_SIGNAL`

### `pass_through_paths[]`

各要素の必須:

- `ref`
- `reason`

### `real_review_targets[]`

各要素の必須:

- `ref`
- `why_it_matters`
- `risk_kind`

`risk_kind` 例:

- `business_logic`
- `layer_boundary`
- `transaction`
- `permission`
- `serialization`
- `external_io`
- `compatibility`
- `error_handling`

### `human_judgment_calls[]`

各要素の必須:

- `question`
- `why_human_judgment_is_needed`
- `refs`

空配列は許可するが、その場合は `low_attention_areas` または `summary` に low-risk 根拠が必要。

### `low_attention_areas[]`

各要素の必須:

- `ref`
- `reason`

### `evidence`

必須:

- `diff_refs`（non-empty string array）
- `repo_rule_refs`（string array, empty allowed）
- `similar_impl_refs`（string array, empty allowed）
- `notes`（non-empty string array）

## Validation Rules

1. 壊れた JSON、必須不足、型不一致は reject
2. `review_route` は 1 件以上必須
3. `attention_signals` は 1 件以上必須
4. `pass_through_paths` と `real_review_targets` を同時に空配列にしない
5. `confidence` は 0.0 以上 1.0 以下
6. remote-first で local repo rule を見ていない場合は `repo_rule_refs` 空配列を許可する

## Sticky Comment Semantic Slots

コメントの見出しや段落構成は固定しない。  
ただし、最終コメントは以下の意味情報を全て含むこと。

1. この PR の実質的な変更要約
2. どの順番で見ると追いやすいか
3. signal 分類された重点観点
4. 深追い不要なので細かく読まなくてよい箇所
5. 実際に深く見るべき箇所
6. 人間が判断すべき論点
7. 深追い優先度が低いと見てよい箇所
8. 根拠
9. 不確実性や前提

signal の見せ方は固定しないが、少なくとも次を読者が識別できること。

- `SMELL`: 実装臭として警戒
- `SPEC_CHECK`: 仕様確認を先に置くべき
- `DESIGN_CHECK`: 責務や境界を見たほうがよい
- `RISK_CHECK`: 副作用や互換性を見たほうがよい
- `LOW_SIGNAL`: 深追い優先度が低い

## Sticky Comment Marker

```md
<!-- AI_PR_REVIEW_STOCKTAKE_START -->
... generated comment body ...
<!-- AI_PR_REVIEW_STOCKTAKE_END -->
```

PM はこの marker を含む **自分のコメントのみ** を upsert 対象にする。
