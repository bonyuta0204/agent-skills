# Repository Guidelines

## Project Structure & Module Organization

- `skills/`: Skill packages. Each skill lives in `skills/<skill-name>/` and is defined by a `SKILL.md` file.
- `README.md`: Overview and usage examples for contributors.
- `Makefile`: Helper commands for linking skills into the local Codex directory.
- No source code or test directories exist yet; this repo is documentation-first.

## Build, Test, and Development Commands

- `make list`: Lists available skills by directory name.
- `make link`: Links all skills into `~/.codex/skills/` (overwrites existing targets).
- `make link SKILL=create-design-doc`: Links a single skill.
- `make link-all`: Explicit alias for linking all skills.
- `make unlink`: Removes linked skills from `~/.codex/skills/`.
- `make help`: Prints available targets and variables.

## Coding Style & Naming Conventions

- Markdown is the primary format. Keep instructions short and actionable.
- Skill directories use kebab-case (`create-design-doc`).
- `SKILL.md` frontmatter must include `name` and `description`.
- Use ASCII unless a skill requires non-ASCII content.

## Testing Guidelines

- No automated tests are defined.
- If you add scripts, include a lightweight verification command in `Makefile` or the README.

## Commit & Pull Request Guidelines

- Use concise, imperative commit messages (e.g., “Add link-all target for skill symlinks”).
- PRs should include a short summary, the affected skill paths, and any commands used for verification.

## Agent-Specific Instructions

- Skills are the source of truth. Do not modify linked copies under `~/.codex/skills/` directly.
- Prefer updating `README.md` when adding or changing skills so contributors can discover them quickly.

## Session Learnings

### repo-specific
- `skills/` に新しい skill を追加したら、同じ変更セットで `README.md` の Skill catalog を必ず更新する。

### general/reusable
- `~/.codex/skills` で個別管理していた skill を repo 管理に移すときは、(1) skill ディレクトリを `skills/<name>/` にコピー、(2) `make link SKILL=<name>` でリンクを切り替え、(3) `~/.codex/skills/<name>` が repo 配下へのシンボリックリンクになっていることを確認する。
