#!/usr/bin/env bash

resolve_docker_compose() {
  if docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE=(docker compose)
    return 0
  fi

  if command -v docker-compose >/dev/null 2>&1 && docker-compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE=(docker-compose)
    return 0
  fi

  echo "[compose] Docker Compose is required but was not found." >&2
  echo "[compose] Install the Docker Compose v2 plugin so 'docker compose version' works." >&2
  echo "[compose] On Fedora, this is typically the 'docker-compose-plugin' package." >&2
  exit 1
}

docker_compose() {
  if [[ "${DOCKER_COMPOSE_RESOLVED:-0}" != "1" ]]; then
    resolve_docker_compose
    DOCKER_COMPOSE_RESOLVED=1
  fi

  "${DOCKER_COMPOSE[@]}" "$@"
}
