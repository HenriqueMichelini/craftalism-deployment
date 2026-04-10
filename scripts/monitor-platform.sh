#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REFRESH_SECONDS="${REFRESH_SECONDS:-0}"
TAIL_LINES="${TAIL_LINES:-40}"
SHOW_LOGS=0

usage() {
  cat <<'EOF'
Usage: scripts/monitor-platform.sh [--watch[=SECONDS]] [--logs]

Shows a compact runtime snapshot for the Craftalism platform:
- host uptime and load
- memory and swap
- Docker container state
- Docker container memory/cpu usage
- compose health state
- warning thresholds for host/container pressure
- restart counts and OOM state
- optional tail of the most recently exited/restarting container
- top host processes by memory and CPU

Examples:
  scripts/monitor-platform.sh
  scripts/monitor-platform.sh --watch
  scripts/monitor-platform.sh --watch=5
  scripts/monitor-platform.sh --watch=3 --logs
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
      --logs)
        SHOW_LOGS=1
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

show_alerts() {
  print_section "Alerts"

  local host_line available used total usage_percent swap_total swap_used
  host_line="$(free -m | awk '/^Mem:/ {printf "%s %s %s %s", $2, $3, $7, int(($3*100)/$2)}')"
  total="$(printf '%s' "$host_line" | awk '{print $1}')"
  used="$(printf '%s' "$host_line" | awk '{print $2}')"
  available="$(printf '%s' "$host_line" | awk '{print $3}')"
  usage_percent="$(printf '%s' "$host_line" | awk '{print $4}')"
  swap_total="$(free -m | awk '/^Swap:/ {print $2}')"
  swap_used="$(free -m | awk '/^Swap:/ {print $3}')"

  if (( available < 128 )); then
    printf 'CRITICAL host memory available is %s MiB\n' "$available"
  elif (( available < 256 )); then
    printf 'WARN host memory available is %s MiB\n' "$available"
  else
    printf 'OK host memory available is %s MiB\n' "$available"
  fi

  if (( usage_percent >= 90 )); then
    printf 'CRITICAL host memory usage is %s%% (%s/%s MiB)\n' "$usage_percent" "$used" "$total"
  elif (( usage_percent >= 80 )); then
    printf 'WARN host memory usage is %s%% (%s/%s MiB)\n' "$usage_percent" "$used" "$total"
  else
    printf 'OK host memory usage is %s%% (%s/%s MiB)\n' "$usage_percent" "$used" "$total"
  fi

  if (( swap_total == 0 )); then
    printf 'WARN swap is disabled\n'
  elif (( swap_used > 0 )); then
    printf 'WARN swap is in use: %s/%s MiB\n' "$swap_used" "$swap_total"
  else
    printf 'OK swap is enabled and idle: %s MiB\n' "$swap_total"
  fi

  docker stats --no-stream --format '{{.Name}}|{{.MemPerc}}|{{.CPUPerc}}' 2>/dev/null | awk -F'|' '
    function to_num(v) { gsub(/%/, "", v); return v + 0 }
    {
      mem = to_num($2)
      cpu = to_num($3)
      if (mem >= 90) {
        printf "CRITICAL container %s memory at %.2f%%\n", $1, mem
      } else if (mem >= 75) {
        printf "WARN container %s memory at %.2f%%\n", $1, mem
      }
      if (cpu >= 80) {
        printf "WARN container %s cpu at %.2f%%\n", $1, cpu
      }
    }'
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
    docker inspect --format '{{.Name}}|{{.HostConfig.Memory}}|{{.HostConfig.MemoryReservation}}|{{.State.OOMKilled}}|{{.State.Restarting}}|{{.RestartCount}}' "$name"
  done | sed 's#^/##' | awk -F'|' '
    BEGIN {
      printf "%-28s %-12s %-12s %-10s %-10s %-8s\n", "NAME", "LIMIT", "RESERVE", "OOM", "RESTARTING", "RESTARTS"
    }
    {
      limit = ($2 == "0" ? "unlimited" : $2)
      reserve = ($3 == "0" ? "unset" : $3)
      printf "%-28s %-12s %-12s %-10s %-10s %-8s\n", $1, limit, reserve, $4, $5, $6
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

show_failure_logs() {
  (( SHOW_LOGS == 1 )) || return 0

  local target
  target="$(
    docker ps -a --format '{{.Names}}|{{.State}}|{{.RunningFor}}' | awk -F'|' '
      $2 != "running" { print $1; exit }
    '
  )"

  if [[ -z "$target" ]]; then
    target="$(
      docker ps --format '{{.Names}}|{{.Status}}' | awk -F'|' '
        /Restarting/ { print $1; exit }
      '
    )"
  fi

  if [[ -z "$target" ]]; then
    return 0
  fi

  print_section "Failure Logs: ${target}"
  docker logs --tail "$TAIL_LINES" "$target" 2>&1 || true
}

render_once() {
  clear_screen
  echo "Craftalism Platform Monitor"
  echo "repo: $ROOT_DIR"
  show_host_summary
  show_alerts
  show_container_state
  show_container_usage
  show_memory_limits
  show_processes
  show_recent_restarts
  show_failure_logs
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
