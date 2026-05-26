#!/usr/bin/env bash

set_default_var() {
  local key="$1"
  local value="$2"
  if [[ -z "${!key:-}" ]]; then
    export "${key}=${value}"
  fi
}

RUNTIME_PROFILE_ENV_KEYS=(
  CRAFTALISM_RUNTIME_PROFILE
  AUTH_SERVER_JAVA_TOOL_OPTIONS
  AUTH_SERVER_MEM_LIMIT
  AUTH_SERVER_MEM_RESERVATION
  AUTH_SERVER_SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE
  AUTH_SERVER_SPRING_DATASOURCE_HIKARI_MINIMUM_IDLE
  API_JAVA_TOOL_OPTIONS
  API_MEM_LIMIT
  API_MEM_RESERVATION
  API_JVM_THREAD_BUDGET
  API_SPRING_JPA_SHOW_SQL
  API_SPRING_JPA_PROPERTIES_HIBERNATE_FORMAT_SQL
  API_SPRINGDOC_API_DOCS_ENABLED
  API_SPRINGDOC_SWAGGER_UI_ENABLED
  API_SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE
  API_SPRING_DATASOURCE_HIKARI_MINIMUM_IDLE
  MARKET_QUOTE_RATE_LIMIT_MAX_REQUESTS
  MARKET_EXECUTE_RATE_LIMIT_MAX_REQUESTS
  MARKET_RATE_LIMIT_WINDOW_SECONDS
  POSTGRES_SHARED_BUFFERS
  POSTGRES_WORK_MEM
  POSTGRES_MAINTENANCE_WORK_MEM
  POSTGRES_MEM_LIMIT
  POSTGRES_MEM_RESERVATION
  DASHBOARD_MEM_LIMIT
  DASHBOARD_MEM_RESERVATION
  DASHBOARD_BFF_MEM_LIMIT
  DASHBOARD_BFF_MEM_RESERVATION
  EDGE_MEM_LIMIT
  EDGE_MEM_RESERVATION
  MINECRAFT_INIT_MEMORY
  MINECRAFT_MEMORY
  MINECRAFT_VIEW_DISTANCE
  MINECRAFT_SIMULATION_DISTANCE
  MINECRAFT_MEM_LIMIT
  MINECRAFT_MEM_RESERVATION
  USE_AIKAR_FLAGS
  MINECRAFT_JVM_XX_OPTS
)

read_runtime_env_var() {
  local file="$1"
  local key="$2"
  awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "$file"
}

load_runtime_profile_env_files() {
  local base_file="$1"
  local override_file="${2:-}"
  local key value
  local -A externally_set=()

  for key in "${RUNTIME_PROFILE_ENV_KEYS[@]}"; do
    if [[ -n "${!key:-}" ]]; then
      externally_set["$key"]=1
    fi
  done

  if [[ -f "$base_file" ]]; then
    for key in "${RUNTIME_PROFILE_ENV_KEYS[@]}"; do
      if [[ -n "${externally_set[$key]:-}" ]]; then
        continue
      fi
      value="$(read_runtime_env_var "$base_file" "$key" || true)"
      if [[ -n "$value" ]]; then
        export "$key=$value"
      fi
    done
  fi

  if [[ -n "$override_file" && -f "$override_file" ]]; then
    for key in "${RUNTIME_PROFILE_ENV_KEYS[@]}"; do
      if [[ -n "${externally_set[$key]:-}" ]]; then
        continue
      fi
      value="$(read_runtime_env_var "$override_file" "$key" || true)"
      if [[ -n "$value" ]]; then
        export "$key=$value"
      fi
    done
  fi
}

apply_runtime_profile() {
  local profile="${1:-small-host}"

  case "$profile" in
    small-host)
      set_default_var AUTH_SERVER_JAVA_TOOL_OPTIONS "-Xms48m -Xmx112m -Xss512k -XX:+UseSerialGC -XX:MaxMetaspaceSize=72m -XX:ReservedCodeCacheSize=32m -XX:+ExitOnOutOfMemoryError"
      set_default_var AUTH_SERVER_MEM_LIMIT "320m"
      set_default_var AUTH_SERVER_MEM_RESERVATION "128m"
      set_default_var AUTH_SERVER_SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE "2"
      set_default_var AUTH_SERVER_SPRING_DATASOURCE_HIKARI_MINIMUM_IDLE "1"
      set_default_var API_JAVA_TOOL_OPTIONS "-Xms48m -Xmx144m -Xss512k -XX:+UseSerialGC -XX:MaxMetaspaceSize=128m -XX:ReservedCodeCacheSize=48m -XX:+ExitOnOutOfMemoryError"
      set_default_var API_MEM_LIMIT "576m"
      set_default_var API_MEM_RESERVATION "192m"
      set_default_var API_JVM_THREAD_BUDGET "80"
      set_default_var API_SPRINGDOC_API_DOCS_ENABLED "false"
      set_default_var API_SPRINGDOC_SWAGGER_UI_ENABLED "false"
      set_default_var API_SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE "3"
      set_default_var API_SPRING_DATASOURCE_HIKARI_MINIMUM_IDLE "1"
      set_default_var MARKET_QUOTE_RATE_LIMIT_MAX_REQUESTS "120"
      set_default_var MARKET_EXECUTE_RATE_LIMIT_MAX_REQUESTS "30"
      set_default_var MARKET_RATE_LIMIT_WINDOW_SECONDS "60"
      set_default_var POSTGRES_SHARED_BUFFERS "64MB"
      set_default_var POSTGRES_WORK_MEM "2MB"
      set_default_var POSTGRES_MAINTENANCE_WORK_MEM "32MB"
      set_default_var POSTGRES_MEM_LIMIT "192m"
      set_default_var POSTGRES_MEM_RESERVATION "96m"
      set_default_var DASHBOARD_MEM_LIMIT "64m"
      set_default_var DASHBOARD_MEM_RESERVATION "16m"
      set_default_var DASHBOARD_BFF_MEM_LIMIT "96m"
      set_default_var DASHBOARD_BFF_MEM_RESERVATION "32m"
      set_default_var EDGE_MEM_LIMIT "96m"
      set_default_var EDGE_MEM_RESERVATION "32m"
      set_default_var MINECRAFT_INIT_MEMORY "768M"
      set_default_var MINECRAFT_MEMORY "768M"
      set_default_var MINECRAFT_VIEW_DISTANCE "6"
      set_default_var MINECRAFT_SIMULATION_DISTANCE "4"
      set_default_var MINECRAFT_MEM_LIMIT "1280m"
      set_default_var MINECRAFT_MEM_RESERVATION "768m"
      set_default_var USE_AIKAR_FLAGS "false"
      set_default_var MINECRAFT_JVM_XX_OPTS "-XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+DisableExplicitGC"
      ;;
    standard)
      set_default_var AUTH_SERVER_JAVA_TOOL_OPTIONS "-XX:InitialRAMPercentage=25 -XX:MaxRAMPercentage=50 -Xss512k -XX:+UseSerialGC -XX:MaxMetaspaceSize=128m -XX:+ExitOnOutOfMemoryError"
      set_default_var AUTH_SERVER_MEM_LIMIT "512m"
      set_default_var AUTH_SERVER_MEM_RESERVATION "384m"
      set_default_var AUTH_SERVER_SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE "6"
      set_default_var AUTH_SERVER_SPRING_DATASOURCE_HIKARI_MINIMUM_IDLE "1"
      set_default_var API_JAVA_TOOL_OPTIONS "-Xms192m -Xmx448m -Xss512k -XX:+UseSerialGC -XX:MaxMetaspaceSize=224m -XX:ReservedCodeCacheSize=128m -XX:+ExitOnOutOfMemoryError"
      set_default_var API_MEM_LIMIT "1280m"
      set_default_var API_MEM_RESERVATION "768m"
      set_default_var API_JVM_THREAD_BUDGET "96"
      set_default_var API_SPRINGDOC_API_DOCS_ENABLED "false"
      set_default_var API_SPRINGDOC_SWAGGER_UI_ENABLED "false"
      set_default_var API_SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE "8"
      set_default_var API_SPRING_DATASOURCE_HIKARI_MINIMUM_IDLE "1"
      set_default_var MARKET_QUOTE_RATE_LIMIT_MAX_REQUESTS "180"
      set_default_var MARKET_EXECUTE_RATE_LIMIT_MAX_REQUESTS "60"
      set_default_var MARKET_RATE_LIMIT_WINDOW_SECONDS "60"
      set_default_var POSTGRES_SHARED_BUFFERS "192MB"
      set_default_var POSTGRES_WORK_MEM "8MB"
      set_default_var POSTGRES_MAINTENANCE_WORK_MEM "96MB"
      set_default_var POSTGRES_MEM_LIMIT "384m"
      set_default_var POSTGRES_MEM_RESERVATION "192m"
      set_default_var DASHBOARD_MEM_LIMIT "128m"
      set_default_var DASHBOARD_MEM_RESERVATION "64m"
      set_default_var EDGE_MEM_LIMIT "128m"
      set_default_var EDGE_MEM_RESERVATION "64m"
      set_default_var MINECRAFT_INIT_MEMORY "768M"
      set_default_var MINECRAFT_MEMORY "768M"
      set_default_var MINECRAFT_VIEW_DISTANCE "8"
      set_default_var MINECRAFT_SIMULATION_DISTANCE "6"
      set_default_var MINECRAFT_MEM_LIMIT "1024m"
      set_default_var MINECRAFT_MEM_RESERVATION "768m"
      ;;
    *)
      echo "[runtime-profile] Unknown CRAFTALISM_RUNTIME_PROFILE: ${profile}" >&2
      echo "[runtime-profile] Supported profiles: small-host, standard" >&2
      return 1
      ;;
  esac

  export CRAFTALISM_RUNTIME_PROFILE="$profile"
}

parse_memory_mb() {
  local raw="${1:-}"
  local value unit

  if [[ -z "$raw" ]]; then
    return 1
  fi

  raw="${raw//[[:space:]]/}"
  if [[ "$raw" =~ ^([0-9]+)([kKmMgG][bB]?)?$ ]]; then
    value="${BASH_REMATCH[1]}"
    unit="${BASH_REMATCH[2]}"
  else
    return 1
  fi

  case "${unit^^}" in
    ""|"M"|"MB")
      printf '%s\n' "$value"
      ;;
    "K"|"KB")
      printf '%s\n' $((value / 1024))
      ;;
    "G"|"GB")
      printf '%s\n' $((value * 1024))
      ;;
    *)
      return 1
      ;;
  esac
}

extract_java_option_value() {
  local options="$1"
  local prefix="$2"
  local token

  for token in $options; do
    if [[ "$token" == "${prefix}"* ]]; then
      printf '%s\n' "${token#"$prefix"}"
      return 0
    fi
  done

  return 1
}

estimate_heap_from_java_opts_mb() {
  local options="$1"
  local limit_mb="$2"
  local xmx_value max_ram_percentage

  if xmx_value="$(extract_java_option_value "$options" "-Xmx")"; then
    parse_memory_mb "$xmx_value"
    return
  fi

  if max_ram_percentage="$(extract_java_option_value "$options" "-XX:MaxRAMPercentage=")"; then
    awk -v limit_mb="$limit_mb" -v pct="$max_ram_percentage" 'BEGIN { printf "%d\n", int((limit_mb * pct) / 100) }'
    return
  fi

  return 1
}

validate_reservation_not_above_limit() {
  local service_name="$1"
  local limit_raw="$2"
  local reservation_raw="$3"
  local limit_mb reservation_mb

  limit_mb="$(parse_memory_mb "$limit_raw")" || {
    echo "[prod] ${service_name} memory limit is invalid: ${limit_raw}" >&2
    return 1
  }

  reservation_mb="$(parse_memory_mb "$reservation_raw")" || {
    echo "[prod] ${service_name} memory reservation is invalid: ${reservation_raw}" >&2
    return 1
  }

  if (( reservation_mb > limit_mb )); then
    echo "[prod] ${service_name} memory reservation ${reservation_raw} exceeds limit ${limit_raw}." >&2
    return 1
  fi
}

validate_java_memory_budget() {
  local service_name="$1"
  local options="$2"
  local limit_raw="$3"
  local thread_budget="${4:-64}"
  local limit_mb heap_mb metaspace_mb code_cache_mb stack_mb stack_total_mb budget_mb xms_mb native_headroom_mb

  limit_mb="$(parse_memory_mb "$limit_raw")" || {
    echo "[prod] ${service_name} memory limit is invalid: ${limit_raw}" >&2
    return 1
  }

  if ! heap_mb="$(estimate_heap_from_java_opts_mb "$options" "$limit_mb")"; then
    echo "[prod] ${service_name} JVM options must include -Xmx or -XX:MaxRAMPercentage for production validation." >&2
    return 1
  fi

  metaspace_mb=0
  if metaspace_raw="$(extract_java_option_value "$options" "-XX:MaxMetaspaceSize=")"; then
    metaspace_mb="$(parse_memory_mb "$metaspace_raw")" || {
      echo "[prod] ${service_name} MaxMetaspaceSize is invalid: ${metaspace_raw}" >&2
      return 1
    }
  fi

  code_cache_mb=0
  if code_cache_raw="$(extract_java_option_value "$options" "-XX:ReservedCodeCacheSize=")"; then
    code_cache_mb="$(parse_memory_mb "$code_cache_raw")" || {
      echo "[prod] ${service_name} ReservedCodeCacheSize is invalid: ${code_cache_raw}" >&2
      return 1
    }
  fi

  stack_mb=1
  if stack_raw="$(extract_java_option_value "$options" "-Xss")"; then
    stack_mb="$(parse_memory_mb "$stack_raw")" || {
      echo "[prod] ${service_name} Xss value is invalid: ${stack_raw}" >&2
      return 1
    }
    if (( stack_mb < 1 )); then
      stack_mb=1
    fi
  fi

  if [[ ! "$thread_budget" =~ ^[0-9]+$ || "$thread_budget" -le 0 ]]; then
    echo "[prod] ${service_name} thread budget is invalid: ${thread_budget}" >&2
    return 1
  fi

  if xms_raw="$(extract_java_option_value "$options" "-Xms")"; then
    xms_mb="$(parse_memory_mb "$xms_raw")" || {
      echo "[prod] ${service_name} Xms value is invalid: ${xms_raw}" >&2
      return 1
    }
    if (( xms_mb > heap_mb )); then
      echo "[prod] ${service_name} Xms exceeds the computed max heap budget." >&2
      return 1
    fi
  fi

  native_headroom_mb=32
  if [[ "$service_name" == "api" ]]; then
    native_headroom_mb=128
  fi

  stack_total_mb=$((stack_mb * thread_budget))
  budget_mb=$((heap_mb + metaspace_mb + code_cache_mb + stack_total_mb + native_headroom_mb))
  if (( budget_mb >= limit_mb )); then
    echo "[prod] ${service_name} JVM budget (${budget_mb}MiB: heap=${heap_mb}, metaspace=${metaspace_mb}, code_cache=${code_cache_mb}, stacks=${stack_total_mb}, native_headroom=${native_headroom_mb}) does not fit inside ${limit_raw}." >&2
    echo "[prod] Lower heap/metaspace/code-cache/thread settings or raise the container memory limit for ${service_name}." >&2
    return 1
  fi
}

validate_minecraft_memory_budget() {
  local init_raw="$1"
  local max_raw="$2"
  local limit_raw="$3"
  local init_mb max_mb limit_mb

  init_mb="$(parse_memory_mb "$init_raw")" || {
    echo "[prod] MINECRAFT_INIT_MEMORY is invalid: ${init_raw}" >&2
    return 1
  }
  max_mb="$(parse_memory_mb "$max_raw")" || {
    echo "[prod] MINECRAFT_MEMORY is invalid: ${max_raw}" >&2
    return 1
  }
  limit_mb="$(parse_memory_mb "$limit_raw")" || {
    echo "[prod] MINECRAFT_MEM_LIMIT is invalid: ${limit_raw}" >&2
    return 1
  }

  if (( init_mb > max_mb )); then
    echo "[prod] MINECRAFT_INIT_MEMORY exceeds MINECRAFT_MEMORY." >&2
    return 1
  fi

  if (( max_mb + 128 >= limit_mb )); then
    echo "[prod] Minecraft heap leaves too little headroom inside ${limit_raw}." >&2
    echo "[prod] Lower MINECRAFT_MEMORY or raise MINECRAFT_MEM_LIMIT." >&2
    return 1
  fi
}
