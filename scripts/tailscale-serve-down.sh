#!/usr/bin/env bash
set -euo pipefail

DASHBOARD_PORT="${DASHBOARD_PORT:-8080}"
API_PORT="${API_PORT:-3000}"
MINECRAFT_PORT="${MINECRAFT_PORT:-25565}"
FAILED=false

stop_http_proxy() {
  local service_name="$1"
  local port="$2"
  echo "[tailscale] Disabling ${service_name} proxy on HTTP port ${port}..."
  if ! sudo tailscale serve --http="$port" "localhost:${port}" off; then
    echo "[tailscale] Failed to disable ${service_name} proxy on HTTP port ${port}." >&2
    FAILED=true
  fi
}

stop_tcp_proxy() {
  local service_name="$1"
  local port="$2"
  echo "[tailscale] Disabling ${service_name} proxy on TCP port ${port}..."
  if ! sudo tailscale serve --tcp="$port" "tcp://localhost:${port}" off; then
    echo "[tailscale] Failed to disable ${service_name} proxy on TCP port ${port}." >&2
    FAILED=true
  fi
}

stop_http_proxy "dashboard" "$DASHBOARD_PORT"
stop_http_proxy "API" "$API_PORT"
stop_tcp_proxy "Minecraft" "$MINECRAFT_PORT"

echo
echo "[tailscale] Current Serve status:"
tailscale serve status || true

if [[ "$FAILED" == true ]]; then
  exit 1
fi
