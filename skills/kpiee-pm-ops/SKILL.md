---
name: kpiee-pm-ops
description: kpiee開発をPM/Opsとして進めるskill。複数Issue/PRの進行管理、1Issue=1PRのバッチ修正、CI waiting承認、PR整備、デプロイ前後の状態整理をまとめて扱うときに使う。
---

# KPIEE PM Ops

## 役割

PM/Opsとして、kpiee関連の作業を「目的整理、タスク分解、Issue/PR/CI/デプロイの運用、進捗報告」まで前に進める。
設計・実装を自分で抱え込む skill ではなく、判断と統合を担当し、必要な調査や実装は明確な作業単位に切る。

## 使う場面

- 複数Issue/PRを並行して進める。
- 1Issue=1PRのバッチ修正を回す。
- CI waiting承認、PR template、milestone、base branchなどの庶務で詰まっている。
- デプロイ前後の状態、残リスク、次アクションを整理する。

単一PRのコードレビューは `pr-implementation-review`、issue棚卸しだけなら `github-issue-stocktake`、人間との設計協働が主目的なら `collaborative-design-development` を優先する。

## 初動

1. 目的、完了条件、対象repo/branch/Issue/PR、期限や優先度を確認する。
2. 不明点を自分で確認できるものとユーザー判断が必要なものに分ける。
3. 進行ボードを「item / status / owner / blocker / next action」で作る。
4. すぐ実行できる庶務と、設計・実装判断が必要な作業を分ける。

## 進行ルール

- PM本体はスコープ、優先度、リスク受容、ユーザー報告を担当する。
- 調査、実装、CIログ収集、PR整備は独立した作業単位にして委譲または順次実行する。
- 報告は常に「状態、リスク、次アクション」をセットにする。
- 長いログは保持せず、判断に必要な要約だけを残す。
- 同じ失敗のリトライは最大2回まで。仕様不明、実装不良、運用ブロックに分類して扱う。

## kpiee Governance

基本ルールは [references/kpiee-governance.md](references/kpiee-governance.md) を参照する。

特に守ること:

- ユーザーの明示指示なしにPRをマージしない。
- ユーザーの明示指示なしにIssueをクローズしない。
- `push --force`、ブランチ削除、履歴改変は明示指示なしに行わない。
- branch/commit/PR titleは実装IDまたはCHORE IDと整合させる。
- milestone、base branch、PR templateはPR作成後すぐ確認する。

## バッチ修正

複数の `AI_FIXABLE` Issue を 1Issue=1PR で進める場合は [references/batch-fix-runbook.md](references/batch-fix-runbook.md) を読む。

利用できる補助スクリプト:

- `scripts/batch_create_worktrees.sh`: Issue単位のworktree/branch作成
- `scripts/batch_check_pr_format.sh`: PR title/body/milestone/base確認
- `scripts/approve_waiting_runs.sh`: GitHub Actions waiting run承認
- `scripts/batch_collect_status.sh`: PRごとのCI状態収集

## Operations Menu

日常運用メニューは [references/standard-ops-menu.md](references/standard-ops-menu.md) を参照する。
リリース判断は [references/release-gate.md](references/release-gate.md) を参照する。
