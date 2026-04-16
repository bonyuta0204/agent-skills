# コメント形式

## 目的

- GitHub 上でぱっと読めて、レビューに入る順番がすぐ分かること
- 情報を詰め込みすぎず、固定コメントとして邪魔にならないこと
- Markdown の標準要素だけで安定して読めること

## 形式ルール

- 通常の Markdown 見出しと箇条書きだけを使う
- table は使わない
- raw JSON や enum をそのまま貼らない
- 1 コメントの冒頭で「この PR をどう読むか」を先に示す
- `推奨レビュー順` は numbered list にする
- `重点観点` は観点ラベルごとに 1 行ずつ短く書く
- `深追い不要の箇所` と `深く見る箇所` は分けて書く
- `人判断が必要` と `深追い優先度が低い箇所` は該当があるときだけ出す
- `根拠` と `不確実性` は最後に短く置く

## 推奨構成

```md
<!-- AI_PR_REVIEW_STOCKTAKE_START -->
## レビュー棚卸しメモ

- 概要: 検索条件追加に伴う API と画面の追従が中心
- まず見る: `app/usecase/search.ts` から入ると追いやすい

### 推奨レビュー順
1. `app/usecase/search.ts`
   - 条件分岐と validation の追加意図を確認する
2. `app/repository/searchRepository.ts`
   - usecase の変更が永続化境界にどう波及しているかを見る
3. `app/ui/search-form.tsx`
   - UI 側は主に追従か、独自ロジックが増えていないかを見る

### 重点観点
- `仕様確認` `app/usecase/search.ts`: 日付条件の inclusive/exclusive が仕様依存
- `リスク確認` `app/repository/searchRepository.ts`: 既存検索条件との後方互換に注意
- `深追い不要` `app/ui/search-form.tsx`: props 伝播中心で、ここ単体の深掘り優先度は低い

### 深く見る箇所
- `app/usecase/search.ts`: validation と query 組み立ての責務が混ざっていないか
- `app/repository/searchRepository.ts`: 条件追加で SQL や外部 API 条件が壊れないか

### 深追い不要と見てよい箇所
- `app/ui/types.ts`: 型追加の追従のみ
- `app/ui/search-form.tsx`: 表示項目追加が中心で意味変化は薄い

### 人判断が必要
- 「終了日を当日含むか」は実装だけでは決め切れない。仕様ソース確認が必要

### 根拠
- diff: `app/usecase/search.ts`, `app/repository/searchRepository.ts`, `app/ui/search-form.tsx`
- 参照: PR本文、既存の検索系 usecase 実装

### 不確実性
- local repo を見られていないため、repo ルール由来の読みは弱め
<!-- AI_PR_REVIEW_STOCKTAKE_END -->
```

## 文面づくりの指針

- 冒頭 2 行で「何の PR で、どこから読めばよいか」を伝える
- `推奨レビュー順` は 3 ステップ前後を目安にし、増やしすぎない
- `重点観点` は観点ラベルと対象 ref を同じ行に置く
- `深く見る箇所` は `real_review_targets` をそのまま並べるのでなく、なぜ見るかを短く添える
- `深追い不要の箇所` はレビュワーが安心して飛ばしてよい範囲だけを書く
- `根拠` は diff / spec / 類似実装の出どころだけに絞る
- `不確実性` は GitHub 上の情報だけで見た場合、spec 未確認、差分量が大きい、など判断精度に効くものだけ書く

## 避けること

- セクションを増やしすぎて、読む前に疲れるコメントにする
- 観点ラベルごとに長文解説を付ける
- diff のファイル一覧をそのまま大量に貼る
- `深追い不要` を大量に並べてノイズを増やす
- 「AIの結論」として approve / request changes 相当の文言を書く
