#!/usr/bin/env bash
# =============================================================================
# Plugin: topproc
# Description: Display the process consuming most CPU
# Dependencies: ps (POSIX)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "topproc"
    metadata_set "name" "Top Process"
    metadata_set "description" "Display the process consuming most CPU"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    # ps is POSIX - available on both macOS and Linux
    has_cmd "ps" || return 1
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    declare_option "icon" "icon" $'\U000F0238' "Plugin icon (fire)"
    declare_option "warning_threshold" "number" "70" "Warning threshold (%)"
    declare_option "critical_threshold" "number" "90" "Critical threshold (%)"
    declare_option "max_length" "number" "15" "Max process name length"
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

plugin_get_state() {
    local proc_name
    proc_name=$(plugin_data_get "proc_name")
    [[ -n "$proc_name" ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() {
    local proc_pct warn_th crit_th
    proc_pct=$(plugin_data_get "proc_pct")
    warn_th=$(get_option "warning_threshold")
    crit_th=$(get_option "critical_threshold")
    
    # Use extract_numeric to handle possible decimal values
    proc_pct=$(extract_numeric "${proc_pct:-0}")
    
    evaluate_threshold_health "$proc_pct" "$warn_th" "$crit_th"
}

plugin_get_context() {
    plugin_context_from_health "$(plugin_get_health)" "top_process"
}

plugin_get_icon() {
    get_option "icon"
}

# =============================================================================
# Main Logic
# =============================================================================

plugin_collect() {
    local max_length
    max_length=$(get_option "max_length")
    
    # POSIX-compliant: ps -A -o %cpu,comm
    # Output: " 87.5 node" or " 10.2 python3"
    local result
    
    # BSD/macOS and GNU ps both support -A -o %cpu,comm
    # macOS returns full path for some procs (e.g. /usr/sbin/coreaudiod), extract basename
    result=$(ps -A -o %cpu,comm 2>/dev/null | awk 'NR>1 {print $1, $2}' | sort -rn | head -1)

    if [[ -n "$result" ]]; then
        local proc_pct proc_name

        # Parse: "87.5 /usr/sbin/coreaudiod" → proc_pct=87.5 proc_name=coreaudiod
        proc_pct=$(echo "$result" | awk '{print $1}')
        proc_name=$(echo "$result" | awk '{sub(/.*\//, "", $NF); print $NF}')

        # Truncate process name
        proc_name=$(truncate_text "$proc_name" "${max_length:-15}")

        plugin_data_set "proc_pct" "$proc_pct"
        plugin_data_set "proc_name" "$proc_name"
        return 0
    else
        return 1
    fi
}

plugin_render() {
    local proc_name proc_pct
    
    proc_name=$(plugin_data_get "proc_name")
    proc_pct=$(plugin_data_get "proc_pct")
    
    printf '%s %s%%' "$proc_name" "$proc_pct"
}
