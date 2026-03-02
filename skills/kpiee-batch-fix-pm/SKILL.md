---
name: kpiee-batch-fix-pm
description: "AI_FIXABLEなIssueをバッチで修正するPMエージェント。Issue単位のworktree作成、Worker割り当て、PRフォーマット検証、CI承認までをオーケストレーションする。"
---

# KPIEE Batch Fix PM

## Overview

複数の `AI_FIXABLE` Issueを 1Issue=1PR で一括修正するためのPMスキル。
キュー設計、Issue単位の実行レーン、PRガバナンス、CI承認操作を統括する。

## When To Use

- 「AI_FIXABLEをまとめて直す」「PMとして回したい」「1Issue 1PRで進めたい」
- worktree + sub-agent の並列実行で厳格なPR規約を守る必要がある
- protected environment による `waiting` 状態の GitHub Actions を処理する必要がある

このスキルを使わない場面:
- 単一Issueを直接実装するだけのとき
- 棚卸し・分類のみのとき（`github-issue-stocktake` を使う）

## Inputs

### 必須

- `repo_path`: ローカルリポジトリの絶対パス
- `repo_slug`: `owner/repo`
- `implementation_id`: 例 `IMP_KP001168`
- `base_branch`: 全Issue共通のベースブランチ
- `issues`: 実行対象のIssue番号（`AI_FIXABLE` のサブセット）

### オプション

- `classification_map`: Issue単位の分類ステータス
- `assignment_strategy`: `user_defined` / `round_robin` / `by_scope`
- `assignment_map`: ユーザーが明示するIssue→エージェント割り当て
- `max_workers`: default `4`（同時起動するWorker数）
- `ci_approval`: `auto`（default） / `manual`
- `expected_milestone`: 省略時は既存PRやスプリントルールから推定

## PM Communication Rules

### PMの役割

PMの最も重要な責務は **ユーザーとのコミュニケーションハブ** であること。
PMは自律的にWorkerを回す自動化ツールではなく、ユーザーと協力してバッチ修正を進めるパートナーとして振る舞う。判断に必要な情報が足りなければ自分で抱え込まず、ユーザーに聞きに行く。

### ユーザーに相談すべき場面

1. **修正方針が不明確**: AI_STOCKTAKEの記述だけでは修正アプローチを決められないとき、ユーザーに方針を相談する。
2. **Issue間のコンフリクト**: 複数Workerの修正が同じファイルに競合しそうなとき、修正順序や統合方針を相談する。
3. **CI失敗の切り分け**: 失敗が今回の修正起因か既存問題か判断できないとき、ユーザーに確認する。
4. **スコープの拡大/縮小**: 修正中に関連バグや追加修正の必要性に気づいたとき、スコープ変更を相談する。
5. **ガバナンス判断**: milestone・base branch・PR構成など、プロジェクトルールに関する判断で迷うとき。

### 聞き方のガイドライン

- 具体的に聞く:「#123 の修正で A と B の2案があります。Aは影響範囲が狭い、Bは根本対処。どちらがいいですか？」
- 質問は1回のメッセージにまとめる。小出しにしない。
- ユーザーの回答を得たら、決定事項を明示してから作業に反映する。

### 進捗共有

- 要所で短く伝える: Worker起動数、PR作成済み件数、CI待ち件数、ブロッカー。
- 全件順調なら逐一報告しない。問題やユーザー判断が必要な場面で伝える。

## State File（永続化ボード）

PMはコンテキスト圧縮や割り込みが起きてもタスクを漏らさないように、進捗をファイルに永続化する。

### 保存場所

```
${WORKTREE_ROOT}/${implementation_id}-state.json
```

デフォルト: `~/.codex/worktrees/<implementation_id>-state.json`

worktreeと同じ親ディレクトリに置く（gitリポジトリの外なので誤コミットしない）。

### フォーマット

```json
{
  "implementation_id": "IMP_KP001168",
  "repo_slug": "owner/repo",
  "base_branch": "feat/IMP_KP001168_visiblity_master",
  "issues": {
    "11971": {
      "status": "done",
      "branch": "feat/IMP_KP001168_issue11971",
      "worktree": "~/.codex/worktrees/IMP_KP001168-11971/dx-kpiee",
      "pr": 12371,
      "ci_status": "pass",
      "failure_reason": null
    },
    "11978": {
      "status": "in_flight",
      "branch": "feat/IMP_KP001168_issue11978",
      "worktree": "~/.codex/worktrees/IMP_KP001168-11978/dx-kpiee",
      "pr": null,
      "ci_status": null,
      "failure_reason": null
    },
    "11979": {
      "status": "queued",
      "branch": null,
      "worktree": null,
      "pr": null,
      "ci_status": null,
      "failure_reason": null
    }
  }
}
```

### ステータス遷移

`queued` → `in_flight` → `pr_created` → `ci_waiting` → `done` / `failed`

### 更新ルール

- **状態変更の直後**にファイルを書き出す（worktree作成後、PR作成後、CI完了後など）。
- PMは各ワークフローステップの冒頭でこのファイルを読み直す。
- コンテキスト圧縮・割り込みからの復帰時は、このファイルから現在地を把握して途中再開する。

## Workflow

### 0) Resume Check

**全ワークフローの最初に実行する。**

1. `${WORKTREE_ROOT}/${implementation_id}-state.json` が存在するか確認。
2. 存在すれば読み込み、各Issueのステータスに応じて途中から再開する。
3. 存在しなければ新規として 1) Intake へ進む。

### 1) Intake

1. 対象Issueを確認。`AI_FIXABLE` のみを対象とする（ユーザーが明示的に他の分類を含める場合を除く）。
2. 既存のopen PRと重複がないか検出する。
3. ステートファイルを作成し、全Issueを `queued` で初期化して書き出す。

### 2) Assignment

1. ユーザーが割り当てを指定していればそのまま使う。
2. 指定がなければデフォルト戦略を選択:
   - `round_robin`: レーン数で均等分配
   - レーン数1の場合は逐次実行にフォールバック
3. Worker起動後の割り当て変更は、ユーザーから依頼された場合のみ。

### 3) Execution Lane作成

1. `base_branch` から Issue単位に1 worktreeを作成する。
2. ブランチ命名はkpiee規約に従う:
   - `feat/<実装ID>_...`: バグ修正トラック
   - `chore/<内部改善ID>_...`: CHORE トラック
3. `scripts/create_worktrees.sh` で一括作成。
4. ステートファイルに `branch` / `worktree` パスを記録。

### 4) Worker起動

1. Issue単位にWorkerを起動。ステータスを `in_flight` に更新して書き出す。
2. Workerへの成果物要件:
   - 原因特定
   - 最小限の修正
   - 焦点を絞ったテスト
   - `[ID]` プレフィックス付きコミット
   - push
   - PR作成
3. Worker完了後、PR番号を記録してステータスを `pr_created` に更新。

### Worker失敗時のリトライ・退避

1. Workerがエラー終了（コンパイル不可・テスト全滅など）した場合、PMは原因を切り分ける:
   - **修正方針の問題**: ユーザーに方針を相談し、確定後に1回だけ再試行。
   - **環境・依存の問題**: ユーザーに報告し、PMでは対処しない。
2. 再試行でも失敗したIssueはステータスを `failed` にし、`failure_reason` をステートファイルに記録。
3. `failed` Issueは最終レポートで一覧化し、ユーザーと次のアクションを相談する。

### 5) PR Governance Gate

作成・更新された各PRに対して以下を検証:

1. タイトルプレフィックス: `[<implementation_id>] ...`
2. milestoneが設定されていること
3. テンプレート見出しとIssueリンクが含まれていること
4. base branchが正しいこと

`scripts/check_pr_format.sh` で検証。
PRボディのテンプレートは [references/pr-template.md](references/pr-template.md) を参照。

### 6) CI Governance Gate

1. 各PRのhead commitで `waiting` 状態のrunを検出。ステータスを `ci_waiting` に更新。
2. `ci_approval=auto` の場合、`test` 環境の `pending_deployments` を承認。
3. 全checkが終了状態になるまで再確認。
4. 失敗が残る場合は種別を切り分ける:
   - フォーマット/型チェック失敗 → レーンブランチで修正
   - ガバナンス失敗（milestone/テンプレート/タイトル） → PRを修正
   - 外部プロバイダ → URLのみ報告
5. 結果に応じてステータスを `done` または `failed` に更新して書き出す。

`scripts/approve_waiting_runs.sh` / `scripts/collect_status.sh` を使用。

### 7) 最終レポート

1. Issue → PR マッピング
2. CIステータスサマリ
3. 残存ブロッカー
4. 推奨マージ順序（リスクの低いものから）
5. `failed` Issueの一覧と失敗理由

## Execution Rules

- レーン内の無関係なファイルを編集しない。
- ユーザーが明示的に依頼しない限り、複数Issueを1PRにまとめない。
- ユーザーの割り当て指定を自動戦略より優先する。
- 対話的なgitコマンドを使わない。
- **各ステップの状態変更後にステートファイルを書き出す。省略しない。**

## Bundled Resources

### references/

- [references/kpiee-rules.md](references/kpiee-rules.md): ブランチ/コミット/CIガバナンスルール
- [references/pr-template.md](references/pr-template.md): PRボディテンプレート

### scripts/

- `scripts/create_worktrees.sh`: worktree一括作成
- `scripts/check_pr_format.sh`: PRフォーマット検証
- `scripts/approve_waiting_runs.sh`: waiting状態のCI run承認
- `scripts/collect_status.sh`: PR単位のCIステータス収集

## Quick Start

```bash
# 1) worktreeレーン作成
scripts/create_worktrees.sh \
  --repo /path/to/repo \
  --base feat/IMP_KP001168_visiblity_master \
  --id IMP_KP001168 \
  --issues 11971,11978,11979,11981

# 2) PRフォーマット検証
scripts/check_pr_format.sh \
  --repo f-scratch/dx-kpiee \
  --pr 12371 \
  --id IMP_KP001168

# 3) waiting状態のCI run承認
scripts/approve_waiting_runs.sh \
  --repo f-scratch/dx-kpiee \
  --commit <HEAD_SHA>
```
