#!/usr/bin/env bash
# =============================================================================
# Plugin: loadavg
# Description: Display system load average with CPU core-aware thresholds
# Type: static (custom threshold logic, no automatic colors)
# Dependencies: None (uses /proc/loadavg, sysctl, or uptime)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "format" "string" "1" "Load average format (1|5|15|all)"

    # Icons
    declare_option "icon" "icon" "󱦟" "Plugin icon"

    # Colors - Default
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Colors - Warning state
    declare_option "warning_accent_color" "color" "warning" "Background color for warning state"
    declare_option "warning_accent_color_icon" "color" "warning-subtle" "Icon background color for warning state"

    # Colors - Critical state
    declare_option "critical_accent_color" "color" "error" "Background color for critical state"
    declare_option "critical_accent_color_icon" "color" "error-subtle" "Icon background color for critical state"

    # Thresholds
    declare_option "warning_threshold_multiplier" "number" "2" "Warning threshold multiplier (times CPU cores)"
    declare_option "critical_threshold_multiplier" "number" "4" "Critical threshold multiplier (times CPU cores)"

    # Cache
    declare_option "cache_ttl" "number" "10" "Cache duration in seconds"
}

plugin_init "loadavg"

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'static'; }

plugin_get_display_info() {
    local content="${1:-}"
    local show="1" accent="" accent_icon="" icon=""

    # Cache num_cores to avoid repeated forks
    local num_cores="${_CACHED_NUM_CORES:-}"
    if [[ -z "$num_cores" ]]; then
        num_cores=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
        _CACHED_NUM_CORES="$num_cores"
    fi

    # Extract first number (load value) - convert float to int*100 for comparison
    local value
    [[ "$content" =~ ([0-9]+)\.?([0-9]*) ]] && {
        local int_part="${BASH_REMATCH[1]}"
        local dec_part="${BASH_REMATCH[2]:-0}"
        dec_part="${dec_part:0:2}"  # max 2 decimal places
        [[ ${#dec_part} -eq 1 ]] && dec_part="${dec_part}0"
        value=$((int_part * 100 + ${dec_part:-0}))
    }
    [[ -z "$value" ]] && value=0

    # Get thresholds (multiplied by cores)
    local warning_mult critical_mult
    warning_mult=$(get_option "warning_threshold_multiplier")
    critical_mult=$(get_option "critical_threshold_multiplier")

    local warning_int=$((num_cores * warning_mult * 100))
    local critical_int=$((num_cores * critical_mult * 100))

    if [[ "$value" -ge "$critical_int" ]]; then
        accent=$(get_option "critical_accent_color")
        accent_icon=$(get_option "critical_accent_color_icon")
    elif [[ "$value" -ge "$warning_int" ]]; then
        accent=$(get_option "warning_accent_color")
        accent_icon=$(get_option "warning_accent_color_icon")
    fi

    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Helper Functions
# =============================================================================

_format_loadavg() {
    local one="$1" five="$2" fifteen="$3"
    local format
    format=$(get_option "format")

    case "$format" in
        "1")  printf '%s' "$one" ;;
        "5")  printf '%s' "$five" ;;
        "15") printf '%s' "$fifteen" ;;
        *)    printf '%s %s %s' "$one" "$five" "$fifteen" ;;
    esac
}

_get_loadavg_linux() {
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

# =============================================================================
# Main Logic
# =============================================================================

_compute_loadavg() {
    local result
    if is_linux; then
        result=$(_get_loadavg_linux)
    elif is_macos; then
        result=$(_get_loadavg_macos)
    else
        result="N/A"
    fi
    printf '%s' "$result"
}

load_plugin() {
    cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_loadavg
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
