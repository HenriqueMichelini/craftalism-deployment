#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-craftalism-minecraft}"
SINCE="${SINCE:-30m}"
OUT_DIR="${OUT_DIR:-./diagnostics}"

mkdir -p "${OUT_DIR}"

RAW_LOG="${OUT_DIR}/minecraft-raw.log"
MATCH_LOG="${OUT_DIR}/minecraft-market-matches.log"
SUMMARY_LOG="${OUT_DIR}/minecraft-market-summary.log"

docker logs --since "${SINCE}" "${CONTAINER_NAME}" > "${RAW_LOG}" 2>&1

grep -n -F -C 3 \
  -e "Craftalism Market API endpoints:" \
  -e "Craftalism Market API auth is not configured; protected quote/execute endpoints may return 403." \
  -e "403" \
  -e "quote" \
  -e "execute" \
  -e "auth" \
  -e "config" \
  "${RAW_LOG}" > "${MATCH_LOG}" || true

{
  echo "Container: ${CONTAINER_NAME}"
  echo "Since: ${SINCE}"
  echo

  if grep -Fq "Craftalism Market API endpoints:" "${RAW_LOG}"; then
    echo "[OK] Found endpoint log:"
    grep -F "Craftalism Market API endpoints:" "${RAW_LOG}" | tail -n 10
    echo
  else
    echo "[WARN] Endpoint log not found."
    echo
  fi

  if grep -Fq "Craftalism Market API auth is not configured; protected quote/execute endpoints may return 403." "${RAW_LOG}"; then
    echo "[WARN] Found auth-not-configured warning:"
    grep -F "Craftalism Market API auth is not configured; protected quote/execute endpoints may return 403." "${RAW_LOG}" | tail -n 10
    echo
  else
    echo "[OK] Auth-not-configured warning not found."
    echo
  fi

  echo "[INFO] quote/execute/403 lines:"
  grep -Ei "quote|execute|403" "${RAW_LOG}" || true
} > "${SUMMARY_LOG}"

echo "Done."
echo "Raw log:     ${RAW_LOG}"
echo "Matches log: ${MATCH_LOG}"
echo "Summary log: ${SUMMARY_LOG}"
