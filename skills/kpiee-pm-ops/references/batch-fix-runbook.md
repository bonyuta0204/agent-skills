# Batch Fix Runbook

複数の `AI_FIXABLE` Issue を 1Issue=1PR で一括修正する時だけ読む。

## Inputs

- `repo_path`: 対象repoの絶対パス
- `repo_slug`: `owner/repo`
- `implementation_id`: `IMP_KP001168` や `CHORE0333`
- `base_branch`: 全Issue共通の分岐元
- `issues`: 対象Issue番号
- 任意: `max_workers`, `expected_milestone`, `ci_approval`

## State File

コンテキスト圧縮や割り込みに備えて、repo外に状態を残す。

```json
{
  "implementation_id": "IMP_KP001168",
  "repo_slug": "owner/repo",
  "base_branch": "feat/IMP_KP001168_base",
  "issues": {
    "11971": {
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

既定の置き場所は `~/.codex/worktrees/<implementation_id>-state.json`。
状態遷移は `queued -> in_flight -> pr_created -> ci_waiting -> done / failed`。
worktree作成、PR作成、CI完了など、状態が変わった直後に更新する。

## Workflow

1. 既存state fileがあれば読み、途中から再開する。
2. 対象Issueが `AI_FIXABLE` で、既存open PRと重複しないことを確認する。
3. Issue単位にworktreeを作る。
4. 各IssueのWorkerまたは実行レーンに、原因特定、最小修正、焦点を絞ったテスト、commit、push、PR作成を要求する。
5. PR title/body/milestone/base branchを確認する。
6. waiting状態のGitHub Actionsがあれば承認し、完了まで監視する。
7. Issue -> PR、CI結果、残ブロッカー、推奨マージ順を報告する。

## Worker Contract

- 1Issueだけを扱う。
- 無関係なファイルを編集しない。
- 似た実装や仕様を確認してから直す。
- commit messageは `[ID] 説明` 形式にする。
- ユーザーが明示しない限り、複数Issueを1PRにまとめない。

## Commands

```bash
scripts/batch_create_worktrees.sh \
  --repo /path/to/repo \
  --base feat/IMP_KP001168_base \
  --id IMP_KP001168 \
  --issues 11971,11978
```

```bash
scripts/batch_check_pr_format.sh \
  --repo f-scratch/dx-kpiee \
  --pr 12371 \
  --id IMP_KP001168
```

```bash
scripts/approve_waiting_runs.sh \
  --repo f-scratch/dx-kpiee \
  --commit <HEAD_SHA>
```

```bash
scripts/batch_collect_status.sh \
  --repo f-scratch/dx-kpiee \
  --prs 12371,12372
```

## Escalation

ユーザーに相談するのは、修正方針が複数ある、Issue間で同じファイルに衝突しそう、CI失敗が今回起因か判断できない、スコープ変更が必要、milestone/base branchなどのプロジェクト判断が曖昧な時。
