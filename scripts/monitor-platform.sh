#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REFRESH_SECONDS="${REFRESH_SECONDS:-3}"
TAIL_LINES="${TAIL_LINES:-20}"
SHOW_LOGS=0
COMPACT_MODE=0
STOP_MONITOR=0
SAMPLER_PID=""
SNAPSHOT_DIR=""
DOCKER_STATS_SNAPSHOT=''
DOCKER_LIST_SNAPSHOT=''
DOCKER_INSPECT_SNAPSHOT=''
HOST_MEM_USED_MIB='-'
HOST_MEM_FREE_MIB='-'
HOST_MEM_AVAILABLE_MIB='-'
HOST_MEM_TOTAL_MIB='-'
HOST_MEM_PCT='-'
HOST_SWAP_USED_MIB='-'
HOST_SWAP_TOTAL_MIB='-'
HOST_LOAD_AVG='-'
SAMPLE_TIMESTAMP='0'
SNAPSHOT_STATUS='warming up'
LAST_RENDER_SAMPLE_TIMESTAMP=''
MAX_RENDER_LINES=0

declare -a FRAME_LINES=()
declare -a CONTAINER_ORDER=()
declare -A CONTAINER_STATE=()
declare -A CONTAINER_STATUS_TEXT=()
declare -A CONTAINER_CPU=()
declare -A CONTAINER_MEM_USED=()
declare -A CONTAINER_MEM_LIMIT=()
declare -A CONTAINER_MEM_PCT=()
declare -A CONTAINER_PIDS=()
declare -A CONTAINER_HEALTH=()
declare -A CONTAINER_RESTARTS=()
declare -A CONTAINER_OOM=()

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
  scripts/monitor-platform.sh --watch=0.5 --compact
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

refresh_is_zero() {
  [[ "$REFRESH_SECONDS" == "0" || "$REFRESH_SECONDS" == "0.0" ]]
}

init_snapshot_dir() {
  SNAPSHOT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/craftalism-monitor.XXXXXX")"
}

cleanup() {
  if [[ -n "$SAMPLER_PID" ]]; then
    kill "$SAMPLER_PID" >/dev/null 2>&1 || true
    wait "$SAMPLER_PID" 2>/dev/null || true
  fi

  if [[ -n "$SNAPSHOT_DIR" && -d "$SNAPSHOT_DIR" ]]; then
    rm -rf "$SNAPSHOT_DIR"
  fi

  if [ -t 1 ]; then
    tput cnorm 2>/dev/null || true
    tput sgr0 2>/dev/null || true
    printf '\n'
  fi
}

request_stop() {
  STOP_MONITOR=1
}

init_screen() {
  if [ -t 1 ]; then
    tput civis 2>/dev/null || true
    clear
  fi
}

move_cursor_home() {
  if [ -t 1 ]; then
    tput cup 0 0 2>/dev/null || printf '\033[H'
  fi
}

reset_frame() {
  FRAME_LINES=()
}

write_at() {
  local row="$1"
  local col="$2"
  shift 2

  while ((${#FRAME_LINES[@]} < row)); do
    FRAME_LINES+=("")
  done

  local current="${FRAME_LINES[row-1]}"
  local prefix=""
  local current_len=${#current}
  if (( current_len < col - 1 )); then
    prefix="${current}$(printf '%*s' "$((col - 1 - current_len))" '')"
  else
    prefix="${current:0:col-1}"
  fi
  FRAME_LINES[row-1]="${prefix}$*"
}

flush_frame() {
  move_cursor_home

  local i
  for ((i = 0; i < ${#FRAME_LINES[@]}; i++)); do
    printf '\033[2K%s\n' "${FRAME_LINES[i]}"
  done

  while (( i < MAX_RENDER_LINES )); do
    printf '\033[2K\n'
    i=$((i + 1))
  done

  MAX_RENDER_LINES=${#FRAME_LINES[@]}
  printf '\033[J'
}

colorize_level() {
  case "$1" in
    OK) printf '%s%s%s' "$COLOR_GREEN$COLOR_BOLD" "$1" "$COLOR_RESET" ;;
    WARN) printf '%s%s%s' "$COLOR_YELLOW$COLOR_BOLD" "$1" "$COLOR_RESET" ;;
    CRITICAL) printf '%s%s%s' "$COLOR_RED$COLOR_BOLD" "$1" "$COLOR_RESET" ;;
    *) printf '%s' "$1" ;;
  esac
}

percent_to_int() {
  local value="${1%%%}"
  value="${value%%.*}"
  if [[ "$value" =~ ^[0-9]+$ ]]; then
    printf '%s' "$value"
  else
    printf '0'
  fi
}

now_epoch() {
  printf '%(%s)T' -1
}

now_timestamp() {
  printf '%(%Y-%m-%d %H:%M:%S %Z)T' -1
}

read_host_metrics() {
  local mem_total_kib=0
  local mem_free_kib=0
  local mem_available_kib=0
  local swap_total_kib=0
  local swap_free_kib=0
  local key value _

  while read -r key value _; do
    case "$key" in
      MemTotal:) mem_total_kib="$value" ;;
      MemFree:) mem_free_kib="$value" ;;
      MemAvailable:) mem_available_kib="$value" ;;
      SwapTotal:) swap_total_kib="$value" ;;
      SwapFree:) swap_free_kib="$value" ;;
    esac
  done </proc/meminfo

  local mem_used_kib=$((mem_total_kib - mem_free_kib))
  local mem_pct=0
  if (( mem_total_kib > 0 )); then
    mem_pct=$(( (mem_used_kib * 100) / mem_total_kib ))
  fi

  printf 'HOST_MEM_USED_MIB=%q\n' "$((mem_used_kib / 1024))"
  printf 'HOST_MEM_FREE_MIB=%q\n' "$((mem_free_kib / 1024))"
  printf 'HOST_MEM_AVAILABLE_MIB=%q\n' "$((mem_available_kib / 1024))"
  printf 'HOST_MEM_TOTAL_MIB=%q\n' "$((mem_total_kib / 1024))"
  printf 'HOST_MEM_PCT=%q\n' "$mem_pct"
  printf 'HOST_SWAP_USED_MIB=%q\n' "$(((swap_total_kib - swap_free_kib) / 1024))"
  printf 'HOST_SWAP_TOTAL_MIB=%q\n' "$((swap_total_kib / 1024))"
  printf 'HOST_LOAD_AVG=%q\n' "$(cut -d' ' -f1-3 </proc/loadavg)"
}

collect_docker_snapshot() {
  local output_dir="$1"
  local list_file="$output_dir/docker-list.tmp"
  local stats_file="$output_dir/docker-stats.tmp"
  local inspect_file="$output_dir/docker-inspect.tmp"
  local host_file="$output_dir/host.tmp"
  local ids_file="$output_dir/container-ids.tmp"

  : >"$list_file"
  : >"$stats_file"
  : >"$inspect_file"

  read_host_metrics >"$host_file"

  if ! docker ps -a --format '{{.ID}}|{{.Names}}|{{.State}}|{{.Status}}' >"$list_file" 2>/dev/null; then
    printf 'SNAPSHOT_STATUS=%q\n' 'docker unavailable' >"$output_dir/meta.tmp"
    printf 'SAMPLE_TIMESTAMP=%q\n' "$(now_epoch)" >>"$output_dir/meta.tmp"
    mv "$host_file" "$output_dir/host.env"
    mv "$list_file" "$output_dir/docker-list.txt"
    mv "$stats_file" "$output_dir/docker-stats.txt"
    mv "$inspect_file" "$output_dir/docker-inspect.txt"
    mv "$output_dir/meta.tmp" "$output_dir/meta.env"
    return 1
  fi

  cut -d'|' -f1 "$list_file" >"$ids_file"

  docker stats --no-stream --format '{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}|{{.PIDs}}' >"$stats_file" 2>/dev/null &
  local stats_pid=$!

  if [[ -s "$ids_file" ]]; then
    xargs -r docker inspect --format '{{.Name}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}}|{{.RestartCount}}|{{.State.OOMKilled}}' <"$ids_file" | sed 's#^/##' >"$inspect_file" 2>/dev/null &
    local inspect_pid=$!
  else
    local inspect_pid=""
  fi

  wait "$stats_pid" 2>/dev/null || true
  if [[ -n "$inspect_pid" ]]; then
    wait "$inspect_pid" 2>/dev/null || true
  fi

  printf 'SNAPSHOT_STATUS=%q\n' 'ok' >"$output_dir/meta.tmp"
  printf 'SAMPLE_TIMESTAMP=%q\n' "$(now_epoch)" >>"$output_dir/meta.tmp"
  mv "$host_file" "$output_dir/host.env"
  mv "$list_file" "$output_dir/docker-list.txt"
  mv "$stats_file" "$output_dir/docker-stats.txt"
  mv "$inspect_file" "$output_dir/docker-inspect.txt"
  mv "$output_dir/meta.tmp" "$output_dir/meta.env"
  rm -f "$ids_file"
}

warmup_docker_access() {
  docker ps -a --format '{{.ID}}' >/dev/null 2>&1 || true
}

sampler_loop() {
  local interval="$1"
  local output_dir="$2"

  warmup_docker_access
  while true; do
    collect_docker_snapshot "$output_dir" >/dev/null 2>&1 || true
    sleep "$interval" || break
  done
}

start_sampler() {
  sampler_loop "$REFRESH_SECONDS" "$SNAPSHOT_DIR" &
  SAMPLER_PID=$!
}

load_snapshot_cache() {
  if [[ ! -f "$SNAPSHOT_DIR/meta.env" ]]; then
    return 1
  fi

  # shellcheck disable=SC1090
  source "$SNAPSHOT_DIR/meta.env"

  if [[ -f "$SNAPSHOT_DIR/host.env" ]]; then
    # shellcheck disable=SC1090
    source "$SNAPSHOT_DIR/host.env"
  fi

  if [[ -f "$SNAPSHOT_DIR/docker-list.txt" ]]; then
    DOCKER_LIST_SNAPSHOT="$(<"$SNAPSHOT_DIR/docker-list.txt")"
  else
    DOCKER_LIST_SNAPSHOT=''
  fi

  if [[ -f "$SNAPSHOT_DIR/docker-stats.txt" ]]; then
    DOCKER_STATS_SNAPSHOT="$(<"$SNAPSHOT_DIR/docker-stats.txt")"
  else
    DOCKER_STATS_SNAPSHOT=''
  fi

  if [[ -f "$SNAPSHOT_DIR/docker-inspect.txt" ]]; then
    DOCKER_INSPECT_SNAPSHOT="$(<"$SNAPSHOT_DIR/docker-inspect.txt")"
  else
    DOCKER_INSPECT_SNAPSHOT=''
  fi

  return 0
}

reset_indexes() {
  CONTAINER_ORDER=()
  CONTAINER_STATE=()
  CONTAINER_STATUS_TEXT=()
  CONTAINER_CPU=()
  CONTAINER_MEM_USED=()
  CONTAINER_MEM_LIMIT=()
  CONTAINER_MEM_PCT=()
  CONTAINER_PIDS=()
  CONTAINER_HEALTH=()
  CONTAINER_RESTARTS=()
  CONTAINER_OOM=()
}

index_snapshot_data() {
  reset_indexes

  local id name state status_text cpu mem_usage mem_pct pids health restarts oom
  while IFS='|' read -r id name state status_text; do
    [[ -n "${name:-}" ]] || continue
    CONTAINER_ORDER+=("$name")
    CONTAINER_STATE["$name"]="${state:-?}"
    CONTAINER_STATUS_TEXT["$name"]="${status_text:-?}"
    CONTAINER_HEALTH["$name"]='n/a'
    CONTAINER_RESTARTS["$name"]='0'
    CONTAINER_OOM["$name"]='false'
    CONTAINER_CPU["$name"]='-'
    CONTAINER_MEM_USED["$name"]='-'
    CONTAINER_MEM_LIMIT["$name"]='-'
    CONTAINER_MEM_PCT["$name"]='-'
    CONTAINER_PIDS["$name"]='-'
  done <<<"$DOCKER_LIST_SNAPSHOT"

  while IFS='|' read -r name cpu mem_usage mem_pct pids; do
    [[ -n "${name:-}" ]] || continue
    CONTAINER_CPU["$name"]="${cpu:--}"
    if [[ "$mem_usage" == *" / "* ]]; then
      CONTAINER_MEM_USED["$name"]="${mem_usage%% / *}"
      CONTAINER_MEM_LIMIT["$name"]="${mem_usage#* / }"
    else
      CONTAINER_MEM_USED["$name"]="${mem_usage:--}"
      CONTAINER_MEM_LIMIT["$name"]='-'
    fi
    CONTAINER_MEM_PCT["$name"]="${mem_pct:--}"
    CONTAINER_PIDS["$name"]="${pids:--}"
  done <<<"$DOCKER_STATS_SNAPSHOT"

  while IFS='|' read -r name health restarts oom; do
    [[ -n "${name:-}" ]] || continue
    CONTAINER_HEALTH["$name"]="${health:-n/a}"
    CONTAINER_RESTARTS["$name"]="${restarts:-0}"
    CONTAINER_OOM["$name"]="${oom:-false}"
  done <<<"$DOCKER_INSPECT_SNAPSHOT"
}

container_count() {
  printf '%s' "${#CONTAINER_ORDER[@]}"
}

draw_header() {
  write_at 1 1 "${COLOR_BOLD}Craftalism Platform Monitor${COLOR_RESET}"
  write_at 2 1 "repo: $ROOT_DIR"
  write_at 3 1 "time: $(now_timestamp)"
  write_at 4 1 "sample: ${SAMPLE_TIMESTAMP}s status=${SNAPSHOT_STATUS} containers=$(container_count)"
}

draw_host() {
  write_at 6 1 "${COLOR_BLUE}${COLOR_BOLD}Host${COLOR_RESET}"
  write_at 7 1 "used=${HOST_MEM_USED_MIB} free=${HOST_MEM_FREE_MIB} avail=${HOST_MEM_AVAILABLE_MIB} total=${HOST_MEM_TOTAL_MIB} pct=${HOST_MEM_PCT}"
  write_at 8 1 "swap used=${HOST_SWAP_USED_MIB} total=${HOST_SWAP_TOTAL_MIB}"
  write_at 9 1 "load=${HOST_LOAD_AVG}"
}

draw_alerts() {
  write_at 11 1 "${COLOR_BLUE}${COLOR_BOLD}Alerts${COLOR_RESET}"
  local row=12 count=0

  if [[ "$HOST_MEM_AVAILABLE_MIB" != "-" ]]; then
    if (( HOST_MEM_AVAILABLE_MIB < 128 )); then
      write_at "$row" 1 "$(colorize_level CRITICAL) host available memory ${HOST_MEM_AVAILABLE_MIB} MiB"
    elif (( HOST_MEM_AVAILABLE_MIB < 256 )); then
      write_at "$row" 1 "$(colorize_level WARN) host available memory ${HOST_MEM_AVAILABLE_MIB} MiB"
    else
      write_at "$row" 1 "$(colorize_level OK) host available memory ${HOST_MEM_AVAILABLE_MIB} MiB"
    fi
    row=$((row + 1))
    count=$((count + 1))
  fi

  if [[ "$HOST_MEM_PCT" != "-" ]]; then
    if (( HOST_MEM_PCT >= 90 )); then
      write_at "$row" 1 "$(colorize_level CRITICAL) host memory usage ${HOST_MEM_PCT}% (${HOST_MEM_USED_MIB}/${HOST_MEM_TOTAL_MIB} MiB)"
    elif (( HOST_MEM_PCT >= 80 )); then
      write_at "$row" 1 "$(colorize_level WARN) host memory usage ${HOST_MEM_PCT}% (${HOST_MEM_USED_MIB}/${HOST_MEM_TOTAL_MIB} MiB)"
    else
      write_at "$row" 1 "$(colorize_level OK) host memory usage ${HOST_MEM_PCT}% (${HOST_MEM_USED_MIB}/${HOST_MEM_TOTAL_MIB} MiB)"
    fi
    row=$((row + 1))
    count=$((count + 1))
  fi

  if [[ "$HOST_SWAP_TOTAL_MIB" != "-" ]]; then
    if (( HOST_SWAP_TOTAL_MIB == 0 )); then
      write_at "$row" 1 "$(colorize_level WARN) swap disabled"
    elif (( HOST_SWAP_USED_MIB > 0 )); then
      write_at "$row" 1 "$(colorize_level WARN) swap in use ${HOST_SWAP_USED_MIB}/${HOST_SWAP_TOTAL_MIB} MiB"
    else
      write_at "$row" 1 "$(colorize_level OK) swap enabled ${HOST_SWAP_TOTAL_MIB} MiB"
    fi
    row=$((row + 1))
    count=$((count + 1))
  fi

  local name cpu mem_pct
  for name in "${CONTAINER_ORDER[@]}"; do
    cpu="${CONTAINER_CPU[$name]:--}"
    mem_pct="${CONTAINER_MEM_PCT[$name]:--}"

    if [[ "$mem_pct" != "-" ]]; then
      local mem_pct_num
      mem_pct_num="$(percent_to_int "$mem_pct")"
      if (( mem_pct_num >= 90 )); then
        write_at "$row" 1 "$(colorize_level CRITICAL) container ${name} memory ${mem_pct}"
        row=$((row + 1))
        count=$((count + 1))
      elif (( mem_pct_num >= 75 )); then
        write_at "$row" 1 "$(colorize_level WARN) container ${name} memory ${mem_pct}"
        row=$((row + 1))
        count=$((count + 1))
      fi
    fi

    if [[ "$cpu" != "-" ]]; then
      local cpu_num
      cpu_num="$(percent_to_int "$cpu")"
      if (( cpu_num >= 80 )); then
        write_at "$row" 1 "$(colorize_level WARN) container ${name} cpu ${cpu}"
        row=$((row + 1))
        count=$((count + 1))
      fi
    fi

    if (( count >= 8 )); then
      break
    fi
  done

  while (( row <= 19 )); do
    write_at "$row" 1 ""
    row=$((row + 1))
  done
}

draw_compact() {
  write_at 21 1 "${COLOR_BLUE}${COLOR_BOLD}Hot Containers${COLOR_RESET}"
  write_at 22 1 "$(printf '%-24s %-8s %-22s %-8s %-8s' 'NAME' 'CPU' 'MEM' 'MEM %' 'PIDS')"
  local row=23 count=0 name cpu mem_used mem_limit mem_pct pids cpu_num mem_pct_num

  for name in "${CONTAINER_ORDER[@]}"; do
    cpu="${CONTAINER_CPU[$name]:--}"
    mem_used="${CONTAINER_MEM_USED[$name]:--}"
    mem_limit="${CONTAINER_MEM_LIMIT[$name]:--}"
    mem_pct="${CONTAINER_MEM_PCT[$name]:--}"
    pids="${CONTAINER_PIDS[$name]:--}"
    cpu_num="$(percent_to_int "$cpu")"
    mem_pct_num="$(percent_to_int "$mem_pct")"

    if [[ "$cpu" == "-" && "$mem_pct" == "-" ]]; then
      continue
    fi

    if (( cpu_num < 40 && mem_pct_num < 75 )); then
      continue
    fi

    write_at "$row" 1 "$(printf '%-24s %-8s %-22s %-8s %-8s' "$name" "$cpu" "${mem_used}/${mem_limit}" "$mem_pct" "$pids")"
    row=$((row + 1))
    count=$((count + 1))
    if (( count >= 8 )); then
      break
    fi
  done

  if (( count == 0 )); then
    write_at "$row" 1 "no hot containers"
    row=$((row + 1))
  fi

  while (( row <= 31 )); do
    write_at "$row" 1 ""
    row=$((row + 1))
  done
}

draw_full() {
  write_at 21 1 "${COLOR_BLUE}${COLOR_BOLD}Containers${COLOR_RESET}"
  write_at 22 1 "$(printf '%-22s %-10s %-10s %-8s %-22s %-8s %-12s' 'NAME' 'STATUS' 'HEALTH' 'CPU' 'MEM' 'MEM %' 'RESTARTS')"
  local row=23 count=0 name

  for name in "${CONTAINER_ORDER[@]}"; do
    write_at "$row" 1 "$(printf '%-22s %-10s %-10s %-8s %-22s %-8s %-12s' \
      "$name" \
      "${CONTAINER_STATE[$name]:-?}" \
      "${CONTAINER_HEALTH[$name]:-n/a}" \
      "${CONTAINER_CPU[$name]:--}" \
      "${CONTAINER_MEM_USED[$name]:--}/${CONTAINER_MEM_LIMIT[$name]:--}" \
      "${CONTAINER_MEM_PCT[$name]:--}" \
      "${CONTAINER_RESTARTS[$name]:-0}/${CONTAINER_OOM[$name]:-false}")"
    row=$((row + 1))
    count=$((count + 1))
    if (( count >= 12 )); then
      break
    fi
  done

  if (( count == 0 )); then
    write_at "$row" 1 "no containers found"
    row=$((row + 1))
  fi

  while (( row <= 35 )); do
    write_at "$row" 1 ""
    row=$((row + 1))
  done
}

failure_log_target() {
  local name state status_text
  for name in "${CONTAINER_ORDER[@]}"; do
    state="${CONTAINER_STATE[$name]:-}"
    if [[ -n "$state" && "$state" != "running" ]]; then
      printf '%s' "$name"
      return 0
    fi
  done

  for name in "${CONTAINER_ORDER[@]}"; do
    status_text="${CONTAINER_STATUS_TEXT[$name]:-}"
    if [[ "$status_text" == *"Restarting"* ]]; then
      printf '%s' "$name"
      return 0
    fi
  done

  return 1
}

draw_logs() {
  (( SHOW_LOGS == 1 )) || return 0

  local target row=37
  target="$(failure_log_target || true)"
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
      if (( row > 37 + TAIL_LINES )); then
        break
      fi
    done < <(docker logs --tail "$TAIL_LINES" "$target" 2>&1 || true)
  fi
}

draw_waiting_frame() {
  reset_frame
  write_at 1 1 "${COLOR_BOLD}Craftalism Platform Monitor${COLOR_RESET}"
  write_at 2 1 "repo: $ROOT_DIR"
  write_at 3 1 "time: $(now_timestamp)"
  write_at 5 1 "collecting initial Docker snapshot..."
  write_at 6 1 "requested refresh interval: ${REFRESH_SECONDS}s"
  flush_frame
}

render_once() {
  if ! load_snapshot_cache; then
    draw_waiting_frame
    return 0
  fi

  if [[ "$SAMPLE_TIMESTAMP" == "$LAST_RENDER_SAMPLE_TIMESTAMP" ]]; then
    SNAPSHOT_STATUS="cached"
  fi
  LAST_RENDER_SAMPLE_TIMESTAMP="$SAMPLE_TIMESTAMP"

  index_snapshot_data
  reset_frame
  draw_header
  draw_host
  draw_alerts
  if (( COMPACT_MODE == 1 )); then
    draw_compact
  else
    draw_full
  fi
  draw_logs
  flush_frame
}

main() {
  parse_args "$@"
  trap request_stop INT TERM
  trap cleanup EXIT

  if refresh_is_zero; then
    init_snapshot_dir
    if ! collect_docker_snapshot "$SNAPSHOT_DIR"; then
      echo "[monitor] Docker is not reachable. Run this script on the host with access to /var/run/docker.sock." >&2
      exit 1
    fi
    init_screen
    render_once
    printf '\n'
    exit 0
  fi

  init_snapshot_dir
  start_sampler
  init_screen
  while (( STOP_MONITOR == 0 )); do
    render_once
    sleep "$REFRESH_SECONDS" || true
  done
}

main "$@"
