# 報告形式

## 目的

- 情報量を増やしすぎず、ひと目で優先度と次アクションが分かること
- Slack / GitHub コメント / Codex の最終返答のどれでも崩れにくい Markdown を使うこと
- まず全体像、次に個別PR、最後に補足という順で読めること

## 形式ルール

- 基本は通常の Markdown 見出しと箇条書きだけを使う
- table は使わない
- raw JSON や enum の列挙はしない
- 空の section は出さない
- 1 PR あたりの基本情報は `概要 / 状況 / 次` の 3 行を軸にする
- `AI対応` や `補足` は必要な PR にだけ足す
- status は生 enum より先に日本語で表現する
  - 例: `checks失敗`, `レビュー待ち`, `作成者修正待ち`, `CI待ち`, `競合あり`
- 補足情報は `GitHub 上の情報だけでの判定`, `confidence が低い理由`, `人判断が必要な論点` など、本当に判断に効くものだけ残す

## 推奨構成

```md
## PR棚卸し結果

- 対象: 4件
- 今すぐ触る: 2件
- AI対応: 1件実施

### 今すぐ触るPR
1. [#123 PRタイトル](https://github.com/owner/repo/pull/123)
   - checks失敗。lint 修正を入れて push するのが最短
2. [#118 PRタイトル](https://github.com/owner/repo/pull/118)
   - レビュワーからの修正依頼あり。対応後に再レビュー依頼が必要

### PRごとの状況
#### [#123 PRタイトル](https://github.com/owner/repo/pull/123)
- 概要: 管理画面の検索条件を追加する PR
- 状況: `pnpm lint` が failure で停止
- 次: lint 修正を入れて push する
- AI対応: `fix_lint_and_push` は安全に実行できる対応の候補

#### [#118 PRタイトル](https://github.com/owner/repo/pull/118)
- 概要: API のレスポンス整形を整理する PR
- 状況: requested changes が残っていて作成者側の返答待ち
- 次: 指摘 2 件に対応して再レビューを依頼する

### AI実施結果
- [#125 PRタイトル](https://github.com/owner/repo/pull/125): pending deployment を承認して CI を再開した

### 人判断が必要
- [#110 PRタイトル](https://github.com/owner/repo/pull/110): stale。進めるか close するかの判断が必要
```

## 文面づくりの指針

- 対象 PR が 1 件だけなら `今すぐ触るPR` を省略してよい
- `AI実施結果` は実施が 0 件なら出さない
- `人判断が必要` は該当 PR があるときだけ出す
- `PRごとの状況` では、優先度順に並べる
- PR タイトルは必ずリンク付きで書く
- `概要` は 1 文、`状況` は観測事実、`次` は作成者の 1 手に絞る

## 避けること

- PR ごとに長い経緯や調査ログを貼る
- checks 名や review comment を未整理のまま大量に列挙する
- `status_category=failing_checks` のように enum を説明なしで出す
- table に詰め込み、モバイルで読みにくくする
- 補足がない PR にも機械的に `補足: なし` を書く
