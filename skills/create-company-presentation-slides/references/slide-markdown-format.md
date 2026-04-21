# Slide Markdown Format

## 目的

この format は、社内向けプレゼン資料を **Markdown で先に固める** ためのものです。

- 最初は骨子だけでもよい
- 固まってきたら slide copy と visual hint を足す
- PowerPoint に移す前の source of truth として使う

## まず押さえる項目

資料の冒頭に、最低限次を置く。

```md
# 資料タイトル

- audience:
- occasion:
- goal:
- change:
- takeaway:
- duration:
```

### 各項目の意味

- `audience`: 誰に向けた資料か
- `occasion`: どの場で話すか
- `goal`: この発表で達成したいこと
- `change`: 聞き手に変わってほしい認識や行動
- `takeaway`: 最後に残したい一文
- `duration`: 話す時間の目安

## 骨子の基本形

各スライドは次の単位で書く。

```md
## Slide 1: タイトル
- role:
- message:
- body:
  - 1 行目
  - 2 行目
- visual:
- note:
```

## 各項目の使い分け

- `role`: この slide の役割
  - 例: opening / agenda / current-state / issue / action / example / closing
- `message`: その slide で言いたいことを 1 行で書く
- `body`: slide 上に置く文章の下書き
- `visual`: 図、カード、比較表、時系列などの見せ方メモ
- `note`: 話すときの補足。slide に直接は載せない

## 最小の骨子例

```md
# 17期3Q データ基盤キックオフ

- audience: データ基盤チーム
- occasion: Q kickoff
- goal: 今Qの重点を揃える
- change: 迷ったときの判断軸を揃える
- takeaway: 今Qは品質と前進を両立する
- duration: 15分

## Slide 1: オープニング
- role: opening
- message: 今Qの重点を最初に言い切る
- body:
  - 17期3Q
  - データ基盤キックオフ
- visual: 表紙
- note: タイトルだけで入る

## Slide 2: 現状
- role: current-state
- message: 前進しているが、まだ揃っていない
- body:
  - 開発は進んでいる
  - ただし判断軸はまだ揃っていない
- visual: 2 カード比較
- note: 事実と危機感を揃える

## Slide 3: 今Qの重点
- role: action
- message: まず品質の土台を揃える
- body:
  - 低レベルな迷いを減らす
  - 重要な改善に時間を使う
- visual: 重点を 2 つ並べる
- note: やらないことも口頭で添える

## Slide 4: 締め
- role: closing
- message: 最後に残したい一文を置く
- body:
  - 今Qは品質と前進を両立する
- visual: 1 メッセージで締める
- note: 行動への期待で締める
```

## 書き方のルール

- 1 slide 1 message
- `message` は説明ではなく断定にする
- `body` は 2〜3 行程度に抑える
- 詳細説明は `note` に逃がす
- PowerPoint に移したあとも、この Markdown を原稿の正とする
