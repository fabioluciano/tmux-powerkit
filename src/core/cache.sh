#!/usr/bin/env bash
# =============================================================================
# PowerKit Core: Cache
# Description: TTL-based file caching system (core-managed)
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "cache" && return 0

. "${POWERKIT_ROOT}/src/core/logger.sh"

# =============================================================================
# Configuration
# =============================================================================

_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-powerkit/data"

# In-memory cache for current render cycle (avoids disk reads)
declare -gA _MEMORY_CACHE=()
declare -g _CYCLE_TIMESTAMP=0

# =============================================================================
# Internal Functions
# =============================================================================

# Get current timestamp (cached per render cycle for performance)
# Uses Bash 5.0+ $EPOCHSECONDS builtin (no external process)
_get_now() {
    if (( _CYCLE_TIMESTAMP == 0 )); then
        _CYCLE_TIMESTAMP=$EPOCHSECONDS
    fi
    printf '%s' "$_CYCLE_TIMESTAMP"
}

# Reset cycle timestamp (call at start of each render cycle)
cache_reset_cycle() {
    _CYCLE_TIMESTAMP=0
    _MEMORY_CACHE=()
}

# =============================================================================
# Unified Render Cycle Cleanup
# =============================================================================
# Master cleanup function that resets all per-cycle caches to free memory.
# Call at start of render cycle to ensure fresh state.

# Reset all per-cycle caches (call at start of render)
# This is the single function to call for a clean render cycle start
# Usage: reset_all_cycle_caches
reset_all_cycle_caches() {
    # Reset cache module state
    cache_reset_cycle

    # Reset color resolver cache (if loaded)
    declare -F color_reset_cycle_cache &>/dev/null && color_reset_cycle_cache

    # Reset separator cache (if loaded)
    declare -F separator_reset_cache &>/dev/null && separator_reset_cache

    # Reset lifecycle plugin output (if loaded)
    declare -F lifecycle_reset_cycle &>/dev/null && lifecycle_reset_cycle
}

# Ensure cache directory exists
_ensure_cache_dir() {
    [[ -d "$_CACHE_DIR" ]] || mkdir -p "$_CACHE_DIR"
}

# Get cache file path for a key
# Usage: _cache_file_path "key"
_cache_file_path() {
    local key="$1"
    # Sanitize key for filesystem: keep alphanumeric, underscore, hyphen
    local safe_key="${key//[^a-zA-Z0-9_-]/_}"
    printf '%s/%s' "$_CACHE_DIR" "$safe_key"
}

# Get file modification time in seconds since epoch
# Usage: _file_mtime "/path/to/file"
_file_mtime() {
    local file="$1"
    if [[ -f "$file" ]]; then
        stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null || echo 0
    else
        echo 0
    fi
}

# =============================================================================
# Public Cache API
# =============================================================================

# Get cached value if still valid
# Usage: cache_get "key" "ttl_seconds"
# Returns: cached value if valid, empty and returns 1 if expired/missing
cache_get() {
    local key="$1"
    local ttl="$2"

    # Check in-memory cache first (fast path)
    local mem_key="${key}:${ttl}"
    if [[ -n "${_MEMORY_CACHE[$mem_key]+x}" ]]; then
        printf '%s' "${_MEMORY_CACHE[$mem_key]}"
        return 0
    fi

    # Inline path calculation to avoid subshell
    local safe_key="${key//[^a-zA-Z0-9_-]/_}"
    local cache_file="${_CACHE_DIR}/${safe_key}"

    [[ ! -f "$cache_file" ]] && return 1

    local now mtime age
    now=$(_get_now)
    mtime=$(_file_mtime "$cache_file")
    age=$((now - mtime))

    if (( age > ttl )); then
        return 1  # Expired
    fi

    local value
    value=$(< "$cache_file")

    # Store in memory cache for this cycle
    _MEMORY_CACHE["$mem_key"]="$value"

    printf '%s' "$value"
    return 0
}

# Store value in cache
# Usage: cache_set "key" "value"
cache_set() {
    local key="$1"
    local value="$2"

    _ensure_cache_dir

    # Inline path calculation to avoid subshell
    local safe_key="${key//[^a-zA-Z0-9_-]/_}"
    local cache_file="${_CACHE_DIR}/${safe_key}"

    printf '%s' "$value" > "$cache_file"
}

# Check if cache entry exists and is valid
# Usage: cache_valid "key" "ttl_seconds"
cache_valid() {
    local key="$1"
    local ttl="$2"

    # Check in-memory cache first
    local mem_key="${key}:${ttl}"
    [[ -n "${_MEMORY_CACHE[$mem_key]+x}" ]] && return 0

    local cache_file
    cache_file=$(_cache_file_path "$key")

    [[ ! -f "$cache_file" ]] && return 1

    local now mtime age
    now=$(_get_now)
    mtime=$(_file_mtime "$cache_file")
    age=$((now - mtime))

    (( age <= ttl ))
}

# Get cache age in seconds
# Usage: cache_age "key"
# Returns: age in seconds, or -1 if not found
cache_age() {
    local key="$1"

    local cache_file
    cache_file=$(_cache_file_path "$key")

    [[ ! -f "$cache_file" ]] && { echo -1; return 1; }

    local now mtime
    now=$(_get_now)
    mtime=$(_file_mtime "$cache_file")

    echo $((now - mtime))
}

# Get cached value or compute and cache it
# Usage: cache_get_or_compute "key" "ttl" command args...
# Example: cache_get_or_compute "weather" 300 curl -s "http://..."
cache_get_or_compute() {
    local key="$1"
    local ttl="$2"
    shift 2

    local cached
    if cached=$(cache_get "$key" "$ttl"); then
        printf '%s' "$cached"
        return 0
    fi

    local result
    result=$("$@")
    local status=$?

    if [[ $status -eq 0 && -n "$result" ]]; then
        cache_set "$key" "$result"
    fi

    printf '%s' "$result"
    return $status
}

# Clear a specific cache entry
# Usage: cache_clear "key"
cache_clear() {
    local key="$1"

    local cache_file
    cache_file=$(_cache_file_path "$key")

    rm -f "$cache_file" 2>/dev/null || true
}

# Clear all cache entries for a prefix
# Usage: cache_clear_prefix "prefix"
cache_clear_prefix() {
    local prefix="$1"
    local safe_prefix="${prefix//[^a-zA-Z0-9_-]/_}"

    _ensure_cache_dir

    local file
    for file in "$_CACHE_DIR/${safe_prefix}"*; do
        [[ -f "$file" ]] && rm -f "$file" 2>/dev/null || true
    done
}

# Clear all cache
# Usage: cache_clear_all
cache_clear_all() {
    _ensure_cache_dir
    rm -f "$_CACHE_DIR"/* 2>/dev/null || true
}

# =============================================================================
# Plugin Cache API (core-managed)
# =============================================================================

# Get plugin cache key
# Usage: _plugin_cache_key "plugin_name"
_plugin_cache_key() {
    local plugin="$1"
    printf 'plugin_%s' "$plugin"
}

# Store plugin output in cache
# Usage: _cache_plugin_output "plugin_name" "output"
_cache_plugin_output() {
    local plugin="$1"
    local output="$2"
    cache_set "$(_plugin_cache_key "$plugin")" "$output"
}

# Get cached plugin output
# Usage: _get_cached_plugin_output "plugin_name" "ttl"
_get_cached_plugin_output() {
    local plugin="$1"
    local ttl="$2"
    cache_get "$(_plugin_cache_key "$plugin")" "$ttl"
}

# Check if plugin cache is valid
# Usage: _plugin_cache_valid "plugin_name" "ttl"
_plugin_cache_valid() {
    local plugin="$1"
    local ttl="$2"
    cache_valid "$(_plugin_cache_key "$plugin")" "$ttl"
}

# Clear plugin cache
# Usage: _clear_plugin_cache "plugin_name"
_clear_plugin_cache() {
    local plugin="$1"
    cache_clear "$(_plugin_cache_key "$plugin")"
}

# =============================================================================
# Debug Functions
# =============================================================================

# List all cache entries with ages
cache_list() {
    _ensure_cache_dir

    local file filename age
    printf 'Cache entries:\n'
    for file in "$_CACHE_DIR"/*; do
        [[ -f "$file" ]] || continue
        filename=$(basename "$file")
        age=$(cache_age "$filename")
        printf '  %s (age: %ds)\n' "$filename" "$age"
    done
}

# Get cache directory path
get_cache_dir() {
    printf '%s' "$_CACHE_DIR"
}
