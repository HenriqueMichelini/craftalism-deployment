#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-prod}"

pull_with_fallback_tag() {
  local image="$1"
  local preferred_tag="$2"
  local fallback_tag="$3"

  if docker pull "${image}:${preferred_tag}" >/dev/null; then
    echo "$preferred_tag"
    return 0
  fi

  echo "⚠️  ${image}:${preferred_tag} not available in registry. Falling back to ${image}:${fallback_tag}." >&2
  echo "   Note: a Git branch named ${preferred_tag} does not automatically create a container tag named ${preferred_tag}." >&2
  docker pull "${image}:${fallback_tag}" >/dev/null
  echo "$fallback_tag"
}

case "$MODE" in
  prod)
    echo "🚀 Production mode (pinned tags from .env)"
    docker compose pull
    docker compose up -d
    ;;
  test)
    echo "🧪 Test mode (mutable test tags)"
    docker compose -f docker-compose.yml -f docker-compose.test.yml pull auth-server api dashboard
    docker compose -f docker-compose.yml -f docker-compose.test.yml up -d
    docker compose -f docker-compose.yml -f docker-compose.test.yml up -d --no-deps --force-recreate auth-server api dashboard
    ;;
  test-main)
    echo "🧪 Test mode (prefer main tags, fallback to latest when missing)"

    AUTH_SERVER_TEST_VERSION="$(pull_with_fallback_tag ghcr.io/henriquemichelini/craftalism-authorization-server main latest)"
    API_TEST_VERSION="$(pull_with_fallback_tag ghcr.io/henriquemichelini/craftalism-api main latest)"
    DASHBOARD_TEST_VERSION="$(pull_with_fallback_tag ghcr.io/henriquemichelini/craftalism-dashboard main latest)"

    echo "Resolved test-main tags: auth-server=${AUTH_SERVER_TEST_VERSION}, api=${API_TEST_VERSION}, dashboard=${DASHBOARD_TEST_VERSION}"

    AUTH_SERVER_TEST_VERSION="$AUTH_SERVER_TEST_VERSION" API_TEST_VERSION="$API_TEST_VERSION" DASHBOARD_TEST_VERSION="$DASHBOARD_TEST_VERSION" \
      docker compose -f docker-compose.yml -f docker-compose.test.yml up -d
    AUTH_SERVER_TEST_VERSION="$AUTH_SERVER_TEST_VERSION" API_TEST_VERSION="$API_TEST_VERSION" DASHBOARD_TEST_VERSION="$DASHBOARD_TEST_VERSION" \
      docker compose -f docker-compose.yml -f docker-compose.test.yml up -d --no-deps --force-recreate auth-server api dashboard
    ;;
  *)
    echo "❌ Invalid mode: $MODE"
    echo "Usage: $0 [prod|test|test-main]"
    exit 1
    ;;
esac

echo "✅ Done!"
