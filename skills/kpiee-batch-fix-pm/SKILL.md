---
name: kpiee-batch-fix-pm
description: "Use when the user asks to run batch fixes across multiple AI-fixable issues as a PM agent in kpiee repositories. This skill orchestrates per-issue worktree creation, flexible task assignment to sub-agents, PR format enforcement, and CI waiting-approval handling."
---

# KPIEE Batch Fix PM

## Overview

Use this skill to run multi-issue bug-fix waves without losing governance quality.
It focuses on orchestration: queue design, per-issue execution lanes, PR quality gates, and CI approval operations.

## When To Use

- User asks for "AI_FIXABLEをまとめて直す", "PMとして回したい", "1Issue 1PRで進めたい"
- You need `worktree + sub-agent` parallel execution with strict PR conventions
- You need to handle `waiting` GitHub Actions runs caused by protected environments

Do not use this skill when:
- The user asks for single-issue direct implementation only
- The user asks for stocktake/classification only (use `github-issue-stocktake`)

## Inputs

Minimum required:
- `repo_path`: local repository path
- `repo_slug`: `owner/repo`
- `implementation_id`: e.g. `IMP_KP001168`
- `base_branch`: branch to base all per-issue branches on
- `issues`: issue numbers to execute (`AI_FIXABLE` subset)

Optional:
- `classification_map`: classification status by issue
- `assignment_strategy`: `user_defined` / `round_robin` / `by_scope`
- `assignment_map`: explicit issue-to-agent mapping when user decides assignment
- `max_parallel_agents`: default `4`
- `ci_approval`: `auto` (default) / `manual`
- `expected_milestone`: if omitted, infer from existing same-ID PRs or sprint rules

## Workflow

### 1) Intake And Queue Build
1. Confirm target set: use only `AI_FIXABLE` issues unless user explicitly includes other classes.
2. Detect duplicates against existing open PRs before spawning work.
3. Produce an execution board with:
- issue
- status (`queued` / `existing_pr` / `blocked` / `done`)
- planned branch
- planned worktree path
- assignee lane

### 2) Assignment (Flexible By Design)
1. If user provides assignment, use it as-is.
2. If no assignment is provided, choose a default strategy:
- `round_robin` by lane count
- fallback to sequential if lane capacity is 1
3. Keep assignment immutable once agents start, unless user asks to rebalance.

### 3) Prepare Per-Issue Execution Lanes
1. Create 1 worktree per issue from `base_branch`.
2. Create branch names with kpiee convention:
- `feat/<実装ID>_...` for feature bug-fix tracks
- `chore/<内部改善ID>_...` for CHORE tracks
3. Use `scripts/create_worktrees.sh` for deterministic setup.

### 4) Spawn And Control Worker Agents
1. Spawn one worker per issue lane.
2. Provide strict deliverables:
- root cause
- minimal fix
- focused tests
- commit with `[ID]` prefix
- push
- PR creation
3. Poll progress and recover interrupted workers by reading lane state directly.

### 5) PR Governance Gate
For every created/updated PR:
1. Enforce title prefix: `[<implementation_id>] ...`
2. Enforce milestone existence
3. Enforce template headings and issue link
4. Enforce base branch correctness

Use `scripts/check_pr_format.sh` for fast checks.
Use [references/pr-template.md](references/pr-template.md) as canonical body template.

### 6) CI Governance Gate
1. Detect `waiting` runs on each PR head commit.
2. If `ci_approval=auto`, approve `pending_deployments` for `test` environment.
3. Re-check PR checks until all terminal states are reached.
4. If failures remain, categorize by:
- formatting/typecheck failures (fix in lane branch)
- governance failures (milestone/template/title)
- external non-GitHub providers (report URL only)

Use `scripts/approve_waiting_runs.sh` and `scripts/collect_status.sh`.

### 7) Final PM Report
Return:
1. Issue -> PR mapping
2. CI status summary
3. Remaining blockers
4. Recommended merge order (usually risk-low first)

## Execution Rules

- Do not edit unrelated files in any lane.
- Do not collapse multiple issues into one PR unless user explicitly asks.
- Preserve user's assignment preference over automatic strategies.
- Prefer non-interactive git commands.
- Keep PM communication concise and stateful: what changed, what is blocked, what is next.

## Bundled Resources

### references/
- [references/kpiee-rules.md](references/kpiee-rules.md): kpiee branch/commit/CI governance rules
- [references/pr-template.md](references/pr-template.md): required PR body structure

### scripts/
- `scripts/create_worktrees.sh`
- `scripts/check_pr_format.sh`
- `scripts/approve_waiting_runs.sh`
- `scripts/collect_status.sh`

## Quick Start

```bash
# 1) worktree lane creation
scripts/create_worktrees.sh \
  --repo /path/to/repo \
  --base feat/IMP_KP001168_visiblity_master \
  --id IMP_KP001168 \
  --issues 11971,11978,11979,11981

# 2) PR format validation
scripts/check_pr_format.sh \
  --repo f-scratch/dx-kpiee \
  --pr 12371 \
  --id IMP_KP001168

# 3) approve waiting CI runs for a commit
scripts/approve_waiting_runs.sh \
  --repo f-scratch/dx-kpiee \
  --commit <HEAD_SHA>
```

---
