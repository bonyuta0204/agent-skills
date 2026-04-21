# Slide Markdown Format

## 目的

この format は、社内向けプレゼン資料を **3 段階で固める** ためのものです。

1. Story Design
2. Slide Outline
3. Slide Production

最初から slide copy を書き込まず、先に全体の筋を作る。

## 1. Story Design

まずは資料全体の筋だけを決める。

```md
# 資料タイトル

- audience:
- occasion:
- goal:
- change:
- takeaway:
- duration:

## Story
- opening:
- tension:
- sections:
  - section 1:
  - section 2:
  - section 3:
- closing:
```

### 各項目

- `audience`: 誰に向けた資料か
- `occasion`: どの場で話すか
- `goal`: この発表で達成したいこと
- `change`: 聞き手に変わってほしい認識や行動
- `takeaway`: 最後に残したい一文
- `duration`: 話す時間
- `opening`: 最初に何を言うか
- `tension`: 今回の話で乗り越えたいズレや問題意識
- `sections`: どの順番で話すか
- `closing`: 最後にどう締めるか

## 2. Slide Outline

story が固まったら、slide ごとの骨子に落とす。

```md
## Slide 1: タイトル
- role:
- message:
- layout:
- beats:
  - beat 1
  - beat 2
- visual:
```

### 各項目

- `role`: opening / agenda / current-state / issue / action / comparison / closing など
- `message`: その slide で言いたいことを 1 行で書く
- `layout`: どの archetype で見せるか
- `beats`: slide 上で見せる要素の順番
- `visual`: カード、比較、時系列、1 メッセージなどの見せ方メモ

## 3. Slide Production

outline が固まったら、実際に slide に載せる文言へ落とす。

```md
## Slide 1: タイトル
- role:
- message:
- copy:
  - 1 行目
  - 2 行目
- visual:
- note:
```

### 各項目

- `copy`: slide 上に載せる文言の確定版
- `visual`: 配置やパーツ構成のメモ
- `note`: 話すときの補足。slide に直接は載せない

## 最小例

```md
# 17期3Q データ基盤キックオフ

- audience: データ基盤チーム
- occasion: Q kickoff
- goal: 今Qの重点を揃える
- change: 迷ったときの判断軸を揃える
- takeaway: 今Qは品質と前進を両立する
- duration: 15分

## Story
- opening: 今Qの重点を最初に言い切る
- tension: 開発は進んでいるが、判断軸はまだ揃っていない
- sections:
  - 現状を揃える
  - 今Qの重点を示す
  - 期待する行動を揃える
- closing: 今Qは品質と前進を両立する

## Slide 1: オープニング
- role: opening
- message: 今Qの重点を最初に言い切る
- layout: title slide
- beats:
  - 17期3Q
  - データ基盤キックオフ
- visual: 表紙

## Slide 2: 現状
- role: current-state
- message: 前進しているが、まだ揃っていない
- layout: 2 card comparison
- beats:
  - 開発は進んでいる
  - 判断軸はまだ揃っていない
- visual: 左右比較

## Slide 3: 今Qの重点
- role: action
- message: まず品質の土台を揃える
- layout: stacked action cards
- beats:
  - 低レベルな迷いを減らす
  - 重要な改善に時間を使う
- visual: 重点を 2 つ並べる

## Slide 4: 締め
- role: closing
- message: 最後に残したい一文を置く
- copy:
  - 今Qは品質と前進を両立する
- visual: 1 メッセージで締める
- note: 行動への期待で締める
```

## 書き方のルール

- Story Design では slide copy を書き込みすぎない
- Slide Outline では flow を壊さず、1 slide 1 message を守る
- Slide Production では `copy` を 2〜3 行程度に抑える
- PowerPoint に移したあとも、この Markdown を原稿の正とする
