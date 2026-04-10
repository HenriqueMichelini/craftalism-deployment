#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REFRESH_SECONDS="${REFRESH_SECONDS:-3}"
TAIL_LINES="${TAIL_LINES:-20}"
SHOW_LOGS=0
COMPACT_MODE=0

if [ -t 1 ]; then
  COLOR_RED=$'\033[31m'
  COLOR_YELLOW=$'\033[33m'
  COLOR_GREEN=$'\033[32m'
  COLOR_BLUE=$'\033[34m'
  COLOR_BOLD=$'\033[1m'
  COLOR_RESET=$'\033[0m'
else
  COLOR_RED=''
  COLOR_YELLOW=''
  COLOR_GREEN=''
  COLOR_BLUE=''
  COLOR_BOLD=''
  COLOR_RESET=''
fi

usage() {
  cat <<'EOF'
Usage: scripts/monitor-platform.sh [--watch[=SECONDS]] [--logs] [--compact]

Stateful terminal dashboard for Craftalism:
- fixed sections with in-place updates
- host memory/swap/load
- per-container status and usage
- alerts and restart counts
- optional last-failure logs

Examples:
  scripts/monitor-platform.sh
  scripts/monitor-platform.sh --watch
  scripts/monitor-platform.sh --watch=3 --compact
  scripts/monitor-platform.sh --watch=3 --logs
EOF
}

parse_args() {
  REFRESH_SECONDS=0
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
      --compact)
        COMPACT_MODE=1
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

  if ! [[ "$REFRESH_SECONDS" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "[monitor] REFRESH_SECONDS must be a non-negative number." >&2
    exit 1
  fi
}

require_docker_access() {
  if ! docker info >/dev/null 2>&1; then
    echo "[monitor] Docker is not reachable. Run this script on the host with access to /var/run/docker.sock." >&2
    exit 1
  fi
}

cleanup() {
  if [ -t 1 ]; then
    tput cnorm 2>/dev/null || true
    tput sgr0 2>/dev/null || true
  fi
}

init_screen() {
  if [ -t 1 ]; then
    tput civis 2>/dev/null || true
    clear
  fi
}

move_to() {
  local row="$1"
  local col="$2"
  printf '\033[%s;%sH' "$row" "$col"
}

clear_line() {
  printf '\033[2K'
}

write_at() {
  local row="$1"
  local col="$2"
  shift 2
  move_to "$row" "$col"
  clear_line
  printf '%s' "$*"
}

colorize_level() {
  case "$1" in
    OK) printf '%s%s%s' "$COLOR_GREEN$COLOR_BOLD" "$1" "$COLOR_RESET" ;;
    WARN) printf '%s%s%s' "$COLOR_YELLOW$COLOR_BOLD" "$1" "$COLOR_RESET" ;;
    CRITICAL) printf '%s%s%s' "$COLOR_RED$COLOR_BOLD" "$1" "$COLOR_RESET" ;;
    *) printf '%s' "$1" ;;
  esac
}

host_snapshot() {
  local mem_line swap_line load_line
  mem_line="$(free -m | awk '/^Mem:/ {printf "used=%s free=%s avail=%s total=%s pct=%d", $3, $4, $7, $2, int(($3*100)/$2)}')"
  swap_line="$(free -m | awk '/^Swap:/ {printf "used=%s total=%s", $3, $2}')"
  load_line="$(uptime | sed 's/.*load average: //')"
  printf '%s|%s|%s\n' "$mem_line" "$swap_line" "$load_line"
}

alerts_snapshot() {
  local available used total usage_percent swap_total swap_used
  read -r total used available usage_percent <<<"$(free -m | awk '/^Mem:/ {print $2, $3, $7, int(($3*100)/$2)}')"
  read -r swap_total swap_used <<<"$(free -m | awk '/^Swap:/ {print $2, $3}')"

  if (( available < 128 )); then
    printf 'CRITICAL|host available memory %s MiB\n' "$available"
  elif (( available < 256 )); then
    printf 'WARN|host available memory %s MiB\n' "$available"
  else
    printf 'OK|host available memory %s MiB\n' "$available"
  fi

  if (( usage_percent >= 90 )); then
    printf 'CRITICAL|host memory usage %s%% (%s/%s MiB)\n' "$usage_percent" "$used" "$total"
  elif (( usage_percent >= 80 )); then
    printf 'WARN|host memory usage %s%% (%s/%s MiB)\n' "$usage_percent" "$used" "$total"
  else
    printf 'OK|host memory usage %s%% (%s/%s MiB)\n' "$usage_percent" "$used" "$total"
  fi

  if (( swap_total == 0 )); then
    printf 'WARN|swap disabled\n'
  elif (( swap_used > 0 )); then
    printf 'WARN|swap in use %s/%s MiB\n' "$swap_used" "$swap_total"
  else
    printf 'OK|swap enabled %s MiB\n' "$swap_total"
  fi

  docker stats --no-stream --format '{{.Name}}|{{.MemPerc}}|{{.CPUPerc}}' 2>/dev/null | awk -F'|' '
    function num(v) { gsub(/%/, "", v); return v + 0 }
    {
      mem = num($2)
      cpu = num($3)
      if (mem >= 90) print "CRITICAL|container " $1 " memory " $2
      else if (mem >= 75) print "WARN|container " $1 " memory " $2
      if (cpu >= 80) print "WARN|container " $1 " cpu " $3
    }'
}

container_rows() {
  docker ps --format '{{.Names}}' | while read -r name; do
    [ -n "$name" ] || continue
    local status health restart_count oom mem limit mempct cpu
    status="$(docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null || printf '?')"
    health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}}' "$name" 2>/dev/null || printf '?')"
    restart_count="$(docker inspect --format '{{.RestartCount}}' "$name" 2>/dev/null || printf '0')"
    oom="$(docker inspect --format '{{.State.OOMKilled}}' "$name" 2>/dev/null || printf 'false')"
    read -r cpu mem limit mempct <<<"$(docker stats --no-stream --format '{{.CPUPerc}} {{.MemUsage}} {{.MemPerc}}' "$name" 2>/dev/null | awk '{cpu=$1; mem=$2" "$3" "$4; limit=$5; mempct=$6; print cpu, mem, limit, mempct}')"
    printf '%s|%s|%s|%s|%s|%s|%s|%s\n' "$name" "$status" "$health" "$cpu" "$mem" "$limit" "$mempct" "$restart_count/$oom"
  done
}

hot_rows() {
  docker stats --no-stream --format '{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}|{{.PIDs}}' 2>/dev/null | awk -F'|' '
    function num(v) { gsub(/%/, "", v); return v + 0 }
    {
      if (num($2) >= 40 || num($4) >= 75) print
    }'
}

failure_log_target() {
  local target
  target="$(docker ps -a --format '{{.Names}}|{{.State}}' | awk -F'|' '$2 != "running" {print $1; exit}')"
  if [[ -z "$target" ]]; then
    target="$(docker ps --format '{{.Names}}|{{.Status}}' | awk -F'|' '/Restarting/ {print $1; exit}')"
  fi
  printf '%s' "$target"
}

draw_header() {
  write_at 1 1 "${COLOR_BOLD}Craftalism Platform Monitor${COLOR_RESET}"
  write_at 2 1 "repo: $ROOT_DIR"
  write_at 3 1 "time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
}

draw_host() {
  local line mem swap load
  line="$(host_snapshot)"
  mem="$(printf '%s' "$line" | cut -d'|' -f1)"
  swap="$(printf '%s' "$line" | cut -d'|' -f2)"
  load="$(printf '%s' "$line" | cut -d'|' -f3)"

  write_at 5 1 "${COLOR_BLUE}${COLOR_BOLD}Host${COLOR_RESET}"
  write_at 6 1 "$mem"
  write_at 7 1 "$swap"
  write_at 8 1 "load=$load"
}

draw_alerts() {
  write_at 10 1 "${COLOR_BLUE}${COLOR_BOLD}Alerts${COLOR_RESET}"
  local row=11 count=0 level message
  while IFS='|' read -r level message; do
    [ -n "${level:-}" ] || continue
    write_at "$row" 1 "$(colorize_level "$level") $message"
    row=$((row + 1))
    count=$((count + 1))
    if (( count >= 8 )); then
      break
    fi
  done < <(alerts_snapshot)
  while (( row <= 18 )); do
    write_at "$row" 1 ""
    row=$((row + 1))
  done
}

draw_compact() {
  write_at 20 1 "${COLOR_BLUE}${COLOR_BOLD}Hot Containers${COLOR_RESET}"
  write_at 21 1 "$(printf '%-24s %-8s %-22s %-8s %-8s' 'NAME' 'CPU' 'MEM' 'MEM %' 'PIDS')"
  local row=22 count=0
  while IFS='|' read -r name cpu mem mempct pids; do
    write_at "$row" 1 "$(printf '%-24s %-8s %-22s %-8s %-8s' "$name" "$cpu" "$mem" "$mempct" "$pids")"
    row=$((row + 1))
    count=$((count + 1))
    if (( count >= 8 )); then
      break
    fi
  done < <(hot_rows)
  while (( row <= 30 )); do
    write_at "$row" 1 ""
    row=$((row + 1))
  done
}

draw_full() {
  write_at 20 1 "${COLOR_BLUE}${COLOR_BOLD}Containers${COLOR_RESET}"
  write_at 21 1 "$(printf '%-22s %-10s %-10s %-8s %-22s %-8s %-12s' 'NAME' 'STATUS' 'HEALTH' 'CPU' 'MEM' 'MEM %' 'RESTARTS')"
  local row=22 count=0
  while IFS='|' read -r name status health cpu mem limit mempct restart_meta; do
    write_at "$row" 1 "$(printf '%-22s %-10s %-10s %-8s %-22s %-8s %-12s' "$name" "$status" "$health" "$cpu" "$mem/$limit" "$mempct" "$restart_meta")"
    row=$((row + 1))
    count=$((count + 1))
    if (( count >= 12 )); then
      break
    fi
  done < <(container_rows)
  while (( row <= 34 )); do
    write_at "$row" 1 ""
    row=$((row + 1))
  done
}

draw_logs() {
  (( SHOW_LOGS == 1 )) || return 0
  local target row=36
  target="$(failure_log_target)"
  write_at "$row" 1 "${COLOR_BLUE}${COLOR_BOLD}Failure Logs${COLOR_RESET}"
  row=$((row + 1))
  if [[ -z "$target" ]]; then
    write_at "$row" 1 "no stopped or restarting containers"
    row=$((row + 1))
  else
    write_at "$row" 1 "target: $target"
    row=$((row + 1))
    while IFS= read -r line; do
      write_at "$row" 1 "$line"
      row=$((row + 1))
      if (( row > 36 + TAIL_LINES )); then
        break
      fi
    done < <(docker logs --tail "$TAIL_LINES" "$target" 2>&1 || true)
  fi
}

render_once() {
  draw_header
  draw_host
  draw_alerts
  if (( COMPACT_MODE == 1 )); then
    draw_compact
  else
    draw_full
  fi
  draw_logs
}

main() {
  parse_args "$@"
  require_docker_access
  trap cleanup EXIT INT TERM

  if (( REFRESH_SECONDS == 0 )); then
    init_screen
    render_once
    printf '\n'
    exit 0
  fi

  init_screen
  while true; do
    render_once
    sleep "$REFRESH_SECONDS"
  done
}

main "$@"
