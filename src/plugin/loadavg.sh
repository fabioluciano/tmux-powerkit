#!/usr/bin/env bash
# Plugin: loadavg - System load average display

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "loadavg"

plugin_get_type() { printf 'static'; }

format_loadavg() {
    local one="$1" five="$2" fifteen="$3"
    local format
    format=$(get_cached_option "@powerkit_plugin_loadavg_format" "$POWERKIT_PLUGIN_LOADAVG_FORMAT")
    
    case "$format" in
        "1")  printf '%s' "$one" ;;
        "5")  printf '%s' "$five" ;;
        "15") printf '%s' "$fifteen" ;;
        *)    printf '%s %s %s' "$one" "$five" "$fifteen" ;;
    esac
}

get_loadavg_linux() {
    if [[ -r /proc/loadavg ]]; then
        read -r one five fifteen _ < /proc/loadavg
    else
        local uptime_out
        uptime_out=$(uptime 2>/dev/null)
        one=$(echo "$uptime_out" | grep -oE '[0-9]+\.[0-9]+' | sed -n '1p')
        five=$(echo "$uptime_out" | grep -oE '[0-9]+\.[0-9]+' | sed -n '2p')
        fifteen=$(echo "$uptime_out" | grep -oE '[0-9]+\.[0-9]+' | sed -n '3p')
    fi
    format_loadavg "$one" "$five" "$fifteen"
}

get_loadavg_macos() {
    local sysctl_out one five fifteen
    sysctl_out=$(sysctl -n vm.loadavg 2>/dev/null)

    if [[ -n "$sysctl_out" ]]; then
        # Output format: "{ 1.23 4.56 7.89 }" - use bash to parse
        read -r _ one five fifteen _ <<< "$sysctl_out"
    else
        local uptime_out
        uptime_out=$(uptime 2>/dev/null)
        one=$(printf '%s' "$uptime_out" | grep -oE '[0-9]+\.[0-9]+' | sed -n '1p')
        five=$(printf '%s' "$uptime_out" | grep -oE '[0-9]+\.[0-9]+' | sed -n '2p')
        fifteen=$(printf '%s' "$uptime_out" | grep -oE '[0-9]+\.[0-9]+' | sed -n '3p')
    fi
    format_loadavg "$one" "$five" "$fifteen"
}

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
    warning_mult=$(get_cached_option "@powerkit_plugin_loadavg_warning_threshold_multiplier" "$POWERKIT_PLUGIN_LOADAVG_WARNING_THRESHOLD_MULTIPLIER")
    critical_mult=$(get_cached_option "@powerkit_plugin_loadavg_critical_threshold_multiplier" "$POWERKIT_PLUGIN_LOADAVG_CRITICAL_THRESHOLD_MULTIPLIER")

    local warning_int=$((num_cores * warning_mult * 100))
    local critical_int=$((num_cores * critical_mult * 100))

    if [[ "$value" -ge "$critical_int" ]]; then
        accent=$(get_cached_option "@powerkit_plugin_loadavg_critical_accent_color" "$POWERKIT_PLUGIN_LOADAVG_CRITICAL_ACCENT_COLOR")
        accent_icon=$(get_cached_option "@powerkit_plugin_loadavg_critical_accent_color_icon" "$POWERKIT_PLUGIN_LOADAVG_CRITICAL_ACCENT_COLOR_ICON")
    elif [[ "$value" -ge "$warning_int" ]]; then
        accent=$(get_cached_option "@powerkit_plugin_loadavg_warning_accent_color" "$POWERKIT_PLUGIN_LOADAVG_WARNING_ACCENT_COLOR")
        accent_icon=$(get_cached_option "@powerkit_plugin_loadavg_warning_accent_color_icon" "$POWERKIT_PLUGIN_LOADAVG_WARNING_ACCENT_COLOR_ICON")
    fi

    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

_compute_loadavg() {
    local result
    if is_linux; then
        result=$(get_loadavg_linux)
    elif is_macos; then
        result=$(get_loadavg_macos)
    else
        result="N/A"
    fi
    printf '%s' "$result"
}

load_plugin() {
    cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_loadavg
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
