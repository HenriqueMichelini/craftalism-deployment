#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-runtime-snapshot-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUT_DIR"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/docker-compose.sh"

SENSITIVE_ENV_KEY_PATTERN='(^|_)(PASSWORD|SECRET|TOKEN|PRIVATE_KEY|PUBLIC_KEY|API_KEY|AUTH_KEY|RCON)(_|$)'

redact_env_stream() {
  awk -F= -v pattern="$SENSITIVE_ENV_KEY_PATTERN" '
    $1 ~ pattern {
      print $1 "=[REDACTED]"
      next
    }
    { print }
  '
}

redact_inspect_stream() {
  sed -E \
    -e 's/([A-Za-z0-9_]*(PASSWORD|SECRET|TOKEN|PRIVATE_KEY|PUBLIC_KEY|API_KEY|AUTH_KEY|RCON)[A-Za-z0-9_]*=)[^"]*/\1[REDACTED]/g' \
    -e 's/("(Password|Secret|Token|PrivateKey|PublicKey|ApiKey|AuthKey|Rcon)"[[:space:]]*:[[:space:]]*")[^"]*"/\1[REDACTED]"/Ig'
}

echo "Writing snapshot to: $OUT_DIR"

docker_compose ps > "$OUT_DIR/compose-ps.txt" || true
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' > "$OUT_DIR/docker-ps.txt"
docker stats --no-stream > "$OUT_DIR/docker-stats.txt"
docker system df > "$OUT_DIR/docker-system-df.txt"

for c in $(docker ps --format '{{.Names}}'); do
  SAFE_NAME="$(echo "$c" | tr '/:' '__')"

  docker inspect "$c" | redact_inspect_stream > "$OUT_DIR/${SAFE_NAME}.inspect.json" || true
  docker top "$c" aux > "$OUT_DIR/${SAFE_NAME}.top.txt" || true

  docker exec "$c" sh -c 'cat /proc/meminfo 2>/dev/null' \
    > "$OUT_DIR/${SAFE_NAME}.meminfo.txt" 2>/dev/null || true

  docker exec "$c" sh -c 'cat /sys/fs/cgroup/memory.max 2>/dev/null || cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null' \
    > "$OUT_DIR/${SAFE_NAME}.cgroup-memory-limit.txt" 2>/dev/null || true

  docker exec "$c" sh -c 'cat /sys/fs/cgroup/cpu.max 2>/dev/null || true' \
    > "$OUT_DIR/${SAFE_NAME}.cgroup-cpu-limit.txt" 2>/dev/null || true

  docker exec "$c" sh -c 'ps -eo pid,ppid,comm,args 2>/dev/null' \
    > "$OUT_DIR/${SAFE_NAME}.processes.txt" 2>/dev/null || true

  docker exec "$c" sh -c 'env | sort' 2>/dev/null | redact_env_stream \
    > "$OUT_DIR/${SAFE_NAME}.env.txt" 2>/dev/null || true

  docker exec "$c" sh -c 'java -XX:+PrintFlagsFinal -version 2>/dev/null | grep -E "UseContainerSupport|MaxRAM|InitialRAM|ActiveProcessorCount|MaxHeapSize|InitialHeapSize|MaxMetaspaceSize|ThreadStackSize"' \
    > "$OUT_DIR/${SAFE_NAME}.jvm-flags.txt" 2>/dev/null || true
done

tar -czf "$OUT_DIR.tar.gz" "$OUT_DIR"
echo "Done: $OUT_DIR.tar.gz"
