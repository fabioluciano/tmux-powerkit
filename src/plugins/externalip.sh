#!/usr/bin/env bash
# =============================================================================
# Plugin: externalip
# Description: Display external (public) IP address
# Type: conditional (hidden when offline)
# Dependencies: curl
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "externalip"
    metadata_set "name" "External IP"
    metadata_set "description" "Display external (public) IP address"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_cmd "curl" || return 1
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Icons
    declare_option "icon" "icon" $'\U000F0A5F' "Plugin icon"

    # Cache
    declare_option "cache_ttl" "number" "600" "Cache duration in seconds (10 minutes)"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

plugin_get_state() {
    local ip=$(plugin_data_get "ip")
    [[ -n "$ip" ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() { printf 'ok'; }

plugin_get_context() {
    local ip=$(plugin_data_get "ip")
    [[ -n "$ip" ]] && printf 'online' || printf 'offline'
}

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# Main Logic
# =============================================================================

plugin_collect() {
    local ip
    ip=$(safe_curl "https://api.ipify.org" 3)
    plugin_data_set "ip" "$ip"
}

plugin_render() {
    local ip=$(plugin_data_get "ip")
    [[ -n "$ip" ]] && printf '%s' "$ip" || printf 'N/A'
}

