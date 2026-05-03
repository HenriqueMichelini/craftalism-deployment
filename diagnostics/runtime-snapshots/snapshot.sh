#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-runtime-snapshot-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUT_DIR"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/docker-compose.sh"

echo "Writing snapshot to: $OUT_DIR"

docker_compose ps > "$OUT_DIR/compose-ps.txt" || true
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' > "$OUT_DIR/docker-ps.txt"
docker stats --no-stream > "$OUT_DIR/docker-stats.txt"
docker system df > "$OUT_DIR/docker-system-df.txt"

for c in $(docker ps --format '{{.Names}}'); do
  SAFE_NAME="$(echo "$c" | tr '/:' '__')"

  docker inspect "$c" > "$OUT_DIR/${SAFE_NAME}.inspect.json" || true
  docker top "$c" aux > "$OUT_DIR/${SAFE_NAME}.top.txt" || true

  docker exec "$c" sh -c 'cat /proc/meminfo 2>/dev/null' \
    > "$OUT_DIR/${SAFE_NAME}.meminfo.txt" 2>/dev/null || true

  docker exec "$c" sh -c 'cat /sys/fs/cgroup/memory.max 2>/dev/null || cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null' \
    > "$OUT_DIR/${SAFE_NAME}.cgroup-memory-limit.txt" 2>/dev/null || true

  docker exec "$c" sh -c 'cat /sys/fs/cgroup/cpu.max 2>/dev/null || true' \
    > "$OUT_DIR/${SAFE_NAME}.cgroup-cpu-limit.txt" 2>/dev/null || true

  docker exec "$c" sh -c 'ps -eo pid,ppid,comm,args 2>/dev/null' \
    > "$OUT_DIR/${SAFE_NAME}.processes.txt" 2>/dev/null || true

  docker exec "$c" sh -c 'env | sort' \
    > "$OUT_DIR/${SAFE_NAME}.env.txt" 2>/dev/null || true

  docker exec "$c" sh -c 'java -XX:+PrintFlagsFinal -version 2>/dev/null | grep -E "UseContainerSupport|MaxRAM|InitialRAM|ActiveProcessorCount|MaxHeapSize|InitialHeapSize|MaxMetaspaceSize|ThreadStackSize"' \
    > "$OUT_DIR/${SAFE_NAME}.jvm-flags.txt" 2>/dev/null || true
done

tar -czf "$OUT_DIR.tar.gz" "$OUT_DIR"
echo "Done: $OUT_DIR.tar.gz"
