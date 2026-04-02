#!/usr/bin/env bash
set -euo pipefail

# Starts only shared dependency services for fast local app iteration.
# Usage:
#   scripts/start-local-deps.sh [up|down|restart]

ACTION="${1:-up}"

case "$ACTION" in
  up)
    docker compose -f docker-compose.yml -f docker-compose.local.yml up -d postgres auth-db-init auth-server api
    ;;
  down)
    docker compose -f docker-compose.yml -f docker-compose.local.yml stop postgres auth-db-init auth-server api
    ;;
  restart)
    docker compose -f docker-compose.yml -f docker-compose.local.yml restart postgres auth-db-init auth-server api
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    echo "Usage: scripts/start-local-deps.sh [up|down|restart]" >&2
    exit 1
    ;;
esac
