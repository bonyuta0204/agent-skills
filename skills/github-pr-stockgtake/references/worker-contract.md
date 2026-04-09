# Worker Contract

worker は単一 PR を調査し、次の意味情報を返す。

## Required

- `pr`: `owner/repo#number`
- `title`
- `summary`
- `status_category`
- `blocking_facts`
- `next_action`
- `ai_actionability`
- `confidence`

## Optional

- `auto_action_candidates`
- `repo_path`
- `latest_review_summary`
- `check_summary`
- `notes`

## summary

2〜4 文で、PR が何をしているかを author 向けに要約する。

## blocking_facts

推測ではなく、観測事実だけを書く。

例:

- `rubocop` が failure
- `mergeable=CONFLICTING`
- `reviewDecision=REVIEW_REQUIRED`
- checks が `WAITING`

## next_action

author が次にやる 1 手を 1 文で書く。

## auto_action_candidates

AI がその場で実行できる具体 action の配列。

例:

- `fix_rubocop_and_push`
- `rerun_failed_checks`
- `approve_pending_deployment`
- `reply_and_request_rereview`

## confidence

`high | medium | low`

local repo と GitHub 状態の両方を見ていれば `high`、remote-only で一部推定があるなら `medium`、根拠が薄いなら `low`。
