#!/usr/bin/env bash
set -euo pipefail

# Pre-pulls compose images to reduce cold start latency in CI/CD.
# Usage:
#   scripts/prepull-images.sh [production|test] [base|friend-paper]

MODE="${1:-production}"
VARIANT="${2:-${CRAFTALISM_PROD_VARIANT:-base}}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/docker-compose.sh"

case "$MODE" in
  production)
    case "$VARIANT" in
      base)
        docker_compose --env-file .env -f docker-compose.yml pull
        ;;
      friend-paper)
        docker_compose --env-file .env --env-file .env.friend-paper -f docker-compose.yml -f docker-compose.friend-paper.yml pull
        ;;
      *)
        echo "Unknown production variant: $VARIANT" >&2
        echo "Supported variants: base, friend-paper" >&2
        exit 1
        ;;
    esac
    ;;
  test)
    docker_compose -f docker-compose.yml -f docker-compose.test.yml pull
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    echo "Usage: scripts/prepull-images.sh [production|test] [base|friend-paper]" >&2
    exit 1
    ;;
esac
