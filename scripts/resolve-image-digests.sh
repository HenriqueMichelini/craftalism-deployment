#!/usr/bin/env bash
set -euo pipefail

# Resolves current image digests for deployment images from versions in an env file.
# Usage:
#   scripts/resolve-image-digests.sh [--env-file path] [--write]
#
# Default mode prints:
#   AUTH_SERVER_DIGEST=sha256:...
#   API_DIGEST=sha256:...
#   DASHBOARD_DIGEST=sha256:...
#   POSTGRES_DIGEST=sha256:...
#   MINECRAFT_IMAGE_DIGEST=sha256:...
#
# With --write, the script updates those variables in the env file in-place.

ENV_FILE=".env"
WRITE_MODE=0

while (($# > 0)); do
  case "$1" in
    --env-file)
      ENV_FILE="${2:-}"
      shift 2
      ;;
    --write)
      WRITE_MODE=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: scripts/resolve-image-digests.sh [--env-file path] [--write]" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$ENV_FILE" || ! -f "$ENV_FILE" ]]; then
  echo "Env file not found: $ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

require_var() {
  local var_name="$1"
  if [[ -z "${!var_name:-}" ]]; then
    echo "Missing required variable in $ENV_FILE: $var_name" >&2
    exit 1
  fi
}

resolve_digest() {
  local image_ref="$1"

  docker pull "$image_ref" >/dev/null
  local repo_digest
  repo_digest="$(docker image inspect --format '{{join .RepoDigests "\n"}}' "$image_ref" | head -n 1)"
  local digest="${repo_digest##*@}"

  if [[ -z "$digest" || "$digest" != sha256:* ]]; then
    echo "Could not resolve digest for $image_ref" >&2
    exit 1
  fi

  echo "$digest"
}

replace_or_append() {
  local key="$1"
  local value="$2"

  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
  else
    printf '%s=%s\n' "$key" "$value" >>"$ENV_FILE"
  fi
}

require_var AUTH_SERVER_VERSION
require_var API_VERSION
require_var DASHBOARD_VERSION

POSTGRES_VERSION="${POSTGRES_VERSION:-18-alpine}"
MINECRAFT_IMAGE_VERSION="${MINECRAFT_IMAGE_VERSION:-java21}"

AUTH_SERVER_DIGEST="$(resolve_digest "ghcr.io/henriquemichelini/craftalism-authorization-server:${AUTH_SERVER_VERSION}")"
API_DIGEST="$(resolve_digest "ghcr.io/henriquemichelini/craftalism-api:${API_VERSION}")"
DASHBOARD_DIGEST="$(resolve_digest "ghcr.io/henriquemichelini/craftalism-dashboard:${DASHBOARD_VERSION}")"
POSTGRES_DIGEST="$(resolve_digest "postgres:${POSTGRES_VERSION}")"
MINECRAFT_IMAGE_DIGEST="$(resolve_digest "itzg/minecraft-server:${MINECRAFT_IMAGE_VERSION}")"

if [[ "$WRITE_MODE" == "1" ]]; then
  replace_or_append AUTH_SERVER_DIGEST "$AUTH_SERVER_DIGEST"
  replace_or_append API_DIGEST "$API_DIGEST"
  replace_or_append DASHBOARD_DIGEST "$DASHBOARD_DIGEST"
  replace_or_append POSTGRES_DIGEST "$POSTGRES_DIGEST"
  replace_or_append MINECRAFT_IMAGE_DIGEST "$MINECRAFT_IMAGE_DIGEST"
  echo "Updated digest variables in $ENV_FILE"
else
  echo "AUTH_SERVER_DIGEST=$AUTH_SERVER_DIGEST"
  echo "API_DIGEST=$API_DIGEST"
  echo "DASHBOARD_DIGEST=$DASHBOARD_DIGEST"
  echo "POSTGRES_DIGEST=$POSTGRES_DIGEST"
  echo "MINECRAFT_IMAGE_DIGEST=$MINECRAFT_IMAGE_DIGEST"
fi
