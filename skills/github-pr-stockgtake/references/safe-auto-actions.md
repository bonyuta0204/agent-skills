# 安全に実行できる対応

## 実行してよい対応

- lint failure の再現と局所修正
- 単体テスト failure のうち、原因が局所的で scope が明確なものの修正
- review comment のうち、仕様判断を伴わない軽微修正
- `gh pr checks` / `gh run` の再確認
- pending check の rerun
- `dx-kpiee` の `test` environment 承認待ち解除
- 自分の PR への補足コメント追加
- レビュワーへの再依頼コメントの投稿

## 実行してはいけない対応

- close / merge
- 複雑な conflict 解消
- PR の主目的変更
- レビュワーの意図を推測した大きい仕様変更
- 他人のコメント編集

## 実行前チェック

1. その対応が local で再現可能か確認する
2. 影響ファイルが局所的か確認する
3. scope creep していないか確認する
4. repo 固有ルールに反していないか確認する
5. 危険なら `auto_action_blocked` で止める

## dx-kpiee の pending deployment

`dx-kpiee` で checks が `WAITING` の場合、`test` environment 保護で止まっていることがある。  
この repo では `gh` と Actions API を使った承認解除は安全に実行できる対応として扱ってよい。
