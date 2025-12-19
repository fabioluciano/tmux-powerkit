#!/usr/bin/env bash
# =============================================================================
# PowerKit Cache System - KISS/DRY Version
# =============================================================================
#
# GLOBAL VARIABLES EXPORTED:
#   - CACHE_DIR (cache directory path)
#
# FUNCTIONS PROVIDED:
#   - cache_init(), cache_is_valid(), cache_get(), cache_set()
#   - cache_invalidate(), cache_clear_all(), setup_cache_keybinding()
#
# DEPENDENCIES: source_guard.sh, defaults.sh (for _DEFAULT_CACHE_DIRECTORY)
# =============================================================================

# Source guard
_CACHE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=src/source_guard.sh
. "$_CACHE_DIR/source_guard.sh"
source_guard "cache" && return 0

# Cache directory
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/$(get_tmux_option "@powerkit_cache_directory" "${_DEFAULT_CACHE_DIRECTORY}")"

# Initialize cache directory (once per session)
_CACHE_INIT=""
cache_init() {
    [[ -n "$_CACHE_INIT" ]] && return
    [[ -d "$CACHE_DIR" ]] || mkdir -p "$CACHE_DIR"
    _CACHE_INIT=1
}

# Check if cache is valid
# Usage: cache_is_valid <key> <ttl_seconds>
cache_is_valid() {
    local cache_file="${CACHE_DIR}/${1}.cache"
    local ttl_seconds="$2"

    [[ -f "$cache_file" ]] || return 1

    local file_mtime current_time
    current_time=$(date +%s)
    file_mtime=$(get_file_mtime "$cache_file") || return 1

    (((current_time - file_mtime) < ttl_seconds))
}

# Get cached value
# Usage: cache_get <key> <ttl_seconds>
cache_get() {
    local cache_file="${CACHE_DIR}/${1}.cache"
    local ttl_seconds="$2"

    cache_init

    if cache_is_valid "$1" "$ttl_seconds" && [[ -r "$cache_file" ]]; then
        printf '%s' "$(<"$cache_file")"
        return 0
    fi
    return 1
}

# Store value in cache
# Usage: cache_set <key> <value>
cache_set() {
    cache_init
    printf '%s' "$2" >"${CACHE_DIR}/${1}.cache"
}

# Invalidate cache
# Usage: cache_invalidate <key>
cache_invalidate() {
    local cache_file="${CACHE_DIR}/${1}.cache"
    [[ -f "$cache_file" ]] && rm -f "$cache_file"
}

# Clear all caches
cache_clear_all() {
    [[ -d "$CACHE_DIR" ]] && rm -rf "${CACHE_DIR:?}"/*
}

# Setup cache clear keybinding
setup_cache_keybinding() {
    local clear_key
    clear_key=$(get_tmux_option "@powerkit_cache_clear_key" "${POWERKIT_PLUGIN_CACHE_CLEAR_KEY:-Q}")

    [[ -n "$clear_key" ]] && tmux bind-key "$clear_key" run-shell \
        "rm -rf '${CACHE_DIR:?}'/* 2>/dev/null; tmux refresh-client -S" \
        \\\; display "PowerKit cache cleared!"
}

# =============================================================================
# Advanced Cache Functions
# =============================================================================

# Cache with automatic refresh (returns stale value while refreshing)
# Usage: cache_get_or_compute <key> <ttl> <command...>
cache_get_or_compute() {
    local key="$1"
    local ttl="$2"
    shift 2
    local cmd=("$@")

    cache_init

    # Start telemetry timing
    local start_ts=""
    declare -f telemetry_plugin_start &>/dev/null && start_ts=$(telemetry_plugin_start "$key")

    # Try to get valid cache
    local cached
    if cached=$(cache_get "$key" "$ttl"); then
        # Record cache hit
        [[ -n "$start_ts" ]] && declare -f telemetry_plugin_end &>/dev/null && \
            telemetry_plugin_end "$key" "$start_ts" "true"
        printf '%s' "$cached"
        return 0
    fi

    # Compute new value
    local result
    result=$("${cmd[@]}" 2>/dev/null) || return 1

    # Store and return
    [[ -n "$result" ]] && cache_set "$key" "$result"

    # Record cache miss (computed)
    [[ -n "$start_ts" ]] && declare -f telemetry_plugin_end &>/dev/null && \
        telemetry_plugin_end "$key" "$start_ts" "false"

    printf '%s' "$result"
}

# Get cache age in seconds
# Usage: cache_age <key>
cache_age() {
    local cache_file="${CACHE_DIR}/${1}.cache"

    [[ ! -f "$cache_file" ]] && { printf '-1'; return 1; }

    local file_mtime current_time
    current_time=$(date +%s)
    file_mtime=$(get_file_mtime "$cache_file") || { printf '-1'; return 1; }

    printf '%d' "$((current_time - file_mtime))"
}

