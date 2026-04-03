#!/usr/bin/env bash
set -euo pipefail

# Starts only shared local dependencies for faster local iteration.
# Usage:
#   scripts/start-local-deps.sh [up|down|restart]

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ACTION="${1:-up}"

read_env_var() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' .env
}

if [[ ! -f .env ]]; then
  cp env.example .env
  echo "[deps] Created .env from env.example"
fi

DUMMY_DIGEST="sha256:0000000000000000000000000000000000000000000000000000000000000000"
for key in AUTH_SERVER_VERSION API_VERSION DASHBOARD_VERSION ECONOMY_VERSION AUTH_SERVER_DIGEST API_DIGEST DASHBOARD_DIGEST POSTGRES_VERSION POSTGRES_DIGEST MINECRAFT_IMAGE_VERSION MINECRAFT_IMAGE_DIGEST RCON_PASSWORD; do
  if [[ -z "${!key:-}" ]]; then
    value="$(read_env_var "$key" || true)"
    if [[ -n "$value" ]]; then
      export "$key=$value"
    fi
  fi
done

export AUTH_SERVER_VERSION="${AUTH_SERVER_VERSION:-local}"
export API_VERSION="${API_VERSION:-local}"
export DASHBOARD_VERSION="${DASHBOARD_VERSION:-local}"
export ECONOMY_VERSION="${ECONOMY_VERSION:-local}"
export AUTH_SERVER_DIGEST="${AUTH_SERVER_DIGEST:-$DUMMY_DIGEST}"
export API_DIGEST="${API_DIGEST:-$DUMMY_DIGEST}"
export DASHBOARD_DIGEST="${DASHBOARD_DIGEST:-$DUMMY_DIGEST}"
export POSTGRES_VERSION="${POSTGRES_VERSION:-18-alpine}"
export POSTGRES_DIGEST="${POSTGRES_DIGEST:-$DUMMY_DIGEST}"
export MINECRAFT_IMAGE_VERSION="${MINECRAFT_IMAGE_VERSION:-java21}"
export MINECRAFT_IMAGE_DIGEST="${MINECRAFT_IMAGE_DIGEST:-$DUMMY_DIGEST}"
export RCON_PASSWORD="${RCON_PASSWORD:-local-rcon-password}"

DEPENDENCY_SERVICES=(
  postgres
  auth-db-init
  auth-server
  api
)

case "$ACTION" in
  up)
    docker compose -f docker-compose.yml -f docker-compose.local.yml up -d "${DEPENDENCY_SERVICES[@]}"
    ;;
  down)
    docker compose -f docker-compose.yml -f docker-compose.local.yml stop "${DEPENDENCY_SERVICES[@]}"
    ;;
  restart)
    docker compose -f docker-compose.yml -f docker-compose.local.yml restart "${DEPENDENCY_SERVICES[@]}"
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    echo "Usage: scripts/start-local-deps.sh [up|down|restart]" >&2
    exit 1
    ;;
esac
