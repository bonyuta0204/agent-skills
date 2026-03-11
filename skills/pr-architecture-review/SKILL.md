---
name: pr-architecture-review
description: Review pull requests with emphasis on code formatting/style consistency, architecture adherence (clean/onion/DDD, layering rules), and PR description quality. Use when given a PR URL and asked to checkout locally, read repo docs (CLAUDE.md, AGENTS.md, .windsurf/rules, README, architecture docs), compare with similar files, and produce review feedback rather than bug hunting.
---

# PR Architecture Review

## Overview

Perform a local PR checkout, collect repository conventions, inspect diffs and adjacent code, review the PR title/body, and produce feedback focused on formatting/style, architecture alignment, and PR explanation quality.

## Workflow

1. Resolve repo and PR
   - Parse the PR URL (assume GitHub). Identify owner/repo and PR number.
   - Ensure you are in the local repo. If it is missing, ask the user for the local path or permission to clone.
   - Prefer `scripts/checkout_pr.sh <pr-url> [remote]` or `gh pr checkout <number>` when available.
   - Fallback: `git fetch origin pull/<number>/head:pr-<number>` then `git checkout pr-<number>`.

2. Gather conventions
   - Read `CLAUDE.md`, `AGENTS.md`, `.windsurf/rules/*` or `.windsurfrules` (if present), `README`, and `docs/architecture` or ADRs if present.
   - Read the current PR title/body and the repo PR template if present.
   - Extract: architecture style, layer boundaries, file placement rules, naming conventions, formatting/linters, review comment language.
   - Reuse the PR explanation viewpoints from `github-create-pr`: reviewer context, root cause, fix explanation, verification, impact investigation, and similar defect investigation.

3. Inspect changes
   - Use `git status -sb`, `git diff --stat`, and `git diff <base>...HEAD` or `gh pr diff`.
   - For each changed file, open the file and 1-2 similar files in the same feature or directory to compare patterns.
   - Validate: file placement, dependency direction, layer boundaries, naming, public API shape, formatting/lint alignment.
   - Validate the PR description against the actual diff and template: missing sections, stale explanations, unclear reviewer context, weak verification evidence, and missing issue/spec links when the repo expects them.
   - Do not run heavy tests unless the user asks.

4. Produce review
   - Use the checklist in `references/review-checklist.md`.
   - Prioritize architecture or convention violations first, then style/formatting issues.
   - Include PR description findings when the title/body is missing, misleading, stale, or below the repo/template expectation.
   - Include file:line references and concise, actionable guidance.
   - When writing review comments in Japanese, prefer natural Japanese over literal translations from English.
   - Avoid unnecessary English words unless they are code identifiers, official tool names, or technical terms that would become less clear in Japanese.
   - After drafting each Japanese review comment, do one rewrite pass that checks whether it reads like natural Japanese written by a reviewer, not translated prose.
   - Prefer short sentences and direct wording. Lead with the problem, then explain the cause and impact in that order.
   - If no issues, say so and list what was checked.
   - Ask before posting comments to a PR.
   - When posting to GitHub with `gh api`, pass review bodies as actual multiline text, not JSON-escaped `\n` sequences.
   - Prefer `--raw-field body=$'...\n...'` or `--input` with a file/body payload that contains real newlines.
   - After posting or editing a comment, fetch it once with `gh api` and confirm the returned `body` contains real line breaks rather than literal `\\n`.

## Japanese Writing Quality

- Default to Japanese for user-facing review text unless the user asks for another language.
- Do not mix English into sentences when a natural Japanese expression exists.
- Avoid literal translations such as "契約を広げる", "成功扱いにする", "インテグレーション", or other phrasing that sounds translated; rewrite into plain reviewer language.
- If a technical concept is easier to understand in Japanese explanation plus code term, keep the code term in backticks and explain the concern in Japanese around it.
- Before posting to GitHub, read the final comment once as plain Japanese and simplify any sentence that feels stiff, translated, or harder to understand than necessary.
- Prefer wording like "〜してしまっています", "〜になるため", "その結果" when explaining review findings in Japanese, if that makes the sentence easier to read.
- PR 本文レビューでは、repo template の見出し順をなるべく保ったまま「レビューアが判断に必要な情報が足りているか」を先に見る。
- PR 本文の指摘は `github-create-pr` の観点を基準にする。最低限、次を確認する。
  - 事象や変更の背景が初見のレビューアに伝わるか
  - 原因や修正方針が diff と整合しているか
  - 動作確認、未確認事項、影響範囲調査が具体的か
  - 関連 Issue / spec / design doc / 関連 PR が repo ルールどおりに示されているか

### Preferred Tone

- Write as a calm reviewer in natural Japanese.
- Do not over-formalize.
- Do not sound like translated documentation.
- Keep the sentence structure simple: "何が問題か" → "なぜ起きるか" → "どんな影響があるか".

### Preferred Review Comment Shape

Use this shape by default for Japanese review comments:

1. One sentence that states the problem in plain Japanese.
2. One or two sentences that explain the trigger or implementation detail.
3. One sentence that explains the impact, regression, or spec difference.

Example:

- Good: `数値入力欄とバリデーションの組み合わせが、現在の Cast の仕様より広い値を許容してしまっています。`
- Good: `` `type="number"` にしたことで `1e3` のような指数表記を入力できる一方、バリデーション側では指数部分を取り除いたうえで正常値として通してしまいます。``
- Good: `base branch では「20桁まで、指数表記不可」だったため、ここは仕様差分になっています。`

- Avoid: `数値 field と validator の組み合わせが、今の Cast の契約より広い値を通します。`
- Avoid: `Field component 側が form state の契約を広げたり上書きしたりしています。`

## Resources

- `scripts/checkout_pr.sh` for PR checkout.
- `references/review-checklist.md` for the review template and checklist.
