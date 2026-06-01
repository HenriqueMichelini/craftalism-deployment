#!/usr/bin/env bash
set -euo pipefail

DASHBOARD_PORT="${DASHBOARD_PORT:-8080}"
API_PORT="${API_PORT:-3000}"
MINECRAFT_PORT="${MINECRAFT_PORT:-25565}"
ENABLE_API=false
ENABLE_MINECRAFT=false

usage() {
  cat <<'EOF'
Usage: scripts/tailscale-serve-up.sh [--api] [--minecraft]

Starts tailnet-only Tailscale Serve proxies for local Craftalism services.

Options:
  --api         Also expose the API directly. The dashboard proxy does not require it.
  --minecraft   Also expose the Minecraft server over TCP.
EOF
}

while (($# > 0)); do
  case "$1" in
    --api)
      ENABLE_API=true
      ;;
    --minecraft)
      ENABLE_MINECRAFT=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[tailscale] Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "[tailscale] Required command not found: ${command_name}" >&2
    exit 1
  fi
}

require_url() {
  local service_name="$1"
  local url="$2"
  if ! curl -fsS "$url" >/dev/null; then
    echo "[tailscale] ${service_name} is not reachable at ${url}" >&2
    exit 1
  fi
  echo "[tailscale] ${service_name} is reachable: ${url}"
}

require_tcp() {
  local service_name="$1"
  local host="$2"
  local port="$3"
  if ! nc -z -w 2 "$host" "$port"; then
    echo "[tailscale] ${service_name} is not reachable at ${host}:${port}" >&2
    exit 1
  fi
  echo "[tailscale] ${service_name} is reachable: ${host}:${port}"
}

start_http_proxy() {
  local service_name="$1"
  local port="$2"
  echo "[tailscale] Exposing ${service_name} within the tailnet on HTTP port ${port}..."
  sudo tailscale serve --bg --http="$port" "localhost:${port}"
}

start_tcp_proxy() {
  local service_name="$1"
  local port="$2"
  echo "[tailscale] Exposing ${service_name} within the tailnet on TCP port ${port}..."
  sudo tailscale serve --bg --tcp="$port" "tcp://localhost:${port}"
}

require_command curl
require_command sudo
require_command tailscale

require_url "dashboard" "http://localhost:${DASHBOARD_PORT}/"
if [[ "$ENABLE_API" == true ]]; then
  require_url "API health" "http://localhost:${API_PORT}/actuator/health"
fi
if [[ "$ENABLE_MINECRAFT" == true ]]; then
  require_command nc
  require_tcp "Minecraft" "localhost" "$MINECRAFT_PORT"
fi

start_http_proxy "dashboard" "$DASHBOARD_PORT"
if [[ "$ENABLE_API" == true ]]; then
  start_http_proxy "API" "$API_PORT"
fi
if [[ "$ENABLE_MINECRAFT" == true ]]; then
  start_tcp_proxy "Minecraft" "$MINECRAFT_PORT"
fi

echo
echo "[tailscale] Current Serve status:"
tailscale serve status
