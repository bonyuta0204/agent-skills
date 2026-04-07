---
name: dx-kpiee-go-arch-review
description: dx-kpiee の Go コードや PR を、domain model を中心に DDD / Clean Architecture / Onion Architecture の観点でレビューする skill。`backend/go` の変更に対して、業務概念の意味や判断が domain の内側で一貫しているか、struct / method の責務分解が自然か、集約境界や保存責務が外へ漏れていないか、移行都合や DTO / infra 都合が domain を汚していないかを確認したいときに使う。バグ一般の網羅レビューではなく、責務配置と境界の妥当性を評価したい場面に使う。
---

# dx-kpiee Go Architecture Review

## この skill の目的

この skill は、`backend/go` の変更を **domain model を中心に責務配置の自然さでレビューする** ためのものである。

最初に問うのは layer 違反ではない。まず問うのは以下。

* この変更で増えた、または変わった業務概念は何か
* その概念の意味や判断を、domain の内側が引き受けているか
* struct / method / service / repository の責務分解が自然か

layer や dependency の確認は重要だが、**domain の一貫性を壊していないかを確かめるための後段チェック** として扱う。

以下は主目的ではない。

* バグ一般の網羅レビュー
* 命名や細かな書き方の好み
* パフォーマンス一般のレビュー
* 未変更箇所の全面リファクタ要求

---

## 対象スコープ

* 対象は `backend/go` の変更に限定する
* 主眼は以下

  * domain model への判断集約
  * struct / method の責務分解
  * 集約境界と保存責務
  * usecase / helper / repository への意味解釈の漏れ
  * 移行都合や transport / infra 都合の内側侵入
  * layer 責務と依存方向

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
2. 変更で増えた、または意味が変わった業務概念を特定する。
3. その概念を `domain model -> domain service -> usecase -> repository -> adapter` の順に追う。
4. 意味解釈、状態判断、組み立て、保存の都合がどこにあるかを整理する。
5. 責務の漏れや重複を指摘する。
6. 最後に layer / dependency の違反を確認する。

変更ファイルだけで判断せず、同じ機能の近傍ファイルを 1-2 本読む。

### 近傍ファイルとして読む候補

* 同じ aggregate を扱う model / service / repository / usecase
* 同系統 endpoint の adapter
* 同責務の既存実装
* repo 内で比較的良い実装例

---

## 最初に置く問い

レビューでは、以下の問いを先に立てる。

* この PR で増えた、または変わった業務概念は何か
* その概念の owner はどの model / service か
* その判断を本来どこが知っているべきか
* 移行や永続化の都合が、その概念の本来の形を崩していないか

「どの layer にいるか」だけではなく、**その責務をそこが持つのが自然か** を見る。

---

## 見る順番

## 1. 業務概念の中心はぶれていないか

まず、新しく入った概念や大きく変わった概念を主役にして見る。

* model がその概念の意味を説明できる形になっているか
* 同じ field や type の意味解釈が複数箇所に散っていないか
* 一時的な移行都合の表現を domain の内側まで持ち込んでいないか
* report 側と widget 側のように、近い概念の責務配置が不自然にずれていないか

この段階では、`if` や `switch` の数よりも、**誰がその意味を知っているか** を重視する。

---

## 2. domain model が単なる入れ物になっていないか

以下の兆候があれば、貧血ドメインの疑いが強い。

* model が単なる struct の受け皿になっている
* 重要な判断が usecase 側の `if` や `switch` に並んでいる
* 同じ model に対する判断が複数 usecase / helper / repository に散っている
* `type`、`status`、`flag`、`nil 判定`、`len(...) == 0` の組み合わせで意味解釈を繰り返している

### このときの基本姿勢

* `P-DOM-02` と `AP-04` を中心に見る
* 「その分岐はこの model 自体が知っているべきか」を必ず一度問う
* 単なる getter を増やす提案はしない
* **判断** や **状態解釈** がまとまるときだけ model メソッド化を提案する

---

## 3. struct / method の責務分解は自然か

各 struct や method について、以下を見る。

* その struct は何の判断の owner か
* その method は何を決めてよいのか
* 単一概念の判断なのか、複数概念をまたぐ調停なのか
* それなら model / domain service / usecase のどこに置くのが自然か

### 不自然な分解の典型

* method を切り出しただけで、責務の本体は usecase に残っている
* domain service ではなく usecase helper に業務判断を逃がしている
* repository が保存形式だけでなく業務上の意味まで知っている
* adapter や converter が domain object の中核ロジックを持っている

---

## 4. 集約境界と保存責務が漏れていないか

特に以下を見る。

* 集約内部の子要素の保存手順を usecase / service が知っていないか
* repository interface が domain 語彙ではなく技術語彙ベースになっていないか
* SQLBoiler model と domain model の変換が repository の外へ漏れていないか
* 「何を保存したいか」ではなく「どう保存するか」が usecase に漏れていないか

### 見方のポイント

* 子要素が集約内部の関心なら、保存の都合は repository 実装の内側に寄せたい
* service が複数 repository を細かく操作して整合を保っているなら、集約境界の漏れを疑う
* 別 repository に分かれていても、domain の公開境界として分ける必要があるかは別問題として見る

---

## 5. usecase が業務判断を抱え込みすぎていないか

usecase の役割は、順序制御と依存調停が中心である。

以下の兆候があれば、手続き型に流れている疑いがある。

* `fetch A -> fetch B -> 条件分岐 -> 値組み立て -> 別 repository 更新` が長く続く
* 業務上の判断が usecase 内の `if` / `switch` に滞留している
* helper 関数へ逃がしただけで、usecase package 内に判断が残っている
* 複数 entity にまたがる判断を domain service 化せず、usecase が直接抱えている

### 基本方針

* 単一 entity / value object の状態解釈なら、まず model メソッド化を検討する
* 複数 entity / value object にまたがる判断なら、domain service を検討する
* usecase 専用 helper に閉じ込めて済ませない

---

## 6. 移行都合や外側の都合が内側を汚していないか

移行 PR では、以下を独立した観点で見る。

* 旧表現と新表現の併存は本当に最小限か
* 暫定コードが domain model や usecase の中核まで侵入していないか
* 将来的に取り除くべき知識が、複数 layer に拡散していないか

また、transport / infra 都合について以下を見る。

* ogen 生成型が Adapter の外へ漏れていないか
* request / response DTO が usecase / domain に侵入していないか
* ORM や DB 保存形式の事情を domain が知っていないか

---

## 7. 最後に layer / dependency を確認する

最後に構造違反を確認する。

* `Domain -> Infrastructure` を増やしていないか
* `Usecase -> Infrastructure` 直接依存を新規追加していないか
* `Infrastructure -> Usecase` の逆依存がないか
* `Adapter` が業務判断や集計条件を持っていないか
* account 境界が `accountID` 引数の都度受け渡しに流れていないか

指摘時は、必要に応じて `docs/go-layered-arch.md` の原則 ID を付ける。

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

* domain model が単なる入れ物になっている
* 同じ概念の意味解釈が複数箇所に散っている
* 集約境界や保存責務が usecase / service へ漏れている
* 単一概念の判断を model が持たず、外側が知りすぎている
* 移行都合の表現が domain の内側まで侵入している

### Minor

即ブロックではないが、将来の責務拡散につながるもの。

* helper 化だけで責務の本体が usecase に残っている
* 近い概念どうしの責務配置に軽いズレがある
* primitive のまま業務概念を受け渡している
* 既存負債をわずかに拡大している

行数の多さ自体を問題にしない。問題は、**どの責務がどこに滞留しているか** で判断する。

---

## 指摘の書き方

指摘では、まず業務概念を主語にする。

1. どの概念の責務がずれているかを書く
2. どこに知識が散っているかを書く
3. なぜその置き場が不自然かを書く
4. 必要なら、model / domain service / usecase のどこに寄せるべきかを短く添える

### 望ましい書き方

* 「`DisplaySettingItem` の意味解釈が model に閉じず、repository と builder と usecase に散っています」
* 「`Widget` 集約の子要素保存の都合を service が知っており、保存責務が集約境界の外に漏れています」

### 避けたい書き方

* 「if が多いです」
* 「もっと domain に寄せた方がいいです」
* 「repository を整理してください」

抽象語だけで終わらせず、**どの概念の何の責務が、どこに漏れているか** を具体化する。

---

## 出力スタイル

* バグ一般の網羅より、責務配置と境界の指摘を優先する
* findings は優先度順に並べる
* 軽い違和感より、domain の一貫性を崩す論点を優先する
* 既存負債がある場合でも、この PR で新たに拡大しているかを重視する

---

## 最後に確認すること

レビューを書き終える前に、以下を自問する。

* 今回の指摘は「どの layer か」だけでなく、「誰がその意味を知るべきか」に踏み込めているか
* model / service / usecase / repository の責務の置き場を、自然さで説明できているか
* 一時的な移行都合と、本来の domain 形状を区別して見られているか

この skill では、**内側がぶれていないか** を最優先で見る。
