#!/usr/bin/env bash
# =============================================================================
# Plugin: ping
# Description: Display network latency to a target host
# Dependencies: ping (built-in)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "ping"

# =============================================================================
# Ping Functions
# =============================================================================

get_ping_latency() {
    local host count timeout
    host=$(get_cached_option "@powerkit_plugin_ping_host" "$POWERKIT_PLUGIN_PING_HOST")
    count=$(get_cached_option "@powerkit_plugin_ping_count" "$POWERKIT_PLUGIN_PING_COUNT")
    timeout=$(get_cached_option "@powerkit_plugin_ping_timeout" "$POWERKIT_PLUGIN_PING_TIMEOUT")
    
    [[ -z "$host" ]] && return 1
    
    local result
    if is_macos; then
        result=$(ping -c "$count" -t "$timeout" "$host" 2>/dev/null | tail -1)
    else
        result=$(ping -c "$count" -W "$timeout" "$host" 2>/dev/null | tail -1)
    fi
    
    # Extract average latency: round-trip min/avg/max/stddev = X/Y/Z/W ms
    local avg
    avg=$(echo "$result" | grep -oE '[0-9]+\.[0-9]+/[0-9]+\.[0-9]+' | head -1 | cut -d'/' -f2)
    
    [[ -z "$avg" ]] && return 1
    
    # Round to integer
    printf '%.0f' "$avg"
}

# =============================================================================
# Plugin Interface
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="${1:-}"
    local show="1" accent="" accent_icon=""

    [[ -z "$content" ]] && { build_display_info "0" "" "" ""; return; }

    local value threshold_result
    value=$(extract_numeric "$content")
    [[ -z "$value" ]] && { build_display_info "0" "" "" ""; return; }

    # Apply threshold colors using centralized helper
    if threshold_result=$(apply_threshold_colors "$value" "ping"); then
        accent="${threshold_result%%:*}"
        accent_icon="${threshold_result#*:}"
    fi

    build_display_info "$show" "$accent" "$accent_icon" ""
}

# =============================================================================
# Main
# =============================================================================

load_plugin() {
    local host
    host=$(get_cached_option "@powerkit_plugin_ping_host" "$POWERKIT_PLUGIN_PING_HOST")
    [[ -z "$host" ]] && return 0
    
    local cached
    if cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached"
        return 0
    fi
    
    local latency unit
    latency=$(get_ping_latency) || return 0
    unit=$(get_cached_option "@powerkit_plugin_ping_unit" "$POWERKIT_PLUGIN_PING_UNIT")
    
    local result="${latency}${unit}"
    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
