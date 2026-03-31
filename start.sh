#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-prod}"

pull_with_fallback_tag() {
  local image="$1"
  local preferred_tag="$2"
  local fallback_tag="$3"
  local preferred_ref="${image}:${preferred_tag}"
  local fallback_ref="${image}:${fallback_tag}"

  # Try preferred tag first, but do not fail the whole script if it's missing.
  if docker pull "$preferred_ref" >/tmp/craftalism_pull_preferred.log 2>&1; then
    echo "$preferred_tag"
    return 0
  fi

  if grep -qiE 'manifest unknown|not found' /tmp/craftalism_pull_preferred.log; then
    echo "⚠️  Preferred tag unavailable: ${preferred_ref}" >&2
    echo "   Falling back to ${fallback_ref}" >&2
    echo "   Note: Git branch names and container registry tags are independent." >&2
  else
    echo "❌ Failed pulling ${preferred_ref} for a reason other than missing tag:" >&2
    cat /tmp/craftalism_pull_preferred.log >&2
    return 1
  fi

  if docker pull "$fallback_ref" >/tmp/craftalism_pull_fallback.log 2>&1; then
    echo "$fallback_tag"
    return 0
  fi

  echo "❌ Failed pulling fallback tag ${fallback_ref}:" >&2
  cat /tmp/craftalism_pull_fallback.log >&2
  return 1
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
