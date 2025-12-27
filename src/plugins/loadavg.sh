#!/usr/bin/env bash
# =============================================================================
# Plugin: loadavg
# Description: Display system load average with CPU core-aware thresholds
# Dependencies: None (uses /proc/loadavg, sysctl, or uptime)
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active: Load average metrics are available
#   - inactive: Unable to read load metrics
#
# Health:
#   - ok: Load is below warning threshold (cores × multiplier)
#   - warning: Load is above warning but below critical
#   - error: Load is above critical threshold
#
# Context:
#   - normal_load: Load is normal
#   - high_load: Load is elevated (warning level)
#   - critical_load: Load is critical
#
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "loadavg"
    metadata_set "name" "Load Average"
    metadata_set "description" "Display system load average with CPU core-aware thresholds"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    # No hard dependencies - uses built-in /proc/loadavg or sysctl
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "format" "string" "1" "Load average format (1|5|15|all)"
    declare_option "separator" "string" " | " "Separator between load values (for format=all)"

    # Icons
    declare_option "icon" "icon" $'\U000F199F' "Plugin icon"

    # Thresholds (multiplied by CPU cores)
    declare_option "warning_threshold_multiplier" "number" "2" "Warning threshold multiplier (times CPU cores)"
    declare_option "critical_threshold_multiplier" "number" "4" "Critical threshold multiplier (times CPU cores)"

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
    local load num_cores warning_mult critical_mult
    load=$(plugin_data_get "load_value")
    num_cores=$(plugin_data_get "num_cores")
    warning_mult=$(get_option "warning_threshold_multiplier")
    critical_mult=$(get_option "critical_threshold_multiplier")

    # Defaults
    num_cores="${num_cores:-1}"
    warning_mult="${warning_mult:-2}"
    critical_mult="${critical_mult:-4}"

    # Calculate thresholds (multiplied by cores)
    local warn_th=$((num_cores * warning_mult))
    local crit_th=$((num_cores * critical_mult))

    # Higher is worse - use float version for load average
    evaluate_threshold_health_float "${load:-0}" "$warn_th" "$crit_th"
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
# Helper Functions
# =============================================================================

_get_cpu_cores() {
    if is_macos; then
        sysctl -n hw.ncpu 2>/dev/null || echo 4
    else
        nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 4
    fi
}

_format_loadavg() {
    local one="$1" five="$2" fifteen="$3"
    local format separator
    format=$(get_option "format")
    separator=$(get_option "separator")

    case "$format" in
        "1")   printf '%s' "$one" ;;
        "5")   printf '%s' "$five" ;;
        "15")  printf '%s' "$fifteen" ;;
        "all") printf '%s%s%s%s%s' "$one" "$separator" "$five" "$separator" "$fifteen" ;;
        *)     printf '%s' "$one" ;;
    esac
}

_get_loadavg_linux() {
    local one five fifteen
    
    if [[ -r /proc/loadavg ]]; then
        read -r one five fifteen _ < /proc/loadavg
    else
        # Fallback: parse uptime output using bash regex (avoids forks)
        local uptime_out
        uptime_out=$(uptime 2>/dev/null)
        # Extract load averages from "load average: 1.23, 4.56, 7.89"
        if [[ "$uptime_out" =~ load\ average:\ ([0-9]+\.[0-9]+),\ ([0-9]+\.[0-9]+),\ ([0-9]+\.[0-9]+) ]]; then
            one="${BASH_REMATCH[1]}"
            five="${BASH_REMATCH[2]}"
            fifteen="${BASH_REMATCH[3]}"
        fi
    fi
    
    _format_loadavg "$one" "$five" "$fifteen"
}

_get_loadavg_macos() {
    local sysctl_out one five fifteen
    sysctl_out=$(sysctl -n vm.loadavg 2>/dev/null)

    if [[ -n "$sysctl_out" ]]; then
        # Output format: "{ 1.23 4.56 7.89 }" - use bash to parse
        read -r _ one five fifteen _ <<< "$sysctl_out"
    else
        # Fallback: parse uptime output using bash regex (avoids forks)
        local uptime_out
        uptime_out=$(uptime 2>/dev/null)
        # Extract load averages from "load averages: 1.23 4.56 7.89"
        if [[ "$uptime_out" =~ load\ averages?:\ ([0-9]+\.[0-9]+)\ ([0-9]+\.[0-9]+)\ ([0-9]+\.[0-9]+) ]]; then
            one="${BASH_REMATCH[1]}"
            five="${BASH_REMATCH[2]}"
            fifteen="${BASH_REMATCH[3]}"
        fi
    fi
    
    _format_loadavg "$one" "$five" "$fifteen"
}

_get_load_value() {
    # Get just the first load value for threshold comparison
    local one five fifteen
    
    if is_macos; then
        local sysctl_out
        sysctl_out=$(sysctl -n vm.loadavg 2>/dev/null)
        if [[ -n "$sysctl_out" ]]; then
            read -r _ one five fifteen _ <<< "$sysctl_out"
        fi
    elif [[ -r /proc/loadavg ]]; then
        read -r one five fifteen _ < /proc/loadavg
    fi
    
    printf '%s' "${one:-0}"
}

# =============================================================================
# Main Logic
# =============================================================================

plugin_collect() {
    local result num_cores load_value
    
    # Get CPU cores (cache for performance)
    num_cores=$(_get_cpu_cores)
    
    # Get load average based on platform
    if is_linux; then
        result=$(_get_loadavg_linux)
    elif is_macos; then
        result=$(_get_loadavg_macos)
    else
        result="N/A"
    fi
    
    # Get first load value for threshold comparison
    load_value=$(_get_load_value)
    
    plugin_data_set "result" "$result"
    plugin_data_set "num_cores" "$num_cores"
    plugin_data_set "load_value" "$load_value"
}

plugin_render() {
    local result
    result=$(plugin_data_get "result")
    printf '%s' "${result:-N/A}"
}

