# KPIEE PM Governance Rules

## Branch Naming

- Feature: `feat/<実装ID>_<変更内容>`
- Internal improvement: `chore/<内部改善ID>_<変更内容>`
- Rollback: `detach/<実装ID>_<変更内容>`
- One branch must contain one ID only.

## Commit Message

- Feature: `[実装ID] 説明`
- Internal improvement: `[内部改善ID] 説明`
- Rollback: `[DETACH_実装ID] 説明`

## PR Guardrails

- Set milestone (Danger blocks merge if missing).
- Do not include `WIP` in title/labels.
- Keep PR title prefix aligned with issue/branch ID.
- Keep PR body in repository template structure.

## CI Waiting Approval (Protected Environment)

`dx-kpiee` often pauses runs in `waiting` due to `test` environment protection.

1. List runs by commit:
```bash
gh run list --commit <HEAD_SHA> --json databaseId,workflowName,status,url
```

2. Check pending deployments:
```bash
gh api -X GET /repos/<owner>/<repo>/actions/runs/<RUN_ID>/pending_deployments
```

3. Approve deployment:
```bash
gh api -X POST /repos/<owner>/<repo>/actions/runs/<RUN_ID>/pending_deployments --input - <<'JSON'
{"environment_ids":[7773130912],"state":"approved","comment":"Approve test environment for CI"}
JSON
```

4. Watch checks:
```bash
gh pr checks <PR番号> --watch
```

