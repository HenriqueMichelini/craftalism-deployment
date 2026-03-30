#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-prod}"

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
    echo "🧪 Test mode (explicit main tags)"
    AUTH_SERVER_TEST_VERSION=main API_TEST_VERSION=main DASHBOARD_TEST_VERSION=main \
      docker compose -f docker-compose.yml -f docker-compose.test.yml pull auth-server api dashboard
    AUTH_SERVER_TEST_VERSION=main API_TEST_VERSION=main DASHBOARD_TEST_VERSION=main \
      docker compose -f docker-compose.yml -f docker-compose.test.yml up -d
    AUTH_SERVER_TEST_VERSION=main API_TEST_VERSION=main DASHBOARD_TEST_VERSION=main \
      docker compose -f docker-compose.yml -f docker-compose.test.yml up -d --no-deps --force-recreate auth-server api dashboard
    ;;
  *)
    echo "❌ Invalid mode: $MODE"
    echo "Usage: $0 [prod|test|test-main]"
    exit 1
    ;;
esac

echo "✅ Done!"
