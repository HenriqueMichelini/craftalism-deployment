#!/usr/bin/env bash
set -euo pipefail

DASHBOARD_PORT="${DASHBOARD_PORT:-8080}"
API_PORT="${API_PORT:-3000}"
ENABLE_API=false

usage() {
  cat <<'EOF'
Usage: scripts/tailscale-serve-up.sh [--api]

Starts tailnet-only Tailscale Serve proxies for local Craftalism services.

Options:
  --api   Also expose the API directly. The dashboard proxy does not require it.
EOF
}

while (($# > 0)); do
  case "$1" in
    --api)
      ENABLE_API=true
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

start_proxy() {
  local service_name="$1"
  local port="$2"
  echo "[tailscale] Exposing ${service_name} within the tailnet on HTTP port ${port}..."
  sudo tailscale serve --bg --http="$port" "localhost:${port}"
}

require_command curl
require_command sudo
require_command tailscale

require_url "dashboard" "http://localhost:${DASHBOARD_PORT}/"
if [[ "$ENABLE_API" == true ]]; then
  require_url "API health" "http://localhost:${API_PORT}/actuator/health"
fi

start_proxy "dashboard" "$DASHBOARD_PORT"
if [[ "$ENABLE_API" == true ]]; then
  start_proxy "API" "$API_PORT"
fi

echo
echo "[tailscale] Current Serve status:"
tailscale serve status
