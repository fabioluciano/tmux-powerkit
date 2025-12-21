#!/usr/bin/env bash
# =============================================================================
# Plugin: ping
# Description: Display network latency to a target host
# Dependencies: ping (built-in)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    require_cmd "ping" || return 1
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    declare_option "host" "string" "8.8.8.8" "Target host to ping"
    declare_option "count" "number" "1" "Number of ping packets"
    declare_option "timeout" "number" "2" "Ping timeout in seconds"
    declare_option "unit" "string" "ms" "Unit to display"
    declare_option "icon" "icon" $'\U000F0012' "Plugin icon"
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"
    declare_option "cache_ttl" "number" "30" "Cache duration in seconds"
    declare_option "warning_threshold" "number" "100" "Warning threshold in ms"
    declare_option "critical_threshold" "number" "300" "Critical threshold in ms"
}

plugin_init "ping"

# =============================================================================
# Ping Functions
# =============================================================================

get_ping_latency() {
    local host count timeout
    host=$(get_option "host")
    count=$(get_option "count")
    timeout=$(get_option "timeout")

    [[ -z "$host" ]] && return 1
    
    local result
    if is_macos; then
        result=$(ping -c "$count" -t "$timeout" "$host" 2>/dev/null | tail -1)
    else
        result=$(ping -c "$count" -W "$timeout" "$host" 2>/dev/null | tail -1)
    fi
    
    # Extract average latency using bash regex (avoids fork)
    # Format: round-trip min/avg/max/stddev = X.XX/Y.YY/Z.ZZ/W.WW ms
    local avg=""
    if [[ "$result" =~ ([0-9]+\.[0-9]+)/([0-9]+\.[0-9]+)/([0-9]+\.[0-9]+) ]]; then
        avg="${BASH_REMATCH[2]}"
    fi

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
    host=$(get_option "host")
    [[ -z "$host" ]] && return 0

    local cached
    if cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached"
        return 0
    fi

    local latency unit
    latency=$(get_ping_latency) || return 0
    unit=$(get_option "unit")

    local result="${latency}${unit}"
    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
