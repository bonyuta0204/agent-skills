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
| [`review-design-doc`](skills/review-design-doc/SKILL.md) | Review kpiee-designs design docs in GitHub pull requests. |

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
