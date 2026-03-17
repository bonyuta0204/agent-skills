# dx-kpiee Go Architecture Review Checklist

## 優先順

1. 構造違反
2. 境界の曖昧化
3. 責務の置き場所
4. 既存負債の拡大
5. テスタビリティ低下

## 構造違反

- `P-DOM-01`: Domain が `internal/infrastructure` に依存していないか
- `P-UC-01`: Usecase が `internal/infrastructure` に直接依存していないか
- `P-INF-01`: Infrastructure が `internal/usecase` に依存していないか
- `P-ADP-03`: Adapter の `infrastructure` 依存が増えすぎていないか

## 責務配置

- `P-ADP-01`: Adapter は受け取り、変換、エラーマッピングに留まっているか
- `P-ADP-02`: ogen 型が Adapter の外へ漏れていないか
- `P-DOM-02`: ドメイン判断を model / domain service に寄せられているか
- `AP-04`: 条件分岐が Usecase や helper に散在していないか
- `P-INF-03`: SQLBoiler と domain model の変換が repository 外へ漏れていないか

## 貧血ドメイン

- `status` / `type` / `flag` の解釈を usecase が毎回していないか
- 同じ entity の判断が複数 usecase や helper に散っていないか
- model 側に「できる / できない」「遷移する」「反映する」といった意味のある操作が存在するか
- getter や field 露出ではなく、業務判断そのものを model / domain service に寄せる提案になっているか

## 手続き型

- usecase が順序制御を超えて、業務ルールの解釈まで抱え込んでいないか
- helper へ分けただけで usecase package 内に業務判断が滞留していないか
- `fetch -> branch -> mutate -> persist` の繰り返しに、domain として名前を持てる塊がないか
- 「if が多い」ではなく、「domain が知るべき if を usecase が知っている」状態を指摘できているか

## account 境界

- `P-DOM-06`: account 依存の service / factory は生成時に account を固定しているか
- `AP-07`: 同一インスタンスのメソッドで `accountID` を都度受けていないか
- 例外の account 非依存参照はコメントや PR 説明で理由が明示されているか

## Usecase 設計

- `P-UC-02`: 新規 or 実質新規の usecase が 500 行を大きく超えていないか
- `P-UC-03`: usecase 間依存を増やしていないか
- `P-UC-04`: usecase 内で domain service や helper を inline 生成していないか
- `AP-05`: sentinel error で正常系フローを分岐していないか

## repo 固有メモ

- [backend/go/internal/usecase/data_connector/post_hook_service.go](/Users/yuta.nakamura/workspace/github.com/f-scratch/dx-kpiee/backend/go/internal/usecase/data_connector/post_hook_service.go)
  - account 固定の良い参照例
- [backend/go/internal/usecase/reports/show_usecase.go](/Users/yuta.nakamura/workspace/github.com/f-scratch/dx-kpiee/backend/go/internal/usecase/reports/show_usecase.go)
  - 既存の巨大 usecase。軽微修正だけで全面分割を要求しない
- [backend/go/internal/usecase/widgets/data_usecase.go](/Users/yuta.nakamura/workspace/github.com/f-scratch/dx-kpiee/backend/go/internal/usecase/widgets/data_usecase.go)
  - 同上
- [backend/go/internal/domain/interfaces/repository/database_factory.go](/Users/yuta.nakamura/workspace/github.com/f-scratch/dx-kpiee/backend/go/internal/domain/interfaces/repository/database_factory.go)
  - account / application DB を factory で切り替える repo 前提
- `internal/domain` からの `kplogger` 直 import は既存に多い
  - 未変更箇所の存在だけでは全面 NG にしない
  - 新規追加や依存拡大なら指摘候補

## コメント雛形

`P-UC-01`: この usecase が `infrastructure` の具象実装を直接 import してしまっており、repo の依存方向を外向きに破っています。ここで具象型を知るようにすると DI とテスト差し替えの境界が崩れるため、Domain interface 経由に戻したいです。

`P-DOM-06`: account 依存の処理なのに同じ service インスタンスがメソッドごとに `accountID` を受け直しています。この形だと「この service がどの account の責務を持つか」が構造上固定されず、境界逸脱を見逃しやすくなります。`CreateForAccount` で account 固定のインスタンスを作る形に寄せたいです。

`AP-04`: この条件分岐は usecase の手順制御ではなく、`Report` 自体の振る舞いの判断に見えます。usecase 側に判断が散ると同じ条件が別経路にも増えやすいため、domain model または domain service に寄せた方がこの repo の責務分担に合います。

`P-DOM-02`: ここで見ているのは単なるデータ更新ではなく、`Report` が今どの状態として扱えるかの業務判断です。判断が usecase 側の `if` に残ると別経路でも同じ条件を持ち始めるため、この entity 自身の操作か domain service に寄せて、usecase は順序制御に留めたいです。

`AP-04`: helper に切り出されてはいますが、依然として usecase package の中で業務判断を手続き的に並べています。分割で見通しは少し上がっても責務の置き場所は変わっていないため、domain として名前を持てる塊まで引き上げないと同じ判断が他の経路にも増えやすいです。
