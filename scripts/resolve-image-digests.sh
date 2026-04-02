#!/usr/bin/env bash
set -euo pipefail

# Resolves current image digests for deployment images from versions in an env file.
# Usage:
#   scripts/resolve-image-digests.sh [--env-file path] [--write] [--mode all|prod|test] [--allow-missing]
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
MODE="all"
ALLOW_MISSING=0

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
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --allow-missing)
      ALLOW_MISSING=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: scripts/resolve-image-digests.sh [--env-file path] [--write] [--mode all|prod|test] [--allow-missing]" >&2
      exit 1
      ;;
  esac
done

if [[ "$MODE" != "all" && "$MODE" != "prod" && "$MODE" != "test" ]]; then
  echo "Invalid --mode value: $MODE (expected all, prod, or test)" >&2
  exit 1
fi

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

  if ! docker pull "$image_ref" >/dev/null; then
    return 1
  fi
  local repo_digest
  repo_digest="$(docker image inspect --format '{{join .RepoDigests "\n"}}' "$image_ref" | head -n 1)"
  local digest="${repo_digest##*@}"

  if [[ -z "$digest" || "$digest" != sha256:* ]]; then
    return 1
  fi

  echo "$digest"
}

resolve_or_fail() {
  local var_name="$1"
  local image_ref="$2"
  local fallback_image_ref="${3:-}"
  local digest=""

  if digest="$(resolve_digest "$image_ref")"; then
    echo "$digest"
    return 0
  fi

  if [[ -n "$fallback_image_ref" ]] && digest="$(resolve_digest "$fallback_image_ref")"; then
    echo "[resolve] ${image_ref} not found, used fallback ${fallback_image_ref}" >&2
    echo "$digest"
    return 0
  fi

  if [[ "$ALLOW_MISSING" == "1" ]]; then
    echo "[resolve] Could not resolve ${var_name}; keeping existing value" >&2
    echo "${!var_name:-}"
    return 0
  fi

  echo "Could not resolve digest for ${image_ref}" >&2
  if [[ -n "$fallback_image_ref" ]]; then
    echo "Also failed fallback ${fallback_image_ref}" >&2
  fi
  echo "Tip: use --mode test to resolve only POSTGRES/MINECRAFT digests for ./test" >&2
  exit 1
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

POSTGRES_VERSION="${POSTGRES_VERSION:-18-alpine}"
MINECRAFT_IMAGE_VERSION="${MINECRAFT_IMAGE_VERSION:-java21}"

if [[ "$MODE" == "all" || "$MODE" == "prod" ]]; then
  require_var AUTH_SERVER_VERSION
  require_var API_VERSION
  require_var DASHBOARD_VERSION

  AUTH_SERVER_FALLBACK=""
  API_FALLBACK=""
  DASHBOARD_FALLBACK=""

  if [[ -n "${AUTH_SERVER_CI_TAG:-}" ]]; then
    AUTH_SERVER_FALLBACK="ghcr.io/henriquemichelini/craftalism-authorization-server:${AUTH_SERVER_CI_TAG}"
  fi
  if [[ -n "${API_CI_TAG:-}" ]]; then
    API_FALLBACK="ghcr.io/henriquemichelini/craftalism-api:${API_CI_TAG}"
  fi
  if [[ -n "${DASHBOARD_CI_TAG:-}" ]]; then
    DASHBOARD_FALLBACK="ghcr.io/henriquemichelini/craftalism-dashboard:${DASHBOARD_CI_TAG}"
  fi

  AUTH_SERVER_DIGEST="$(resolve_or_fail AUTH_SERVER_DIGEST "ghcr.io/henriquemichelini/craftalism-authorization-server:${AUTH_SERVER_VERSION}" "$AUTH_SERVER_FALLBACK")"
  API_DIGEST="$(resolve_or_fail API_DIGEST "ghcr.io/henriquemichelini/craftalism-api:${API_VERSION}" "$API_FALLBACK")"
  DASHBOARD_DIGEST="$(resolve_or_fail DASHBOARD_DIGEST "ghcr.io/henriquemichelini/craftalism-dashboard:${DASHBOARD_VERSION}" "$DASHBOARD_FALLBACK")"
fi

if [[ "$MODE" == "all" || "$MODE" == "prod" || "$MODE" == "test" ]]; then
  POSTGRES_DIGEST="$(resolve_or_fail POSTGRES_DIGEST "postgres:${POSTGRES_VERSION}")"
  MINECRAFT_IMAGE_DIGEST="$(resolve_or_fail MINECRAFT_IMAGE_DIGEST "itzg/minecraft-server:${MINECRAFT_IMAGE_VERSION}")"
fi

if [[ "$WRITE_MODE" == "1" ]]; then
  if [[ "$MODE" == "all" || "$MODE" == "prod" ]]; then
    replace_or_append AUTH_SERVER_DIGEST "$AUTH_SERVER_DIGEST"
    replace_or_append API_DIGEST "$API_DIGEST"
    replace_or_append DASHBOARD_DIGEST "$DASHBOARD_DIGEST"
  fi
  if [[ "$MODE" == "all" || "$MODE" == "prod" || "$MODE" == "test" ]]; then
    replace_or_append POSTGRES_DIGEST "$POSTGRES_DIGEST"
    replace_or_append MINECRAFT_IMAGE_DIGEST "$MINECRAFT_IMAGE_DIGEST"
  fi
  echo "Updated digest variables in $ENV_FILE"
else
  if [[ "$MODE" == "all" || "$MODE" == "prod" ]]; then
    echo "AUTH_SERVER_DIGEST=$AUTH_SERVER_DIGEST"
    echo "API_DIGEST=$API_DIGEST"
    echo "DASHBOARD_DIGEST=$DASHBOARD_DIGEST"
  fi
  if [[ "$MODE" == "all" || "$MODE" == "prod" || "$MODE" == "test" ]]; then
    echo "POSTGRES_DIGEST=$POSTGRES_DIGEST"
    echo "MINECRAFT_IMAGE_DIGEST=$MINECRAFT_IMAGE_DIGEST"
  fi
fi
