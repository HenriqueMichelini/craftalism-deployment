#!/usr/bin/env bash
set -euo pipefail

# Pre-pulls compose images to reduce cold start latency in CI/CD.
# Usage:
#   scripts/prepull-images.sh [production|test]

MODE="${1:-production}"

case "$MODE" in
  production)
    docker compose -f docker-compose.yml pull
    ;;
  test)
    docker compose -f docker-compose.yml -f docker-compose.test.yml pull
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    echo "Usage: scripts/prepull-images.sh [production|test]" >&2
    exit 1
    ;;
esac
