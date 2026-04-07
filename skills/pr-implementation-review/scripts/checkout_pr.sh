#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: checkout_pr.sh <pr-url> [remote]" >&2
  echo "Example: checkout_pr.sh https://github.com/owner/repo/pull/123 origin" >&2
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

pr_url="$1"
remote="${2:-origin}"

if [[ "$pr_url" =~ github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
  owner="${BASH_REMATCH[1]}"
  repo="${BASH_REMATCH[2]}"
  pr_number="${BASH_REMATCH[3]}"
else
  echo "Unsupported PR URL: $pr_url" >&2
  exit 2
fi

branch="pr-${pr_number}"

if git show-ref --verify --quiet "refs/heads/${branch}"; then
  git checkout "${branch}"
else
  git fetch "${remote}" "pull/${pr_number}/head:${branch}"
  git checkout "${branch}"
fi

echo "Checked out ${branch} for ${owner}/${repo} (#${pr_number}) from ${remote}."
echo "Refresh with: git fetch ${remote} pull/${pr_number}/head:${branch}" 
