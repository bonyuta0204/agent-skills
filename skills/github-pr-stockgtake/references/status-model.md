# 状態分類

## status_category

- `ready_waiting_review`
  - CI が実質 green
  - conflict なし
  - 作成者側の修正待ちが見えない
  - 人間の承認や再レビュー待ちが主ボトルネック

- `waiting_for_author_changes`
  - 最新の review comment や requested changes があり、作成者側の修正が未完

- `failing_checks`
  - status checks に `FAILURE` が含まれる
  - lint/test/build の局所修正で進む可能性が高い

- `waiting_ci`
  - status checks が `PENDING` / `WAITING`
  - 環境承認、rerun、workflow 待機解除で進む可能性がある

- `conflicting`
  - `mergeable=CONFLICTING` または `mergeStateStatus=DIRTY`

- `draft_wip`
  - draft のまま

- `stale_needs_decision`
  - 長期間更新がなく、技術的 blocker より継続要否の判断が必要

## ai_actionability

- `auto_fixable`
  - AI がローカル修正まで進められる

- `auto_retryable`
  - rerun、承認待ち解除、補足コメントなどの作業的対応で進められる

- `human_review_needed`
  - 実装はほぼ終わっており、人間の承認や判断待ちが主

- `human_decision`
  - 続けるか close するか、仕様を変えるかなど人の判断が必要
