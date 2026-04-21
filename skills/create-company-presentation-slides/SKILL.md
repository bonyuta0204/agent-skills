---
name: create-company-presentation-slides
description: 社内向けの発表資料やキックオフ資料を作るときに、いきなり PowerPoint を作らず、まずユーザーと擦り合わせながら story を設計し、次に slide ごとの骨子を Markdown で固め、最後に必要なときだけ PowerPoint 化する 3 段階 workflow の skill。
---

# Create Company Presentation Slides

## この skill の目的

この skill は、社内向けスライドを **story の設計 -> slide ごとの骨子化 -> PowerPoint への仕上げ** の 3 段階で作るためのものです。

特に次のような資料に向いています。

- キックオフ
- 方針共有
- 振り返り
- 社内ナレッジ共有
- チーム向けの期待値合わせ

この skill は、PowerPoint を直接作る skill ではありません。まず伝える流れを作り、そのあとで slide 単位に落とし、最後に必要なら `PowerPoint` skill に渡します。

## 我々のスライドの特徴

この skill では、次の特徴を前提に slide を作る。

- まず story があり、見た目はその story を強く見せるために使う
- 1 枚 1 メッセージが強く、1 slide に複数論点を詰め込まない
- 文章量は少なく、短い断定文を大きく見せる
- 箇条書きで説明しきるより、見出し・カード・比較・並列配置で理解させる
- 写真や装飾より、図形と文字で構成する slide が多い
- 同じレイアウト archetype を繰り返し使い、流れで読ませる

より具体的な表現ルールは [references/company-slide-style.md](references/company-slide-style.md) を読む。

## 進め方

### 1. Story Design

最初に、slide を書く前に story を設計する。

必ず詰める。

- 誰に向けた話か
- どの場で話すか
- 今回いちばん変えたい認識や行動は何か
- 最後に残したい一文は何か

必要なら次も確認する。

- 聞き手の前提知識
- 話す時間
- 既に決まっている message
- 避けたいトーン

この段階の成果物は、`slide そのもの` ではなく **資料全体の筋**。

- 資料タイトル
- opening で何を言うか
- どの順で話を進めるか
- closing をどこへ着地させるか

Story design の format は [references/slide-markdown-format.md](references/slide-markdown-format.md) の `Story Design` を使う。

### 2. Slide-Level Outline

story が固まったら、次に slide ごとの骨子へ落とす。

この段階では、各 slide について次を決める。

- その slide の役割
- その slide で言いたいこと
- 何行くらいで見せるか
- どんな layout archetype が合うか

まだ PowerPoint の仕上げや細かい文言調整には入りすぎない。ここで欲しいのは、**見出しだけ見ても流れが通る状態**。

Slide-level outline の format は [references/slide-markdown-format.md](references/slide-markdown-format.md) の `Slide Outline` を使う。

### 3. Slide Production

outline が固まったら、各 slide を実際の slide copy にする。

- 1 枚 1 メッセージ
- 2〜3 行で言い切る
- 説明より断定を優先する
- 強調したい語だけを太くする、または色を変える前提で書く
- 読ませる paragraph ではなく、見た瞬間に意味が伝わる文量にする

必要なら次も添える。

- 補足メモ
- 話すときの口頭説明
- 図解やカード配置などの visual hint
- PowerPoint 化するときの handoff

Slide production の format は [references/slide-markdown-format.md](references/slide-markdown-format.md) の `Slide Production` を使う。

### 4. PowerPoint が必要なときだけ仕上げる

PowerPoint が必要なら、最後に `PowerPoint` skill を使う。

- 既存テンプレートがあるならそれを優先する
- story と outline を変えずに PowerPoint に流し込む
- PowerPoint 側では見た目の整形と配置調整に集中する

ユーザーが Markdown までを求めている場合は、PPTX まで進めない。

## スライド文体ルール

- タイトルだけで 1 枚の意味が分かるようにする
- 1 枚に複数の論点を詰め込まない
- 長い説明文より、短い断定文を優先する
- 抽象語だけで済ませず、必要なら具体例を 1 つ置く
- 現状 / 問題 / アクション / 締め を 1 枚で混ぜない
- 相手を責める語り口より、何を揃えるか・何を目指すかが伝わる語り口を優先する

## 出力

返却は、原則として次の順で行う。

1. Story design
2. Slide-level outline
3. Slide production
4. 必要なら PowerPoint 用の handoff、または PPTX

## 参考

- 段階別 Markdown format: [references/slide-markdown-format.md](references/slide-markdown-format.md)
- 我々のスライドらしさ: [references/company-slide-style.md](references/company-slide-style.md)
- 最終的な PPTX 化: `PowerPoint` skill
