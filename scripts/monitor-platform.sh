#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REFRESH_SECONDS="${REFRESH_SECONDS:-0}"

usage() {
  cat <<'EOF'
Usage: scripts/monitor-platform.sh [--watch[=SECONDS]]

Shows a compact runtime snapshot for the Craftalism platform:
- host uptime and load
- memory and swap
- Docker container state
- Docker container memory/cpu usage
- compose health state
- top host processes by memory and CPU

Examples:
  scripts/monitor-platform.sh
  scripts/monitor-platform.sh --watch
  scripts/monitor-platform.sh --watch=5
EOF
}

parse_args() {
  for arg in "$@"; do
    case "$arg" in
      --watch)
        REFRESH_SECONDS=3
        ;;
      --watch=*)
        REFRESH_SECONDS="${arg#--watch=}"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "[monitor] Unknown argument: $arg" >&2
        usage >&2
        exit 1
        ;;
    esac
  done

  if ! [[ "$REFRESH_SECONDS" =~ ^[0-9]+$ ]]; then
    echo "[monitor] REFRESH_SECONDS must be a non-negative integer." >&2
    exit 1
  fi
}

print_section() {
  printf '\n== %s ==\n' "$1"
}

clear_screen() {
  if [ -t 1 ] && command -v clear >/dev/null 2>&1; then
    clear || true
  fi
}

require_docker_access() {
  if ! docker info >/dev/null 2>&1; then
    echo "[monitor] Docker is not reachable. Run this script on the host with access to /var/run/docker.sock." >&2
    exit 1
  fi
}

show_host_summary() {
  print_section "Host"
  printf 'time: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
  uptime
  free -m
}

show_container_state() {
  print_section "Containers"
  docker ps --format '{{.Names}}|{{.Status}}|{{.Ports}}' | while IFS='|' read -r name status ports; do
    [ -n "$name" ] || continue
    health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}}' "$name" 2>/dev/null || printf 'unknown')"
    printf '%s|%s|%s|%s\n' "$name" "$status" "$health" "$ports"
  done | awk -F'|' '
    BEGIN {
      printf "%-28s %-24s %-10s %s\n", "NAME", "STATUS", "HEALTH", "PORTS"
    }
    {
      printf "%-28s %-24s %-10s %s\n", $1, $2, $3, $4
    }'
}

show_container_usage() {
  print_section "Container Usage"
  docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.PIDs}}'
}

show_memory_limits() {
  print_section "Container Limits"
  docker ps --format '{{.Names}}' | while read -r name; do
    [ -n "$name" ] || continue
    docker inspect --format '{{.Name}}|{{.HostConfig.Memory}}|{{.HostConfig.MemoryReservation}}|{{.State.OOMKilled}}|{{.State.Restarting}}' "$name"
  done | sed 's#^/##' | awk -F'|' '
    BEGIN {
      printf "%-28s %-12s %-12s %-10s %-10s\n", "NAME", "LIMIT", "RESERVE", "OOM", "RESTARTING"
    }
    {
      limit = ($2 == "0" ? "unlimited" : $2)
      reserve = ($3 == "0" ? "unset" : $3)
      printf "%-28s %-12s %-12s %-10s %-10s\n", $1, limit, reserve, $4, $5
    }'
}

show_processes() {
  print_section "Top Processes By RSS"
  ps -eo pid,ppid,%cpu,%mem,rss,cmd --sort=-rss | head -n 12

  print_section "Top Processes By CPU"
  ps -eo pid,ppid,%cpu,%mem,rss,cmd --sort=-%cpu | head -n 12
}

show_recent_restarts() {
  print_section "Recent Docker Events"
  docker events --since 15m --until 0s --filter type=container --filter event=die --filter event=oom --filter event=restart 2>/dev/null | tail -n 20 || true
}

render_once() {
  clear_screen
  echo "Craftalism Platform Monitor"
  echo "repo: $ROOT_DIR"
  show_host_summary
  show_container_state
  show_container_usage
  show_memory_limits
  show_processes
  show_recent_restarts
}

main() {
  parse_args "$@"
  require_docker_access

  if (( REFRESH_SECONDS == 0 )); then
    render_once
    exit 0
  fi

  while true; do
    render_once
    sleep "$REFRESH_SECONDS"
  done
}

main "$@"
