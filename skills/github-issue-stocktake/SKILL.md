---
name: github-issue-stocktake
description: GitHub Issueの棚卸しをAIが実行する。既存Issueを5件前後のバッチで調査し、分類（ステータス更新）、担当領域の切り分け、重複統合、クローズ判断、一次調査メモ（根拠・差分・方針）を作る。AIで直せるものは改修エージェントに渡す前提だが、改修PRの作成は別エージェントで行う。次のボールはPRのlabelで管理する。
---

# GitHub Issue Stocktake（AI Orchestration Spec）

## Goals
- 未整理Issueを分類し、根拠を構造化して残す。
- 仕様・画面項目定義・実装の突合によって、差分と結論を明文化する。
- AIで修正可能なIssueは、改修エージェントに渡せる入力を生成する。
- 人間が必要な作業（仕様確認・実機調査・意図補完）を明確に切り分ける。
- 何度回してもタイムラインを汚さない（コメント爆増を防ぐ）。

## Non-Goals
- ユーザーの明示指示がない限り、新規Issueの起票はしない。
- Stocktake AIはPRを作らない（改修は別エージェント）。
- 次のボール（担当）をIssueで管理しない（PRのlabelで管理）。

## Inputs
1. 対象リポジトリ・対象Issue番号（または範囲）
2. バッチサイズ（デフォルト5件）
3. 実行可能操作（Issue本文編集・ラベル付与・アサイン・クローズ・重複クローズ/リンク）
4. 参照先（仕様書・画面項目定義・必要時のみFigma・現行実装）

## Core Concept

### 1) Classification（排他的）
各Issueは必ず次のいずれか1つに分類する。

- `CLOSE_DONE`
  - 実装済み/解消済み/再現しない/仕様変更で吸収済み
- `CLOSE_DUPLICATE`
  - 重複。集約先Issueへ統合
- `AI_FIXABLE`
  - 再現手順が明確、原因箇所が概ね特定、仕様解釈不要、局所修正で対応可能
- `HUMAN_SPEC_REQUIRED`
  - 仕様根拠が不足、または仕様書/画面項目定義から仕様が読み取れない（該当チーム確認が必要）
- `HUMAN_REPRO_REQUIRED`
  - 実機調査/環境依存/外部要因でAIでは検証困難（QA/実機確認が必要）
- `HUMAN_CONTEXT_REQUIRED`
  - Issue記載が荒い/意図不明/再現手順不足で、起票者または関係者の補足が必要

### 2) Confidence
- AI判断には信頼度を付与する。
- `confidence`: 0.0〜1.0
- 原則: `AI_FIXABLE` は `confidence >= 0.75` を推奨（閾値は運用で調整）
- `confidence < 0.75` の `AI_FIXABLE` 判定は禁止し、`HUMAN_*` に分類する。

### 3) Evidence First
- 「直っている」「仕様」「吸収済み」等の結論は、現行実装・仕様根拠・差分で裏付けてから出す。

## No-Noise Policy（コメント爆増防止）

### AI_STOCKTAKEブロックをIssue本文に保持する
- タイムラインにコメントを積み重ねない。
- Issue本文末尾にAI専用ブロックを置き、以降はブロック内だけ更新する。
- 判定変更時（例: `HUMAN_* -> AI_FIXABLE`, `AI_FIXABLE -> CLOSE_*`）のみ、履歴可読性のために補足コメントを1件だけ許可する。

### ブロック仕様（必須）
Issue本文の末尾に以下が無ければ追加し、以降は中身を置換更新する。

```md
---

<!-- AI_STOCKTAKE_START -->
## AI_STOCKTAKE

(ここはAIが更新します)

<!-- AI_STOCKTAKE_END -->
```

## Body Update Safety Rules
- 本文更新は `<!-- AI_STOCKTAKE_START -->` から `<!-- AI_STOCKTAKE_END -->` までの区間のみを置換する。
- 開始マーカー/終了マーカーが両方無い場合のみ、本文末尾へ新規ブロックを追記する。
- 開始または終了のどちらか一方だけ存在する壊れた本文は、更新を中止して手動確認に回す。
- `AI_STOCKTAKE` ブロック以外の本文は変更しない。
- `HUMAN_*` はPR未作成のため、Issue本文 `Human Action` を唯一の次アクション管理元とする。

## Batch Workflow

### Step 1. Issue状態を取得する
- `gh issue view <番号> --comments` で本文・履歴・最新判断を確認する。
- 未確定事項と既存合意を分離してメモする。

### Step 2. 根拠を調査する
- 実装: `rg` を起点に該当コードへ到達し、関連箇所を読む。
- 仕様: 仕様書と画面項目定義を確認し、実装との差分を明文化する。
- UI仕様が曖昧な場合のみFigmaを追加確認する。

### Step 3. 分類を決める
- `CLOSE_*` / `AI_FIXABLE` / `HUMAN_*` のいずれかを1つ選ぶ。
- 必ず `confidence` と根拠をセットで残す。

### Step 4. 反映する
- Issue本文の `AI_STOCKTAKE` ブロックを更新する。
- 必要ならラベル・アサインを更新する。
- クローズ時は本文に根拠が残っていることを確認してクローズする。

### Step 5. バッチ報告する
- 実施Issue、分類、実行アクションを列挙する。
- 保留Issueは「不足根拠」と「次アクション（人間がやるべき内容）」を1行で示す。

## Decision Rules
- 重複クローズ時は必ず集約先Issue番号を明記する（例: `#123`）。
- 「直っている」判定は現行実装で根拠を確認してから行う。
- 「仕様変更でクローズ」は変更後仕様の根拠（参照URL）を添える。
- 仕様書/画面項目定義を参照した場合は、AI_STOCKTAKE内にNotionページURLを必ず明記する。
- 根拠不足時は無理にクローズせず、調査結果と不足点を残す。

## Label Strategy（推奨）

### Issueラベル（分類）
分類はダッシュボード化のためIssueラベルに反映してよい。

- `クローズ可（解消）`
- `クローズ可（重複）`
- `AI改修可能`
- `要仕様確認`
- `要再現確認`
- `要起票者確認`

Classification とラベルの対応:
- `CLOSE_DONE` -> `クローズ可（解消）`
- `CLOSE_DUPLICATE` -> `クローズ可（重複）`
- `AI_FIXABLE` -> `AI改修可能`
- `HUMAN_SPEC_REQUIRED` -> `要仕様確認`
- `HUMAN_REPRO_REQUIRED` -> `要再現確認`
- `HUMAN_CONTEXT_REQUIRED` -> `要起票者確認`

### 排他運用（推奨）
- Stocktake実行時、上記6つの分類ラベルのうち既存ラベルを削除し、1つだけ付与する。

### PRラベル（次のボール）
- 次のボール（担当/状態）はPRのlabelで管理する。
- Stocktake AIはPRを作らない。

## AI_STOCKTAKE ブロックフォーマット（Mandatory）
更新する本文はGFMで構造化し、最低限「見出し + 箇条書き」を含める。

```md
<!-- AI_STOCKTAKE_START -->
## AI_STOCKTAKE

### Classification
- AI_FIXABLE

### Confidence
- 0.84

### Summary
- 事象: ...
- 結論: ...

### Evidence
- 再現結果: ...
- 実装確認: `app/foo.ts:120` ...
- 仕様確認: 仕様書 <Notion URL> / 画面項目定義 <Notion URL>（必要ならFigma <URL>）

### Diff / Gap
- 仕様と実装の差分: ...

### Fix Strategy（AI_FIXABLEのとき）
- 方針: ...
- 影響範囲: ...

### Human Action（HUMAN_* のとき）
- 依頼先: ...
- 確認事項: ...

### Fix Agent Input（AI_FIXABLEのとき）
- suspected_root_cause: ...
- reproduction_steps:
  - ...
- expected_behavior:
  - ...
- affected_files:
  - ...
- test_plan:
  - ...

<!-- AI_STOCKTAKE_END -->
```

## Command Patterns
```bash
# 状態確認
gh issue view <番号> --comments

# 本文取得
gh issue view <番号> --json body -q .body > /tmp/issue-<番号>-body.md

# AI_STOCKTAKEブロックを作成
cat > /tmp/issue-<番号>-stocktake.md <<'__BLOCK_EOF__'
<!-- AI_STOCKTAKE_START -->
## AI_STOCKTAKE
...
<!-- AI_STOCKTAKE_END -->
__BLOCK_EOF__

# 本文更新（安全にブロックのみ更新）
skills/github-issue-stocktake/scripts/upsert_ai_stocktake_block.sh \
  --body-file /tmp/issue-<番号>-body.md \
  --block-file /tmp/issue-<番号>-stocktake.md \
  --out-file /tmp/issue-<番号>-new-body.md

# 反映
gh issue edit <番号> --body-file /tmp/issue-<番号>-new-body.md

# ラベル排他更新（例）
gh issue edit <番号> \
  --remove-label 'クローズ可（解消）' --remove-label 'クローズ可（重複）' \
  --remove-label 'AI改修可能' --remove-label '要仕様確認' \
  --remove-label '要再現確認' --remove-label '要起票者確認'

gh issue edit <番号> --add-label 'AI改修可能'

# アサイン（必要時）
gh issue edit <番号> --add-assignee <user>

# クローズ
gh issue close <番号>
```

## Output Contract（バッチごと）
バッチごとに次を返す。
1. 対応Issue番号とClassification
2. 実行アクション（ラベル/アサイン/クローズ等）
3. `HUMAN_*` の不足根拠と次アクション
4. 次バッチ候補（5件）
