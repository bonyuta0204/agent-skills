# Priority Rubric

## 1. Gate First

まず bucket を決める。

- `RETURN_NOW`: 返してからでないとレビュー投入しても無駄
- `WATCH`: 待ち要因があり、今は優先順位に載せない
- `REVIEW_NOW`: 今のレビューキューに載せる
- `DONE_OR_OUT_OF_SCOPE`: 今回の棚卸し対象から外す

check が未完了の PR は `WATCH` に寄せる。
自分のレビューが済んでいても、non-terminal check が残っている間は `DONE_OR_OUT_OF_SCOPE` にしない。

`REVIEW_NOW` 以外は、priority を細かく競わせない。

## 2. Difficulty

### `S`

- 変更ファイル 1-3
- 追加削除が小さい
- 変更面が単一レイヤー
- 想定レビュー 15分以内

### `M`

- 変更ファイル 4-8
- API / UI / test のうち2面まで
- 想定レビュー 15-30分

### `L`

- 変更ファイル 9-20
- 複数レイヤー横断
- データ構造変更や権限系を含む
- 想定レビュー 30-60分

### `XL`

- 変更ファイル 20超
- 複数モジュール/複数repo 前提
- migration、基盤変更、広い回帰確認が必要
- 想定レビュー 60分超

## 3. Risk

### `LOW`

- 局所変更
- 非本番系または影響が限定的

### `MEDIUM`

- 既存ユーザー導線へ触る
- API shape や主要画面の変更がある

### `HIGH`

- 認証、課金、権限、データ整合性、本番運用フローに触る
- rollback や検証が重い

### `CRITICAL`

- 障害対応中
- release blocker
- 顧客影響が大きい

## 4. Urgency

### `LOW`

- stale ではない
- 依存ブロックも締切圧もない

### `MEDIUM`

- author が待っている
- 2営業日以上停滞している

### `HIGH`

- release branch / hotfix branch
- 依存タスクのボトルネック

### `CRITICAL`

- incident / same-day release / 明確な緊急対応

## 5. Priority Tier

### `P0`

- `REVIEW_NOW` かつ `urgency` が `CRITICAL`
- または `HIGH` 以上の urgency で、自分の review だけが最後の gate

### `P1`

- `REVIEW_NOW` かつ high urgency または high risk
- 今日中に触る価値が高い

### `P2`

- `REVIEW_NOW` だが urgency は中以下
- 重めで後ろに回してよい

### `P3`

- `WATCH`
- `RETURN_NOW`
- `DONE_OR_OUT_OF_SCOPE`
- または `REVIEW_NOW` でも今週優先度が低い

## 6. Ordering Rule Inside `REVIEW_NOW`

並び順の既定:

1. `P0`
2. `P1`
3. `P2`
4. 同 tier なら `urgency` 高い順
5. 次に `risk` 高い順
6. 最後に `estimated_review_minutes` が短い順

ただし、`L` / `XL` ばかり続くときは、`S` / `M` の quick win を1件だけ前へ差し込んでよい。
