#!/usr/bin/env bash
# =============================================================================
# Plugin: uptime
# Description: Display system uptime
# Contract-based plugin (PowerKit)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"


plugin_get_metadata() {
    metadata_set "id" "uptime"
    metadata_set "name" "Uptime"
    metadata_set "description" "Display system uptime"
}

plugin_declare_options() {
    declare_option "icon" "icon" $'\uf254' "Plugin icon"

    # Cache - uptime changes slowly, no need for frequent updates
    declare_option "cache_ttl" "number" "300" "Cache duration in seconds"
}


plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'always'; }
plugin_get_state() { printf 'active'; }
plugin_get_health() { printf 'ok'; }

plugin_get_context() {
    local uptime_str=$(plugin_data_get "uptime")
    # Parse uptime to determine category
    if [[ "$uptime_str" == *d* ]]; then
        printf 'days'
    elif [[ "$uptime_str" == *h* ]]; then
        printf 'hours'
    else
        printf 'minutes'
    fi
}

plugin_collect() {
    local uptime_seconds=0
        if is_linux && [[ -r /proc/uptime ]]; then
            uptime_seconds=$(awk '{printf "%d", $1}' /proc/uptime 2>/dev/null)
        elif is_macos; then
            # macOS: use sysctl to get boot time (campo 'sec')
            local boot_time now=$EPOCHSECONDS
            boot_time=$(sysctl -n kern.boottime | awk '{gsub(",", "", $4); print $4}')
            ((uptime_seconds=now-boot_time))
    else
        # Fallback: parse uptime output
        uptime_seconds=$(uptime | awk -F'( |,|:)+' '{if ($7=="min") print $6*60; else if ($7=="hrs") print $6*3600; else print 0}')
    fi
    plugin_data_set "uptime" "$(format_uptime_seconds "$uptime_seconds")"
}

plugin_render() {
    plugin_data_get "uptime"
}

plugin_get_icon() {
    get_option "icon"
}
