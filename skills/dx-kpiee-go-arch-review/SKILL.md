---
name: dx-kpiee-go-arch-review
description: dx-kpiee の Go コードや PR を、DDD / Clean Architecture / Onion Architecture の観点に絞ってレビューする skill。`backend/go` の変更に対して、レイヤー責務、依存方向、domain への振る舞い集約、貧血ドメイン、手続き型に流れた usecase / service、account 境界、DTO 漏れ、DI / テスタビリティ、transaction boundary、value object の欠如を確認したいときに使う。バグ一般の網羅レビューではなく、設計の置き場所と境界の妥当性を評価したい場面に使う。
---

# dx-kpiee Go Architecture Review

## この skill の目的

この skill は、`backend/go` 配下の変更に対して、dx-kpiee の layered / clean / onion architecture の原則に照らして、**どの責務をどの layer に置くべきか**、**依存方向が壊れていないか**、**既存負債を再生産・拡大していないか**をレビューするためのものである。

以下は主目的ではない。

* バグ一般の網羅レビュー
* 命名や細かな書き方の好み
* パフォーマンス一般のレビュー
* 未変更箇所の全面リファクタ要求

レビューでは、理想論ではなく、**この repo の既存原則と現実的な改善余地**に基づいて指摘する。

---

## 対象スコープ

* 対象は `backend/go` の変更に限定する
* 主眼は以下

  * layer 責務
  * 依存方向
  * domain への振る舞い集約
  * usecase の責務肥大化
  * account 境界
  * DTO 漏れ
  * DI / テスタビリティ
  * transaction boundary
  * value object 不在による primitive 汚染

---

## 最初に読むもの

レビュー開始時に、まず以下を読む。

* `AGENTS.md`
* `.windsurf/rules/go-arch.md`
* `docs/go-layered-arch.md`
* `references/review-checklist.md`

repo ルールと矛盾する一般論は優先しない。判断に迷う場合は `docs/go-layered-arch.md` の原則 ID を基準にする。

---

## 進め方

1. レビュー対象を `backend/go` に限定する。
2. 差分ファイルを layer ごとに分類する。

   * `internal/adapter`
   * `internal/usecase`
   * `internal/domain`
   * `internal/infrastructure`
3. 変更ファイルだけで判断せず、同じ機能の近傍ファイルを 1-2 本読む。
4. まず構造違反を探す。
5. 次に責務配置のズレを見る。
6. 次に既存負債の再生産や拡大を確認する。
7. 最後に指摘を優先度順に整理する。

### 近傍ファイルとして読む候補

以下から 1-2 本を選ぶ。

* 同じ aggregate を扱う domain / repository / usecase
* 同系統 endpoint の adapter
* 同責務の既存実装
* repo 内で比較的良い実装例

「変更ファイルだけ見る」のではなく、**その変更が repo の設計文脈の中でどう見えるか**を確認する。

---

## 優先度の基準

### Blocker

マージ前に直すべきもの。

* Must 原則違反
* 依存方向の逆転
* DTO / ogen 型の layer 漏れ
* account 境界の破壊
* transaction boundary の破綻
* domain / usecase / adapter に transport / infra 都合が強く漏れているもの

### Major

設計負債を増やすため、強く改善を勧めるもの。

* domain に寄せるべき業務判断が usecase / helper に滞留
* repository interface が domain 語彙でなく技術語彙ベース
* domain model が単なるデータ入れ物になっている
* 具象依存が増え、DI / テスタビリティが悪化
* 既存負債パターンを新規に再生産している

### Minor

即ブロックではないが、将来の複製や責務拡散につながるもの。

* helper 化だけで責務の本体が usecase に残っている
* 長大な usecase にさらに責務を追加している
* primitive のまま業務概念を受け渡している
* 既存負債をわずかに拡大している

行数の多さ自体を問題にしない。問題は、**どの責務がどこに滞留しているか**で判断する。

---

## 見る順番

## 1. 依存方向

最初に構造違反を確認する。

* `Domain -> Infrastructure` を増やしていないか
* 原則として `Usecase -> Infrastructure` 直接依存を新規追加していないか
* `Infrastructure -> Usecase` の逆依存がないか
* `Adapter` から `Infrastructure` を直接参照してよい範囲を超えていないか
* 指摘時は `docs/go-layered-arch.md` の原則 ID を付ける

### Adapter で許容されること

* DI wiring
* request / response の変換
* 認証文脈の抽出
* 薄い入出力補助

### Adapter で許容されないこと

* 業務条件分岐
* 複数 repository / service の調停
* domain object 組み立ての中核ロジック
* 集計条件や業務ルールの解釈

例外が必要なら、**interface 越しに抽象化できない理由**が明示されているか確認する。

---

## 2. 責務の置き場所

* Adapter が業務判断や集計条件を持っていないか
* Usecase が単なる順序制御を超えて、domain 判断を抱え込みすぎていないか
* Domain model / domain service に寄せるべき条件分岐が Usecase や helper に散っていないか
* Repository interface が技術語彙ではなく domain 語彙になっているか
* SQLBoiler model と domain model の変換が repository の外へ漏れていないか

### Repository interface で特に見ること

* `FindByIDsAndAccountID` のように DB 都合の API に寄りすぎていないか
* `SaveRawRows` のような infrastructure 起点の命名になっていないか
* domain 側が「どう取得するか」ではなく「何を欲しいか」で依存できているか
* SQLBoiler / ORM の事情が interface ににじんでいないか

---

## 2.5. 貧血ドメインの兆候

* model が単なる struct の受け皿になっていないか
* 重要な判断が usecase 側の `if` や `switch` に並んでいないか
* `status`、`type`、`flag`、`nil 判定`、`len(...) == 0` の組み合わせで業務判断を繰り返していないか
* 更新可能か、公開可能か、再計算対象か、といった判断が model / domain service に寄っていないか
* 同じ model に対する判断が複数 usecase / helper にコピペされていないか

### 貧血ドメインを見るときの原則

* `P-DOM-02` と `AP-04` を中心に見る
* 「その分岐はこの model 自体が知っているべきか」を必ず一度問う
* 単なる getter を増やす提案はしない
* **判断**や**状態遷移**がまとまるときにだけ model メソッド化を提案する

### 典型例

* `report.Status == ...` を複数箇所で分岐する
* `report.ShowUnregisteredCodes` や `widget.Type` の解釈が usecase ごとに散る
* 業務判断が `CanPublish`, `CanRecalculate`, `NeedsPostHook` のような操作にまとまっていない

---

## 2.6. 手続き型に流れている兆候

* 長い usecase が「順番に repository を呼ぶだけ」に見えても、その途中に業務判断が混ざった時点で手続き型の疑いがある
* `fetch A -> fetch B -> 条件分岐 -> 値組み立て -> 別 repository 更新` が続くときは、どの塊が業務概念として名前を持てるかを見る
* helper 関数へ逃がしただけで、usecase package 内に業務判断が滞留している場合は改善扱いにしない
* 「if が多い」こと自体ではなく、「if の意味が domain に属しているのに usecase が知っている」ことを問題として書く

### model と domain service の使い分け

* 単一 entity / value object の状態解釈なら、まず model メソッド化を検討する
* 複数 entity / value object にまたがる業務判断なら、domain service を検討する
* usecase 専用 helper に閉じ込めて済ませない
* domain service を便利箱にしない

---

## 3. account 境界

* account 依存の service / factory が `1インスタンス1アカウント` を基本にしているか
* 同じインスタンスの公開メソッドで `accountID` を毎回受け直していないか
* `workspace_user` など account 非依存の横断参照は例外理由が明示されているか
* account 固定にできるものを汎用 service のまま広げていないか

### 基準例

良い参照例として、`backend/go/internal/usecase/data_connector/post_hook_service.go` の `CreateForAccount` パターンを基準にする。

---

## 4. Usecase の健全性

* usecase の責務が順序制御と依存調停に留まっているか
* 新規または実質新規の usecase が大きくなりすぎていないか
* 行数ではなく、業務判断・値組み立て・状態解釈まで抱え込んでいないかを重視する
* Domain service を usecase 内で都度 `New...` していないか
* 別 usecase を直接呼び出していないか
* 戻り値で表現できる分岐を sentinel error で制御していないか

### 巨大 usecase の扱い

既存に巨大 usecase が存在していても、軽微修正だけで全面分割を要求しない。以下の場合に絞って指摘する。

* 責務がさらに増えた
* 追加ロジックの置き場所が悪い
* 分割しやすい塊を増やしている
* 既存負債を再生産している

---

## 5. DTO と transport leakage

* ogen 生成型が Adapter の外へ漏れていないか
* request / response DTO が usecase / domain に侵入していないか
* transport 都合の field や status 表現を usecase / domain が知っていないか
* 外部 API / DB / message queue の都合が domain object に混ざっていないか

DTO 漏れは Blocker 候補として扱う。

---

## 6. DI とテスタビリティ

* 新しい依存は interface 経由で注入されているか
* テストで差し替えにくい具象生成を増やしていないか
* 時刻、乱数、外部通信、logger、transaction manager などを直に握り込んでいないか
* package 内 private helper に押し込めたせいで、逆にテスト不能になっていないか

具象依存が layer 責務を壊している場合は Major 以上で扱う。

---

## 7. transaction boundary

* transaction の開始 / 終了位置が一貫しているか
* 複数 repository 更新をまたぐ処理で整合性境界が曖昧でないか
* transaction 制御が domain 判断と混ざっていないか
* transaction の都合が domain interface に漏れていないか

transaction は「どこで張るか」だけでなく、**どの業務操作を一つの整合性単位として扱うか**を確認する。

---

## 8. Value Object と primitive 汚染

* `string`, `int`, `bool` のまま業務概念を受け渡していないか
* `AccountID`, `ReportStatus`, `WidgetType` などにできる概念が primitive のまま散っていないか
* 無効値の侵入を型で防げる箇所を放置していないか
* usecase / adapter が primitive の解釈ロジックを持ちすぎていないか

ただし、repo の既存スタイルに照らして過剰に value object 化を要求しない。**分岐の重複や意味の解釈が散る箇所**を優先的に見る。

---

## 9. エラーモデリング

* domain error と infrastructure error が混ざっていないか
* adapter で HTTP status や transport error に落とす責務が保たれているか
* usecase が transport 固有の error 表現を知っていないか
* 戻り値で表現できる業務分岐を error で横流ししていないか

「とりあえず sentinel error」で分岐させる実装は、責務のにじみとして見る。

---

## dx-kpiee 固有の前提

* `docs/go-layered-arch.md` の原則 ID をレビュー本文に引用する
* 新規コードは Must 原則違反を持ち込まない前提で見る
* 既存負債は「repo にすでにある」だけでは承認理由にならない
* ただし未変更箇所の全面改修は要求しない
* 既存負債を diff が拡大しているか、新しい実装が同じ負債を再生産しているかを重視する

---

## 既存負債の扱い

* `internal/domain` から `internal/infrastructure/kplogger` を直接 import している箇所は repo 内に広く存在する
* そのため、既存ファイルに同パターンが残っているだけで全面ブロックにはしない
* ただし、新規ファイルで同じ依存を増やす、または既存ファイルで依存範囲を広げる差分は `P-DOM-01` または `P-DOM-04` 文脈で指摘候補にする
* 巨大 usecase も既存に存在する。例として以下がある

  * `backend/go/internal/usecase/reports/show_usecase.go`
  * `backend/go/internal/usecase/widgets/data_usecase.go`
* 巨大ファイルに軽微修正が入っただけなら「今すぐ全面分割」は主張しない
* 指摘は「責務がさらに増えたか」「悪い置き場所のロジックが増えたか」に絞る

---

## レビューコメントの書き方

* 日本語で書く
* 理想論ではなく、**この repo のどの境界を壊しているか**を書く
* 可能なら `P-DOM-01` のような原則 ID を入れる
* 「長い」「複雑」だけで終わらせず、**何の業務判断を誰が持つべきか**を書く

### コメントの基本形式

* 問題: 何がどの境界を壊しているか
* 原因: 本来どの layer / model / service が持つべき責務か
* 影響: 何が複製されるか、何がテストしづらくなるか、何が今後つらくなるか
* 修正案: どこへ移すか、どう抽象化するか

### 貧血ドメインの指摘時

* 「model に寄せるべき判断」と「usecase に残す順序制御」を分けて書く
* 単なる getter の追加ではなく、判断や状態遷移としてまとまるかで提案する

### 手続き型の指摘時

* 「長い」ではなく、「何の業務判断が usecase に漏れているか」を書く
* helper に逃がしただけでは改善扱いにしない

---

## 出力形式

### findings がある場合

findings を優先度順に並べる。

各 finding に以下を含める。

* Priority: Blocker / Major / Minor
* File
* Line
* Rule ID
* 問題
* 原因
* 影響
* 修正案

### findings がない場合

指摘なしで終わらせず、以下を短く列挙する。

* 確認した layer
* 確認した主な観点
* 問題がなかった理由
* 気になったが今回問題化しなかった点があれば一言

### 出力例

```markdown
- Priority: Major
  File: backend/go/internal/usecase/reports/update_usecase.go
  Line: 84-112
  Rule ID: P-DOM-02
  問題: `report.Status` の解釈を usecase が直接持っており、公開可能判定が usecase に滞留している。
  原因: 状態解釈が `Report` model か domain service に集約されていない。
  影響: 同じ判定が別 usecase に複製されやすく、公開条件変更時の修正箇所が散る。
  修正案: 単一 entity の状態解釈なので、まず `Report` の操作として寄せることを検討する。
```

---

## レビュー時の最終判定基準

* **Approve 寄り**

  * 境界違反はなく、既存負債も拡大していない
* **Comment 必須**

  * 責務配置にズレがあり、将来の複製や密結合を増やす
* **Request changes**

  * Must 原則違反、依存方向違反、DTO 漏れ、account 境界破壊、transaction boundary 破綻がある

---

## 参照

* `references/review-checklist.md`
* `docs/go-layered-arch.md`
* `AGENTS.md`
* `CLAUDE.md`
* `.windsurf/rules/go-arch.md`
