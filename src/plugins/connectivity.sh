#!/usr/bin/env bash
# =============================================================================
# Plugin: connectivity
# Description: Display internet connectivity status (online/offline)
# Dependencies: network.sh (is_endpoint_reachable)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "connectivity"
    metadata_set "name" "Connectivity"
    metadata_set "description" "Display internet connectivity status (online/offline)"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    # network.sh is already sourced via plugin_contract.sh
    has_cmd "curl" || return 1
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    declare_option "host" "string" "https://1.1.1.1" "Host to check connectivity"
    declare_option "timeout" "number" "2" "Connection timeout in seconds"
    declare_option "icon" "icon" $'\U000F059F' "Plugin icon (network)"
    declare_option "icon_offline" "icon" $'\U000F0F17' "Icon when offline"
    declare_option "cache_ttl" "number" "10" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'always'; }

plugin_get_state() { printf 'active'; }

plugin_get_health() {
    local online
    online=$(plugin_data_get "online")
    [[ "$online" == "1" ]] && printf 'good' || printf 'error'
}

plugin_get_context() {
    local online
    online=$(plugin_data_get "online")
    [[ "$online" == "1" ]] && printf 'online' || printf 'offline'
}

plugin_get_icon() {
    local online
    online=$(plugin_data_get "online")
    if [[ "$online" == "1" ]]; then
        get_option "icon"
    else
        get_option "icon_offline"
    fi
}

# =============================================================================
# Main Logic
# =============================================================================

plugin_collect() {
    local host timeout
    host=$(get_option "host")
    timeout=$(get_option "timeout")

    if is_endpoint_reachable "$host" "$timeout"; then
        plugin_data_set "online" "1"
    else
        plugin_data_set "online" "0"
    fi
}

plugin_render() {
    local online
    online=$(plugin_data_get "online")
    [[ "$online" == "1" ]] && printf 'online' || printf 'offline'
}
