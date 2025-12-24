#!/usr/bin/env bash
# =============================================================================
# Plugin: iops
# Description: Display disk IOPS (Input/Output Operations Per Second)
# Dependencies: iostat
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "iops"
    metadata_set "name" "IOPS"
    metadata_set "version" "2.0.0"
    metadata_set "description" "Display disk IOPS"
    metadata_set "priority" "170"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_cmd "iostat" || return 1
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "device" "string" "disk0" "Disk device to monitor"
    declare_option "show_read" "bool" "true" "Show read IOPS"
    declare_option "show_write" "bool" "true" "Show write IOPS"

    # Icons
    declare_option "icon" "icon" $'\U000F0A27' "Disk icon"

    # Thresholds
    declare_option "warning_threshold" "number" "500" "Warning threshold (total IOPS)"
    declare_option "critical_threshold" "number" "1000" "Critical threshold (total IOPS)"

    # Cache - iostat takes ~1 second to collect data, so cache longer
    declare_option "cache_ttl" "number" "10" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'always'; }
plugin_get_state() { printf 'active'; }

plugin_get_health() {
    local total_iops warn_th crit_th
    total_iops=$(plugin_data_get "total_iops")
    warn_th=$(get_option "warning_threshold")
    crit_th=$(get_option "critical_threshold")

    total_iops="${total_iops:-0}"
    warn_th="${warn_th:-500}"
    crit_th="${crit_th:-1000}"

    if (( total_iops >= crit_th )); then
        printf 'error'
    elif (( total_iops >= warn_th )); then
        printf 'warning'
    else
        printf 'ok'
    fi
}

plugin_get_context() {
    local read_iops write_iops total_iops
    read_iops=$(plugin_data_get "read_iops")
    write_iops=$(plugin_data_get "write_iops")
    total_iops=$(plugin_data_get "total_iops")
    
    read_iops="${read_iops:-0}"
    write_iops="${write_iops:-0}"
    total_iops="${total_iops:-0}"
    
    if (( total_iops == 0 )); then
        printf 'idle'
    elif (( read_iops > write_iops * 2 )); then
        printf 'read_heavy'
    elif (( write_iops > read_iops * 2 )); then
        printf 'write_heavy'
    else
        printf 'balanced'
    fi
}

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# Main Logic
# =============================================================================

_get_iops() {
    local device=$(get_option "device")

    if is_macos; then
        # macOS iostat format
        local output
        output=$(iostat -c 2 -w 1 "$device" 2>/dev/null | tail -1)
        
        [[ -z "$output" ]] && return 1

        # Parse KB/t, tps (transactions per second = IOPS)
        local tps
        tps=$(echo "$output" | awk '{print $3}')
        
        printf '%.0f|%.0f' "${tps:-0}" "${tps:-0}"
    else
        # Linux iostat format
        local output
        output=$(iostat -x 1 2 "$device" 2>/dev/null | grep "$device" | tail -1)
        
        [[ -z "$output" ]] && return 1

        local r_iops w_iops
        r_iops=$(echo "$output" | awk '{print $4}')
        w_iops=$(echo "$output" | awk '{print $5}')
        
        printf '%.0f|%.0f' "${r_iops:-0}" "${w_iops:-0}"
    fi
}

plugin_collect() {
    local iops_data
    iops_data=$(_get_iops) || return 1

    IFS='|' read -r read_iops write_iops <<< "$iops_data"

    plugin_data_set "read_iops" "${read_iops:-0}"
    plugin_data_set "write_iops" "${write_iops:-0}"
    plugin_data_set "total_iops" "$((${read_iops:-0} + ${write_iops:-0}))"
}

plugin_render() {
    local show_read show_write read_iops write_iops
    show_read=$(get_option "show_read")
    show_write=$(get_option "show_write")
    read_iops=$(plugin_data_get "read_iops")
    write_iops=$(plugin_data_get "write_iops")

    local parts=()
    [[ "$show_read" == "true" ]] && parts+=("R:${read_iops}")
    [[ "$show_write" == "true" ]] && parts+=("W:${write_iops}")

    local IFS=" "
    printf '%s' "${parts[*]}"
}

