#!/usr/bin/env bash
set -euo pipefail

# Bootstraps local development dependencies by cloning/updating service repos
# and building the local economy plugin artifact used by docker-compose.local.yml.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARENT_DIR="$(dirname "$ROOT_DIR")"
GIT_HOST="${GIT_HOST:-https://github.com}"
GIT_OWNER="${GIT_OWNER:-HenriqueMichelini}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"

clone_or_update_repo() {
  local repo_name="$1"
  local branch_name="$2"
  local target_dir="${PARENT_DIR}/${repo_name}"
  local repo_url="${GIT_HOST}/${GIT_OWNER}/${repo_name}.git"

  if [[ ! -d "$target_dir/.git" ]]; then
    echo "[bootstrap] Cloning ${repo_name} (${branch_name})"
    git clone --branch "$branch_name" --single-branch "$repo_url" "$target_dir"
    return
  fi

  echo "[bootstrap] Reusing existing repo ${repo_name}"
  git -C "$target_dir" fetch --prune origin
  if git -C "$target_dir" show-ref --verify --quiet "refs/remotes/origin/${branch_name}"; then
    git -C "$target_dir" checkout "$branch_name"
    git -C "$target_dir" pull --ff-only origin "$branch_name"
  else
    echo "[bootstrap] Branch ${branch_name} not found on origin for ${repo_name}; leaving current branch unchanged"
  fi
}

clone_or_update_repo "craftalism-authorization-server" "${AUTH_SERVER_BRANCH:-$DEFAULT_BRANCH}"
clone_or_update_repo "craftalism-api" "${API_BRANCH:-$DEFAULT_BRANCH}"
clone_or_update_repo "craftalism-dashboard" "${DASHBOARD_BRANCH:-$DEFAULT_BRANCH}"
clone_or_update_repo "craftalism-economy" "${ECONOMY_BRANCH:-$DEFAULT_BRANCH}"

if [[ "${CLEAN_PLUGIN_BUILD:-0}" == "1" ]]; then
  "$ROOT_DIR/scripts/build-economy-plugin.sh" --clean "$PARENT_DIR/craftalism-economy/java"
else
  "$ROOT_DIR/scripts/build-economy-plugin.sh" "$PARENT_DIR/craftalism-economy/java"
fi
echo
echo "[bootstrap] Local development dependencies are ready."
echo "[bootstrap] Suggested environment variables:"
echo "  export AUTH_SERVER_BUILD_CONTEXT=$PARENT_DIR/craftalism-authorization-server"
echo "  export API_BUILD_CONTEXT=$PARENT_DIR/craftalism-api"
echo "  export DASHBOARD_BUILD_CONTEXT=$PARENT_DIR/craftalism-dashboard"
echo "  export ECONOMY_PLUGIN_JAR=$ROOT_DIR/.local-dev/craftalism-economy.jar"
