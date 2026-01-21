---
name: review-design-doc
description: Review kpiee-designs design docs in GitHub pull requests. Use when asked to review a PR like "https://github.com/f-scratch/kpiee-designs/pull/301", "設計書レビューして", or "PRの設計書をチェックしてコメントして". The workflow includes checking out the PR branch locally, validating design doc templates and content quality, and posting review comments on the PR in Japanese.
---

# Review Design Doc (kpiee-designs)

## Workflow

### 1) Gather inputs
- Get the PR URL or number. If missing, ask.
- Confirm repo is `f-scratch/kpiee-designs`. If different, stop and ask.

### 2) Prepare local workspace
- Check worktree safety:
  - `git status` and avoid destructive commands.
- Fetch and check out the PR branch locally:
  - `git fetch origin pull/<PR>/head:pr-<PR>`
  - `git checkout pr-<PR>`
- If the branch already exists locally, just `git checkout` it.

### 3) Identify review scope
- List changed files:
  - `git diff --name-only origin/<base>...HEAD`
  - If base is unknown, use PR info or `git show --name-only`.
- Focus on design docs under `docs/feature/`, `docs/fix/`, `docs/architecture/`, or related image assets.

### 4) Load repo-specific guidance
- Open and follow `AGENTS.md` and `CLAUDE.md` in the repo.
- Use the correct template from `docs/onboarding/` based on doc type.

### 5) Format compliance checks
- Confirm section numbering, headings, and required sections match the template.
- Ensure no empty sections or template placeholders remain.
- Confirm file placement and names are correct (e.g., `detail_design.md`).
- Check image paths and that images live beside the doc in `img/` when applicable.

### 6) Content quality checks
- Basic design: focus on What/Why/Purpose/Interface/Design philosophy; avoid implementation details.
- Detail design: focus on How; ensure logical flow and responsibility boundaries.
- Detail design: assume readers do not read the code; the doc must be understandable on its own without opening the codebase.
- Detail design: avoid over-specific, code-dependent explanations; the design should be readable without opening the codebase.
- Detail design: avoid large code blocks or full source listings; if any snippet appears, it should be minimal and used only to clarify intent/behavior.
- If the doc reads like a code dump or relies on code to explain the design intent, flag it and request a clear, language-based explanation of intent, mechanism, and rationale.
- Verify "概要/改修概要/設計方針" sections actually explain the feature and approach; if they only list links or headings, request a real summary in words.
- Require concrete descriptions for "API/データ処理/バリデーション" changes (name endpoints/classes and describe behavior); flag vague phrases like "対応/検証/シリアライズ" without specifics.
- Treat auto-generated files and regeneration commands as noise unless they are essential to design intent; request removal when included.
- Avoid overly fine-grained UI/implementation minutiae that don't change design decisions; keep explanations at the design level.
- Confirm assumptions and context are stated; avoid unexplained domain terms.
- Check for over/under specification and missing rationale.
- Follow the repo rules for release/rollback notes (only if special steps exist).
  - Calibration examples: `skills/review-design-doc/references/detail-design-bad-good-samples.md`

### 7) Draft review comments (Japanese)
- Prefer inline comments for concrete issues with exact file/line context.
- Use a short summary comment for overall feedback and positives.
- Classify tone by severity:
  - MUST: format violations, missing required sections, contradictions.
  - SHOULD: clarity, missing rationale, weak explanations.
  - QUESTION: ambiguous areas needing clarification.

### 8) Post the review on GitHub
- Use GitHub tools to create a pending review, add inline comments, then submit.
- Choose review event based on severity:
  - REQUEST_CHANGES if MUST issues exist.
  - COMMENT if only SHOULD/QUESTION feedback.

### 9) Report back to the user
- Provide a concise summary of what was reviewed and key findings.
- Mention any follow-up questions for the user.

## Notes
- Keep comments focused on the design document requirements and clarity for business/domain readers.
- Avoid adding new requirements; do not speculate beyond the PR content.
- If local files differ from PR view, re-fetch or verify with `git show`.
