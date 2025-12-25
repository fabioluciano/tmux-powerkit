#!/usr/bin/env bash
# =============================================================================
# Plugin: ping
# Description: Display network latency to a target host
# Dependencies: ping (built-in)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "ping"
    metadata_set "name" "Ping"
    metadata_set "description" "Display network latency to a target host"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_cmd "ping" || return 1
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Network options
    declare_option "host" "string" "8.8.8.8" "Target host to ping"
    declare_option "count" "number" "1" "Number of ping packets"
    declare_option "timeout" "number" "2" "Ping timeout in seconds"
    declare_option "unit" "string" "ms" "Unit to display"

    # Icons
    declare_option "icon" "icon" $'\U000F0012' "Plugin icon"

    # Thresholds
    declare_option "warning_threshold" "number" "100" "Warning threshold in ms"
    declare_option "critical_threshold" "number" "300" "Critical threshold in ms"

    # Cache
    declare_option "cache_ttl" "number" "30" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

plugin_get_state() {
    local latency=$(plugin_data_get "latency")
    [[ -n "$latency" && "$latency" != "-1" ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() {
    local latency warn_th crit_th
    latency=$(plugin_data_get "latency")
    warn_th=$(get_option "warning_threshold")
    crit_th=$(get_option "critical_threshold")

    latency="${latency:-0}"
    warn_th="${warn_th:-100}"
    crit_th="${crit_th:-300}"

    if (( latency >= crit_th )); then
        printf 'error'
    elif (( latency >= warn_th )); then
        printf 'warning'
    else
        printf 'ok'
    fi
}

plugin_get_context() {
    local latency=$(plugin_data_get "latency")
    latency="${latency:--1}"
    
    if [[ "$latency" == "-1" ]]; then
        printf 'unreachable'
    elif (( latency < 50 )); then
        printf 'excellent'
    elif (( latency < 100 )); then
        printf 'good'
    elif (( latency < 200 )); then
        printf 'fair'
    else
        printf 'poor'
    fi
}

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# Main Logic
# =============================================================================

_get_ping_latency() {
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

    # Extract average latency: round-trip min/avg/max/stddev = X.XX/Y.YY/Z.ZZ/W.WW ms
    local avg=""
    if [[ "$result" =~ ([0-9]+\.[0-9]+)/([0-9]+\.[0-9]+)/([0-9]+\.[0-9]+) ]]; then
        avg="${BASH_REMATCH[2]}"
    fi

    [[ -z "$avg" ]] && return 1

    # Round to integer
    printf '%.0f' "$avg"
}

plugin_collect() {
    local host=$(get_option "host")
    [[ -z "$host" ]] && return 0

    local latency
    latency=$(_get_ping_latency) || latency="-1"

    plugin_data_set "latency" "$latency"
}

plugin_render() {
    local latency unit
    latency=$(plugin_data_get "latency")
    unit=$(get_option "unit")

    [[ "$latency" == "-1" || -z "$latency" ]] && { printf 'N/A'; return; }

    printf '%s%s' "$latency" "$unit"
}

