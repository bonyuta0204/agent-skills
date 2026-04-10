# agent-skills

Skills repository for managing https://agentskills.io/home and local Codex skills.

## About

This repo is the source of truth for reusable agent skills. Each skill is a
small, task-focused package of instructions (and optional scripts/assets) that
an agent can load to perform a specific workflow.

## Quick start

Clone this repo and link the skills you want into your Codex skills directory.

```bash
make link
```

Link all skills explicitly:

```bash
make link-all
```

Link a single skill:

```bash
make link SKILL=create-design-doc
```

Use a custom Codex home:

```bash
make link CODEX_HOME=~/.my-codex
```

Show all commands:

```bash
make help
```

Note: `make link` and `make unlink` will overwrite any existing directories or files
at the target path.

To unlink:

```bash
make unlink
```

Unlink a single skill:

```bash
make unlink SKILL=create-design-doc
```

## How to use

- Each skill lives under `skills/<skill-name>/`.
- A skill is defined by `SKILL.md` with frontmatter:
  - `name`: skill name
  - `description`: short, single-line description
- Codex loads skills from `~/.codex/skills/`.
- Use symlinks so this repo stays the source of truth.

## Skill catalog

| Skill | Description |
| --- | --- |
| [`create-design-doc`](skills/create-design-doc/SKILL.md) | Create kpiee design docs (basic or detail) in kpiee-designs using repo templates. |
| [`create-mermaid-diagram`](skills/create-mermaid-diagram/SKILL.md) | Mermaid 図を壊れにくく作成・修正し、render 検証と syntax/style のチェックまで行う。 |
| [`code-architecture-review`](skills/code-architecture-review/SKILL.md) | 実装の細部よりも責務配置・依存方向・境界設計に注目して、コードや PR をアーキテクチャ観点でレビューする。 |
| [`github-create-pr`](skills/github-create-pr/SKILL.md) | GitHub の Pull Request をレビューア向け説明で作成・更新し、repo 固有の preflight、template、milestone も扱う。 |
| [`github-issue-stocktake`](skills/github-issue-stocktake/SKILL.md) | PM-style GitHub issue stocktake/triage with worker-based primary investigation, PM-owned duplicate handling, resumable state tracking, and controlled `AI_STOCKTAKE` body/label updates. |
| [`github-pr-stockgtake`](skills/github-pr-stockgtake/SKILL.md) | 自分が author の open PR を棚卸しし、概要・状況・ネクストアクション整理と、安全な AI 自動対応まで扱う。 |
| [`github-pr-review-stocktake`](skills/github-pr-review-stocktake/SKILL.md) | 自分に assign / review request された PR を棚卸しし、レビュー順・pass-through・重点論点を整理した sticky review comment を更新する。 |
| [`kpiee-bastion-ops`](skills/kpiee-bastion-ops/SKILL.md) | kpiee の non-prod 環境で、共有 bastion 優先の踏み台ルーティングに従って日常的な確認作業を安全に進め、`it/stg/stg01/stg02` の起動 wrapper も提供する。 |
| [`kpiee-local-smoke-check`](skills/kpiee-local-smoke-check/SKILL.md) | kpiee の localhost 動作確認で、repo の役割、起動方法、log、認証付き API アクセス、DB 前提、HTTP 最小再現を一貫した runbook として扱う toolkit。 |
| [`kpiee-playwright-auth`](skills/kpiee-playwright-auth/SKILL.md) | kpiee を playwright-cli で調査・自動化するときの認証を、human login + state-save/load で安定化する。 |
| [`kpiee-pm-ops`](skills/kpiee-pm-ops/SKILL.md) | PM+Ops orchestrator for kpiee delivery: architecture-aware task decomposition, issue/PR operations, CI/deploy execution, and release reporting via sub-agents. |
| [`kpiee-batch-fix-pm`](skills/kpiee-batch-fix-pm/SKILL.md) | Run PM-style batch fixes across multiple AI-fixable issues in kpiee repositories with worktree/sub-agent orchestration and CI governance handling. |
| [`kpiee-stg-log-db-check`](skills/kpiee-stg-log-db-check/SKILL.md) | Investigate kpiee non-production environments (`it`, `stg`, `stg01`, `stg02`) with reusable logs/ECS/DB/Snowflake tools, bastion-hosted env start/stop guidance, and DB route references including atlas-core tenant DB lookup. |
| [`pr-implementation-review`](skills/pr-implementation-review/SKILL.md) | GitHub PR をローカル checkout して、コードの構成・style・PR本文の説明品質まで含めて広くレビューする。 |
| [`review-design-doc`](skills/review-design-doc/SKILL.md) | GitHub PR 上の kpiee-designs 設計書を、文書品質と設計妥当性の 2 ステップでレビューし、日本語の inline review と総評を返す。 |
| [`slack-ng-to-issue`](skills/slack-ng-to-issue/SKILL.md) | Slack `#kpiee_ng報告` の NG レポートを NG一覧ID 指定で取得し、GitHub Issue として起票する。 |

## Review skills guide

レビュー系 skill は似て見えるが、見る対象と返す成果物が違う。

| Skill | 主対象 | 向いている依頼 | 主なアウトプット |
| --- | --- | --- | --- |
| [`github-pr-review-stocktake`](skills/github-pr-review-stocktake/SKILL.md) | 複数 PR のレビュー待ちキュー | 自分の assigned / review requested PR を棚卸ししたい | PR ごとの sticky なレビュー導線コメント |
| [`github-pr-stockgtake`](skills/github-pr-stockgtake/SKILL.md) | 複数 PR の author 側キュー | 自分が author の open PR を棚卸しし、AI で進められるものは進めたい | PR ごとの概要・状況・next action と safe auto action |
| [`pr-implementation-review`](skills/pr-implementation-review/SKILL.md) | 単一 PR の実装 | 1 本の PR をローカル checkout して丁寧にレビューしたい | 実装・構成・PR 本文に対するレビュー指摘 |
| [`code-architecture-review`](skills/code-architecture-review/SKILL.md) | 単一 PR や差分の構造 | コードレベルの細部より、責務配置・境界・依存方向を見たい | 実装アーキテクチャ観点のレビュー指摘 |
| [`review-design-doc`](skills/review-design-doc/SKILL.md) | `kpiee-designs` の設計書 PR | 設計書の文書品質と設計妥当性を見たい | 設計書向け inline review と総評 |

選び方の目安:

- まずレビュー待ちの PR 群を整理したいなら `github-pr-review-stocktake`
- 自分が author の PR 群を整理して、AI で進められるものを進めたいなら `github-pr-stockgtake`
- 単一 PR の実装を広めに見るなら `pr-implementation-review`
- コードレベルの細部より責務配置や境界を見たいなら `code-architecture-review`
- 実装ではなく設計書をレビューするなら `review-design-doc`

Skill-specific verification example:

```bash
./skills/create-mermaid-diagram/scripts/check_mermaid.sh --strict path/to/diagram.mmd
./skills/kpiee-bastion-ops/scripts/start_env_via_bastion_ssm.sh --help
```

## Add a new skill

1. Create `skills/<skill-name>/SKILL.md`.
2. Add YAML frontmatter with `name` and `description`.
3. Write the skill instructions in Markdown.
4. Update the catalog table above.
5. Symlink it to `~/.codex/skills/<skill-name>`.

Example template:

```markdown
---
name: my-skill-name
description: A clear description of what this skill does and when to use it.
---

# My Skill Name

Write instructions here.
```

## Notes

- Keep skill names kebab-case.
- Prefer short, task-focused skills.
- If a skill needs templates or scripts, keep them under the skill directory.
