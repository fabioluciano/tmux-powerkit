#!/usr/bin/env bash
# =============================================================================
# Plugin: loadavg
# Description: Display system load average
# Dependencies: uptime (built-in)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "loadavg"
    metadata_set "name" "Load Average"
    metadata_set "description" "Display system load average"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_cmd "uptime" || return 1
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "period" "string" "1" "Load average period: 1, 5, or 15 minutes"
    declare_option "show_cores" "bool" "true" "Show number of CPU cores"

    # Icons
    declare_option "icon" "icon" $'\U000F0EE7' "Plugin icon"

    # Thresholds (based on number of cores)
    declare_option "warning_multiplier" "number" "0.7" "Warning threshold (cores * multiplier)"
    declare_option "critical_multiplier" "number" "1.0" "Critical threshold (cores * multiplier)"

    # Cache
    declare_option "cache_ttl" "number" "10" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'always'; }
plugin_get_state() { printf 'active'; }

plugin_get_health() {
    local load cores warn_th crit_th
    load=$(plugin_data_get "load")
    cores=$(plugin_data_get "cores")
    
    warn_th=$(get_option "warning_multiplier")
    crit_th=$(get_option "critical_multiplier")

    load="${load:-0}"
    cores="${cores:-1}"
    warn_th="${warn_th:-0.7}"
    crit_th="${crit_th:-1.0}"

    local warn_level=$(awk "BEGIN {printf \"%.2f\", $cores * $warn_th}")
    local crit_level=$(awk "BEGIN {printf \"%.2f\", $cores * $crit_th}")

    if (( $(awk "BEGIN {print ($load >= $crit_level)}") )); then
        printf 'error'
    elif (( $(awk "BEGIN {print ($load >= $warn_level)}") )); then
        printf 'warning'
    else
        printf 'ok'
    fi
}

plugin_get_context() {
    local health
    health=$(plugin_get_health)

    case "$health" in
        error)   printf 'critical_load' ;;
        warning) printf 'high_load' ;;
        *)       printf 'normal_load' ;;
    esac
}

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# Main Logic
# =============================================================================

_get_load_average() {
    local period=$(get_option "period")
    local output
    
    if is_macos; then
        output=$(sysctl -n vm.loadavg 2>/dev/null)
        # Output: { 2.50 2.30 2.10 }
        output="${output#\{ }"
        output="${output% \}}"
    else
        output=$(cat /proc/loadavg 2>/dev/null)
    fi

    [[ -z "$output" ]] && return 1

    local load1 load5 load15
    read -r load1 load5 load15 _ <<< "$output"

    case "$period" in
        1) printf '%s' "$load1" ;;
        5) printf '%s' "$load5" ;;
        15) printf '%s' "$load15" ;;
        *) printf '%s' "$load1" ;;
    esac
}

_get_cpu_cores() {
    if is_macos; then
        sysctl -n hw.ncpu 2>/dev/null
    else
        nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null
    fi
}

plugin_collect() {
    local load cores
    load=$(_get_load_average)
    cores=$(_get_cpu_cores)

    plugin_data_set "load" "${load:-0}"
    plugin_data_set "cores" "${cores:-1}"
}

plugin_render() {
    local load cores show_cores
    load=$(plugin_data_get "load")
    cores=$(plugin_data_get "cores")
    show_cores=$(get_option "show_cores")

    [[ "$show_cores" == "true" ]] && printf '%s/%s' "$load" "$cores" || printf '%s' "$load"
}

