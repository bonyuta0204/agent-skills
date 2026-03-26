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
| [`dx-kpiee-go-arch-review`](skills/dx-kpiee-go-arch-review/SKILL.md) | dx-kpiee の `backend/go` 変更を DDD / Clean Architecture / Onion Architecture の観点に絞ってレビューする。 |
| [`github-create-pr`](skills/github-create-pr/SKILL.md) | GitHub の Pull Request をレビューア向け説明で作成・更新し、repo 固有の preflight、template、milestone も扱う。 |
| [`github-issue-stocktake`](skills/github-issue-stocktake/SKILL.md) | PM-style GitHub issue stocktake/triage with worker-based primary investigation, PM-owned duplicate handling, resumable state tracking, and controlled `AI_STOCKTAKE` body/label updates. |
| [`github-pr-review-stocktake`](skills/github-pr-review-stocktake/SKILL.md) | 自分に assign / review request された PR を棚卸しし、レビュー順・pass-through・重点論点を整理した sticky review comment を更新する。 |
| [`kpiee-bastion-ops`](skills/kpiee-bastion-ops/SKILL.md) | kpiee の non-prod 環境で、共有 bastion 優先の踏み台ルーティングに従って日常的な確認作業を安全に進める。 |
| [`kpiee-pm-ops`](skills/kpiee-pm-ops/SKILL.md) | PM+Ops orchestrator for kpiee delivery: architecture-aware task decomposition, issue/PR operations, CI/deploy execution, and release reporting via sub-agents. |
| [`kpiee-batch-fix-pm`](skills/kpiee-batch-fix-pm/SKILL.md) | Run PM-style batch fixes across multiple AI-fixable issues in kpiee repositories with worktree/sub-agent orchestration and CI governance handling. |
| [`kpiee-stg-log-db-check`](skills/kpiee-stg-log-db-check/SKILL.md) | Investigate kpiee non-production environments (`it`, `stg`, `stg01`, `stg02`) with reusable logs/ECS/DB/Snowflake tools, bastion-hosted env start/stop guidance, and DB route references including atlas-core tenant DB lookup. |
| [`pr-architecture-review`](skills/pr-architecture-review/SKILL.md) | GitHub PR をローカル checkout して、コードの構成・style だけでなく PR本文の説明品質までレビューする。 |
| [`review-design-doc`](skills/review-design-doc/SKILL.md) | GitHub PR 上の kpiee-designs 設計書を、文書品質と設計妥当性の 2 ステップでレビューし、日本語の inline review と総評を返す。 |

Skill-specific verification example:

```bash
./skills/create-mermaid-diagram/scripts/check_mermaid.sh --strict path/to/diagram.mmd
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
