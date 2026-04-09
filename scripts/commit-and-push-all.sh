#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARENT_DIR="$(dirname "$ROOT_DIR")"

usage() {
  cat <<'EOF'
Usage: scripts/commit-and-push-all.sh "commit message" [repo-name ...]

Stages all changes, creates a commit, and pushes the current branch for each
selected sibling git repository under the parent IdeaProjects directory.

Examples:
  scripts/commit-and-push-all.sh "Fix Dockerfile casing"
  scripts/commit-and-push-all.sh "Update local build flow" craftalism-api craftalism-dashboard
EOF
}

if (($# == 0)); then
  usage >&2
  exit 1
fi

COMMIT_MESSAGE="$1"
shift

discover_repos() {
  find "$PARENT_DIR" -mindepth 1 -maxdepth 1 -type d -name '.git' -prune >/dev/null 2>&1
  find "$PARENT_DIR" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
    if [[ -d "$dir/.git" ]]; then
      basename "$dir"
    fi
  done | sort
}

resolve_repos() {
  if (($# > 0)); then
    printf '%s\n' "$@"
    return
  fi

  discover_repos
}

commit_and_push_repo() {
  local repo_name="$1"
  local repo_dir="${PARENT_DIR}/${repo_name}"

  if [[ ! -d "$repo_dir/.git" ]]; then
    echo "[push-all] Skipping ${repo_name}: not a git repository under ${PARENT_DIR}" >&2
    return 0
  fi

  local branch_name
  branch_name="$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD)"
  if [[ "$branch_name" == "HEAD" ]]; then
    echo "[push-all] Skipping ${repo_name}: detached HEAD" >&2
    return 0
  fi

  echo "[push-all] Processing ${repo_name} on ${branch_name}"

  git -C "$repo_dir" add -A

  if git -C "$repo_dir" diff --cached --quiet; then
    echo "[push-all] No changes to commit in ${repo_name}"
    return 0
  fi

  git -C "$repo_dir" commit -m "$COMMIT_MESSAGE"

  if git -C "$repo_dir" remote get-url origin >/dev/null 2>&1; then
    git -C "$repo_dir" push origin "$branch_name"
    echo "[push-all] Pushed ${repo_name} (${branch_name})"
  else
    echo "[push-all] Skipping push for ${repo_name}: no origin remote" >&2
  fi
}

mapfile -t REPOS < <(resolve_repos "$@")

if ((${#REPOS[@]} == 0)); then
  echo "[push-all] No repositories found." >&2
  exit 1
fi

for repo_name in "${REPOS[@]}"; do
  commit_and_push_repo "$repo_name"
done
