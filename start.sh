#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-prod}"

case "$MODE" in
  prod)
    echo "🚀 Production mode (pinned image tags from .env)"
    docker compose pull
    docker compose up -d
    ;;
  test)
    echo "🧪 Test mode (build from repo branches; default: main)"
    docker compose -f docker-compose.yml -f docker-compose.test.yml build --pull
    docker compose -f docker-compose.yml -f docker-compose.test.yml up -d
    ;;
  *)
    echo "❌ Invalid mode: $MODE"
    echo "Usage: $0 [prod|test]"
    exit 1
    ;;
esac

echo "✅ Done!"
