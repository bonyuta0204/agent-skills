---
name: review-product-doc-set
description: 要件定義書・仕様書・画面項目定義書を文書セットとして読み、3つの専門レビュー観点（文書構造・仕様品質・可読性）で並列レビューし、結果を統合して日本語のレビューコメント案を返す skill。
---

# Review Product Doc Set

## この skill の目的

この skill は、要件定義書・仕様書・画面項目定義書を **文書セット全体として、複数の観点から並列レビューする** ためのものです。

3 つの専門 reviewer agent を並列に起動し、それぞれの結果を orchestrator が統合します。

| Reviewer | 観点 | プロンプト |
|----------|------|-----------|
| **Structural Reviewer** | 文書構造 — 責務分離・重複・整合性・参照の向き | `references/structural-reviewer.md` |
| **Spec Quality Reviewer** | 仕様品質 — 考慮漏れ・エッジケース・曖昧なルール | `references/spec-quality-reviewer.md` |
| **Readability Reviewer** | 可読性 — 伝わりやすさ・構成・用語統一 | `references/readability-reviewer.md` |

## この skill を使う場面

- 要件定義書 / 仕様書 / 画面項目定義書のレビューを頼まれたとき
- Notion 上の文書群について多面的にレビューしたいとき
- 「仕様に抜けがないか」「読みやすいか」「文書の置き場所は合っているか」をまとめて確認したいとき

次の場面では別 skill を優先します。

- GitHub PR 上の設計書レビューなら `review-design-doc`
- 実装 PR のコードレビューなら `pr-implementation-review`
- コードの責務配置や依存方向を中心に見るなら `code-architecture-review`

## 進め方

### Step 1: 対象文書の特定と読み込み

1. レビュー対象の文書を特定する
   - 要件定義書、仕様書、画面項目定義書の所在を確認する
   - 関連する Figma ファイルや共通仕様書があれば把握する
   - Notion MCP や Figma MCP を使って対象文書を読み込む

2. 文書間の対応関係を整理する
   - どの要件定義書がどの仕様書に対応するか
   - どの仕様書がどの画面項目定義書・Figma に対応するか

### Step 2: ドメインコンテキストの収集

reviewer agent に渡すドメイン知識を収集する。

- 作業リポジトリの CLAUDE.md / AGENTS.md を読む
- リポジトリ内の `docs/` やドキュメントディレクトリを確認する
- 必要に応じて関連するソースコード（モデル定義、バリデーション、API）を読む
- 必要に応じて deepwiki MCP でリポジトリの構造を把握する

### Step 3: 3 reviewer agent の並列起動

Agent tool を使い、以下の 3 agent を **並列で** 起動する。

各 agent には以下を渡す:
- 対応する reviewer プロンプト（`references/` 配下の該当ファイル）の内容
- Step 1 で収集した対象文書の内容
- Step 2 で収集したドメインコンテキスト
- `references/comment-format.md` のコメント書式

#### Agent 1: Structural Reviewer

`references/structural-reviewer.md` の指示に従い、文書構造の観点でレビューする。
責務分離・重複・整合性・参照の向き・将来の分解方針への適合を見る。

#### Agent 2: Spec Quality Reviewer

`references/spec-quality-reviewer.md` の指示に従い、仕様品質の観点でレビューする。
条件分岐の網羅性・境界値・エラー系・暗黙の前提・データ整合性・並行性を見る。

#### Agent 3: Readability Reviewer

`references/readability-reviewer.md` の指示に従い、可読性の観点でレビューする。
読者と目的の明確さ・構成と流れ・用語の一貫性・粒度・曖昧表現・図表の効果を見る。

### Step 4: 結果の統合

3 agent の結果が揃ったら、orchestrator として以下を行う。

#### 4-1. 重複指摘の除去

複数の reviewer が同じ箇所について指摘している場合:
- 観点が異なるなら両方残す（同じ箇所でも構造の問題と仕様の問題は別）
- 実質的に同じ指摘なら、より具体的な方を残してマージする

#### 4-2. 優先度の再整理

全指摘を通しで見て、優先度を再評価する。

- `MUST` が多すぎないか — 本当に「直さないと事故になる」ものだけが MUST か
- reviewer 間で同じ箇所に MUST と SHOULD が混在している場合、より適切な方に統一する
- 指摘の依存関係を考慮する（A を直せば B は自然に解消する、など）

#### 4-3. 総評の作成

個別指摘の羅列だけでなく、文書セット全体の傾向を総評としてまとめる。

- 3 つの観点それぞれで最も重要な課題は何か
- 文書セット全体として改善すべき方向性
- すぐに着手すべきことと、中長期で取り組むことの区分

### Step 5: 出力

以下の順で返却する。

1. **総評** — 文書セット全体の傾向と改善の方向性（3〜5 行程度）
2. **MUST** — 直さないと事故になる指摘
3. **SHOULD** — 改善すると品質が上がる指摘
4. **QUESTION** — 意図確認が必要な箇所

各コメントには以下を含める:
- 対象箇所
- どの観点からの指摘か（構造 / 仕様品質 / 可読性）
- 問題の内容
- 問題になる理由
- 改善案

## 参考資料

- `references/structural-reviewer.md` — 文書構造レビューの指示
- `references/spec-quality-reviewer.md` — 仕様品質レビューの指示
- `references/readability-reviewer.md` — 可読性レビューの指示
- `references/review-rubric.md` — 構造レビューの詳細判定軸
- `references/comment-format.md` — コメントの書き方
- `references/documentation-improvement-proposal.md` — 文書改善提案の背景
