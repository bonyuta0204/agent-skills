# Detailed Design Doc: Bad / Good Samples
#
# Purpose: Pasteable examples to calibrate reviews for "detail design" docs.
# Assumption: Readers do NOT open the codebase to understand intent.
#
# Use in reviews:
# - Point authors to the "Bad" patterns to remove.
# - Ask authors to rewrite into the "Good" structure in words.

## ❌ Bad sample (common failure)

### Change summary
ユーザーのKPI集計結果を保存する処理を追加する。

### Implementation (code dump)
以下のように `KpiAggregationService` に処理を追加する。

```rb
class KpiAggregationService
  def execute(user_id, period)
    records = KpiRecord.where(user_id: user_id, period: period)
    total = 0
    records.each do |record|
      total += record.value if record.value.present?
    end
    AggregatedKpi.create!(user_id: user_id, period: period, value: total)
  end
end
```

Controller 側では以下のように呼び出す。

```rb
class Api::KpisController < ApplicationController
  def aggregate
    KpiAggregationService.new.execute(params[:user_id], params[:period])
    render json: { status: "ok" }
  end
end
```

### Why it's bad (review points)
- 目的/仕様が書かれていない（合計？平均？欠損値の扱いは？）
- 責務分割の意図が不明（なぜServiceがDB保存まで持つ？境界は？）
- 失敗時の挙動が不明（例外・二重実行・部分失敗は？冪等性は？）
- コードを読まないと意図が汲み取れない（= 詳細設計書としてNG）
- 設計書ではなく「実装メモ」になっている（設計判断が残らない）

### Example review comment
詳細設計書として、**コードを読まないと意図/仕様が伝わらない状態**です。
目的（何を実現したいか）/重要な仕様（欠損値や例外時の扱い）/責務分割/不変条件を文章で明記してください。
本文の大きなコードブロックは削除し、必要なら最小限の擬似コードに留めてください。

---

## ✅ Good sample (desired detail design)

### 1. Background / problem
ユーザー単位・期間単位でKPIを集計した結果を永続化する仕組みが存在せず、毎回オンデマンド集計が走っている。
そのためパフォーマンスと再利用性に課題がある。

### 2. Purpose / non-purpose
**Purpose**
- ユーザー × 期間単位でKPI集計結果を永続化する
- 集計ロジックと永続化責務を明確に分離する

**Non-purpose**
- KPI定義の変更
- 集計トリガーの非同期化（将来検討）

### 3. Approach (overview)
- 集計処理は `AggregationService` が担う
- 永続化は `Repository` 層が担う
- 集計結果は **冪等に保存** される（同一キーは上書き/更新）

```
Controller
  -> AggregationService
    -> AggregatedKpiRepository
```

### 4. Responsibility boundaries
| Component | Responsibility |
| --- | --- |
| Controller | リクエスト受付・入力検証・エラーレスポンス |
| AggregationService | 集計ロジック（仕様の言語化） |
| Repository | 永続化（insert/update/tx境界） |

※ AggregationService は DB の insert/update 方法を知らない

### 5. Data flow
1. Controller が `user_id` / `period` を受け取る
2. AggregationService が対象レコードを取得する
3. `value = nil` のレコードは集計対象外
4. 合計値を算出する
5. Repository を通じて保存する

### 6. Invariants / key rules
- 同一 `(user_id, period)` に対する集計結果は常に1件
- 再実行しても重複しない（冪等性）
- `value = nil` は集計対象外

### 7. Failure behavior
- 集計途中で例外が発生した場合、保存は行われない
- DB保存失敗時はエラーを上位に返却し、Controller でエラーレスポンスを返す
- トランザクション境界は Repository 内で管理する

### 8. Implementation notes (reference-only)
必要なら擬似コードで意図を補足する（本文に大量のコードは載せない）。

```text
total = sum(record.value where value is not null)
save(user_id, period, total)  # idempotent
```

### 9. Test considerations
- valueがすべて存在する場合の集計
- valueが一部nilの場合
- 同一パラメータでの再実行（冪等性）
- DB保存失敗時の挙動

### Why it's good
- コードを読まなくても「何を・なぜ・どうやるか」が理解できる
- 責務・境界・不変条件が明示され、合意ポイントがはっきりする
- 実装が変わっても設計判断が残り続ける

### One-sentence principle
詳細設計書は「実装の説明」ではなく、**チームが合意すべき意図と仕組みを固定する文書**。

