#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  batch_create_worktrees.sh \
    --repo <repo_path> \
    --base <base_branch_or_ref> \
    --id <implementation_id> \
    --issues <comma_separated_issue_numbers> \
    [--kind feat|chore|detach] \
    [--root <worktree_root>] \
    [--name-map <csv_file>]

Options:
  --repo      Local repository path.
  --base      Base branch or ref to branch from.
  --id        Implementation/internal ID used in branch names.
  --issues    Comma-separated issue numbers (e.g., 11971,11978).
  --kind      Branch kind prefix. Default: feat.
  --root      Root directory for generated worktrees.
              Default: ~/.codex/worktrees
  --name-map  Optional CSV file with rows: issue,suffix
              suffix is appended as <kind>/<id>_<suffix>
USAGE
}

REPO=""
BASE=""
ID=""
ISSUES=""
KIND="feat"
ROOT="${HOME}/.codex/worktrees"
NAME_MAP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --base) BASE="$2"; shift 2 ;;
    --id) ID="$2"; shift 2 ;;
    --issues) ISSUES="$2"; shift 2 ;;
    --kind) KIND="$2"; shift 2 ;;
    --root) ROOT="$2"; shift 2 ;;
    --name-map) NAME_MAP="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$REPO" || -z "$BASE" || -z "$ID" || -z "$ISSUES" ]]; then
  usage >&2
  exit 1
fi

if [[ ! -d "$REPO/.git" && ! -f "$REPO/.git" ]]; then
  echo "Invalid repo path: $REPO" >&2
  exit 1
fi

if [[ -n "$NAME_MAP" && ! -f "$NAME_MAP" ]]; then
  echo "name-map not found: $NAME_MAP" >&2
  exit 1
fi

sanitize() {
  local raw="$1"
  echo "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_]+/_/g; s/_+/_/g; s/^_+|_+$//g'
}

lookup_suffix() {
  local issue="$1"
  if [[ -z "$NAME_MAP" ]]; then
    return 1
  fi
  awk -F',' -v i="$issue" '
    $1 == i { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit 0 }
  ' "$NAME_MAP"
}

mkdir -p "$ROOT"
git -C "$REPO" fetch origin

BASE_REF="$BASE"
if git -C "$REPO" show-ref --verify --quiet "refs/remotes/origin/$BASE"; then
  BASE_REF="origin/$BASE"
fi

REPO_NAME="$(basename "$REPO")"
IFS=',' read -r -a ISSUE_ARRAY <<< "$ISSUES"

echo "issue,branch,worktree,status"
for issue in "${ISSUE_ARRAY[@]}"; do
  issue="$(echo "$issue" | xargs)"
  [[ -z "$issue" ]] && continue

  suffix=""
  if mapped="$(lookup_suffix "$issue" 2>/dev/null)"; then
    suffix="$(sanitize "$mapped")"
  else
    suffix="issue${issue}"
  fi

  branch="${KIND}/${ID}_${suffix}"
  lane_dir="${ROOT}/${ID}-${issue}"
  worktree_path="${lane_dir}/${REPO_NAME}"
  mkdir -p "$lane_dir"

  if git -C "$REPO" show-ref --verify --quiet "refs/heads/$branch"; then
    if [[ -d "$worktree_path/.git" || -f "$worktree_path/.git" ]]; then
      echo "${issue},${branch},${worktree_path},exists"
      continue
    fi
    git -C "$REPO" worktree add "$worktree_path" "$branch"
    echo "${issue},${branch},${worktree_path},attached_existing_branch"
    continue
  fi

  git -C "$REPO" worktree add "$worktree_path" -b "$branch" "$BASE_REF"
  echo "${issue},${branch},${worktree_path},created"
done
