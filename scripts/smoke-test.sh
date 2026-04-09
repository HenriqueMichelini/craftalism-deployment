#!/usr/bin/env bash
set -euo pipefail

AUTH_SERVER_URL="${AUTH_SERVER_URL:-http://localhost:9000}"
API_URL="${API_URL:-http://localhost:3000}"
DASHBOARD_URL="${DASHBOARD_URL:-http://localhost:8080}"
MINECRAFT_CLIENT_ID="${MINECRAFT_CLIENT_ID:-minecraft-server}"
MINECRAFT_CLIENT_SECRET="${MINECRAFT_CLIENT_SECRET:?Set MINECRAFT_CLIENT_SECRET}"
SMOKE_TIMEOUT_SECONDS="${SMOKE_TIMEOUT_SECONDS:-180}"

wait_for_url() {
  local name="$1"
  local url="$2"
  local started_at
  started_at="$(date +%s)"

  until curl -fsS "$url" >/dev/null; do
    if (( "$(date +%s)" - started_at >= SMOKE_TIMEOUT_SECONDS )); then
      echo "[smoke] Timed out waiting for ${name}: ${url}" >&2
      return 1
    fi
    sleep 2
  done

  echo "[smoke] ${name} is reachable: ${url}"
}

extract_json_string() {
  local key="$1"
  sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    echo "[smoke] Assertion failed: ${message}" >&2
    return 1
  fi
}

wait_for_url "auth health" "${AUTH_SERVER_URL}/actuator/health"
wait_for_url "api health" "${API_URL}/actuator/health"
wait_for_url "dashboard root" "${DASHBOARD_URL}/"

echo "[smoke] Requesting access token..."
token_response="$(
  curl -fsS \
    -u "${MINECRAFT_CLIENT_ID}:${MINECRAFT_CLIENT_SECRET}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials&scope=api:write" \
    "${AUTH_SERVER_URL}/oauth2/token"
)"
access_token="$(printf '%s' "$token_response" | extract_json_string "access_token")"

if [[ -z "$access_token" ]]; then
  echo "[smoke] Failed to extract access token from auth server response." >&2
  exit 1
fi

player_uuid="${SMOKE_PLAYER_UUID:-$(cat /proc/sys/kernel/random/uuid)}"
player_name="${SMOKE_PLAYER_NAME:-SMK${player_uuid%%-*}}"
create_payload="$(printf '{"uuid":"%s","name":"%s"}' "$player_uuid" "$player_name")"

echo "[smoke] Creating player ${player_uuid} (${player_name})..."
create_http_code="$(
  curl -sS -o /tmp/craftalism-smoke-create-player.json -w "%{http_code}" \
    -X POST \
    "${API_URL}/api/players" \
    -H "Authorization: Bearer ${access_token}" \
    -H "Content-Type: application/json" \
    --data "$create_payload"
)"

if [[ "$create_http_code" != "201" ]]; then
  echo "[smoke] Expected 201 from protected player creation, got ${create_http_code}." >&2
  cat /tmp/craftalism-smoke-create-player.json >&2
  exit 1
fi

api_read_response="$(curl -fsS "${API_URL}/api/players/${player_uuid}")"
assert_contains "$api_read_response" "\"uuid\":\"${player_uuid}\"" "API read did not return the created player UUID"
assert_contains "$api_read_response" "\"name\":\"${player_name}\"" "API read did not return the created player name"
echo "[smoke] Direct API read verified."

dashboard_read_response="$(curl -fsS "${DASHBOARD_URL}/api/players/${player_uuid}")"
assert_contains "$dashboard_read_response" "\"uuid\":\"${player_uuid}\"" "Dashboard proxy read did not return the created player UUID"
assert_contains "$dashboard_read_response" "\"name\":\"${player_name}\"" "Dashboard proxy read did not return the created player name"
echo "[smoke] Dashboard proxy read verified."

echo "[smoke] Compose smoke flow passed."
