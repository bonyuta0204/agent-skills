---
name: pr-architecture-review
description: Review pull requests with emphasis on code formatting/style consistency and architecture adherence (clean/onion/DDD, layering rules). Use when given a PR URL and asked to checkout locally, read repo docs (CLAUDE.md, AGENTS.md, .windsurf/rules, README, architecture docs), compare with similar files, and produce review feedback rather than bug hunting.
---

# PR Architecture Review

## Overview

Perform a local PR checkout, collect repository conventions, inspect diffs and adjacent code, and produce review feedback focused on formatting/style and architecture alignment.

## Workflow

1. Resolve repo and PR
   - Parse the PR URL (assume GitHub). Identify owner/repo and PR number.
   - Ensure you are in the local repo. If it is missing, ask the user for the local path or permission to clone.
   - Prefer `scripts/checkout_pr.sh <pr-url> [remote]` or `gh pr checkout <number>` when available.
   - Fallback: `git fetch origin pull/<number>/head:pr-<number>` then `git checkout pr-<number>`.

2. Gather conventions
   - Read `CLAUDE.md`, `AGENTS.md`, `.windsurf/rules/*` or `.windsurfrules` (if present), `README`, and `docs/architecture` or ADRs if present.
   - Extract: architecture style, layer boundaries, file placement rules, naming conventions, formatting/linters, review comment language.

3. Inspect changes
   - Use `git status -sb`, `git diff --stat`, and `git diff <base>...HEAD` or `gh pr diff`.
   - For each changed file, open the file and 1-2 similar files in the same feature or directory to compare patterns.
   - Validate: file placement, dependency direction, layer boundaries, naming, public API shape, formatting/lint alignment.
   - Do not run heavy tests unless the user asks.

4. Produce review
   - Use the checklist in `references/review-checklist.md`.
   - Prioritize architecture or convention violations first, then style/formatting issues.
   - Include file:line references and concise, actionable guidance.
   - If no issues, say so and list what was checked.
   - Ask before posting comments to a PR.

## Resources

- `scripts/checkout_pr.sh` for PR checkout.
- `references/review-checklist.md` for the review template and checklist.
