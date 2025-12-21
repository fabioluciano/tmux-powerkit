#!/usr/bin/env bash
# =============================================================================
# Plugin: temperature
# Description: Display CPU/system temperature with threshold colors
# Type: conditional (hides when below threshold or when temp unavailable)
# Dependencies: sensors (Linux), osx-cpu-temp/smctemp (macOS - optional)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    if is_linux; then
        require_cmd "sensors" || return 1
    fi
    if is_macos; then
        require_any_cmd "osx-cpu-temp" "smctemp" 1  # Optional
    fi
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "source" "string" "auto" "Temperature source (auto, cpu, cpu-pkg, cpu-acpi, nvme, wifi, acpi, dell)"
    declare_option "unit" "string" "C" "Temperature unit (C or F)"
    declare_option "hide_below_threshold" "number" "" "Hide plugin when temperature is below this value"

    # Icons
    declare_option "icon" "icon" $'\U000F02C7' "Plugin icon"
    declare_option "icon_hot" "icon" "󱃂" "Icon for high temperature"

    # Colors - Default
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Colors - Warning state
    declare_option "warning_accent_color" "color" "warning" "Background color for warning state"
    declare_option "warning_accent_color_icon" "color" "warning-strong" "Icon background color for warning state"

    # Colors - Critical state
    declare_option "critical_accent_color" "color" "error" "Background color for critical state"
    declare_option "critical_accent_color_icon" "color" "error-strong" "Icon background color for critical state"

    # Thresholds
    declare_option "warning_threshold" "number" "70" "Warning threshold in Celsius"
    declare_option "critical_threshold" "number" "85" "Critical threshold in Celsius"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

plugin_init "temperature"

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="${1:-}"
    local show="1" accent="" accent_icon="" icon=""

    # Use bash regex instead of echo | grep (performance: avoids fork)
    local value=""
    [[ "$content" =~ ([0-9]+) ]] && value="${BASH_REMATCH[1]}"
    [[ -z "$value" ]] && { build_display_info "0" "" "" ""; return; }

    local warning_threshold critical_threshold hide_below unit
    warning_threshold=$(get_option "warning_threshold")
    critical_threshold=$(get_option "critical_threshold")
    hide_below=$(get_option "hide_below_threshold")
    unit=$(get_option "unit")

    [[ "$unit" == "F" ]] && {
        warning_threshold=$(_celsius_to_fahrenheit "$warning_threshold")
        critical_threshold=$(_celsius_to_fahrenheit "$critical_threshold")
        [[ -n "$hide_below" ]] && hide_below=$(_celsius_to_fahrenheit "$hide_below")
    }

    # Hide if below threshold
    [[ -n "$hide_below" && "$value" -lt "$hide_below" ]] && { build_display_info "0" "" "" ""; return; }

    if [[ "$value" -ge "$critical_threshold" ]]; then
        accent=$(get_option "critical_accent_color")
        accent_icon=$(get_option "critical_accent_color_icon")
        icon=$(get_option "icon_hot")
    elif [[ "$value" -ge "$warning_threshold" ]]; then
        accent=$(get_option "warning_accent_color")
        accent_icon=$(get_option "warning_accent_color_icon")
    fi

    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Helper Functions
# =============================================================================

_celsius_to_fahrenheit() {
    awk "BEGIN {printf \"%.0f\", ($1 * 9/5) + 32}"
}

_get_temp_thermal_zone_by_type() {
    local zone_type="$1"
    for zone in /sys/class/thermal/thermal_zone*; do
        [[ -f "$zone/type" ]] || continue
        [[ "$(<"$zone/type")" == "$zone_type" ]] || continue
        [[ -f "$zone/temp" ]] || continue
        local temp_milli=$(<"$zone/temp")
        [[ -n "$temp_milli" ]] && { awk "BEGIN {printf \"%.0f\", $temp_milli / 1000}"; return 0; }
    done
    return 1
}

_get_temp_hwmon_by_name() {
    local sensor_name="$1"
    for dir in /sys/class/hwmon/hwmon*; do
        [[ -f "$dir/name" && "$(<"$dir/name")" == "$sensor_name" ]] || continue
        for temp_file in "$dir"/temp*_input; do
            [[ -f "$temp_file" ]] || continue
            local temp_milli=$(<"$temp_file")
            [[ -n "$temp_milli" ]] && { awk "BEGIN {printf \"%.0f\", $temp_milli / 1000}"; return 0; }
        done
    done
    return 1
}

_get_temp_linux_sys() {
    local thermal_zone="/sys/class/thermal/thermal_zone0/temp"
    [[ -f "$thermal_zone" ]] || return 1
    local temp_milli=$(<"$thermal_zone")
    [[ -n "$temp_milli" ]] && awk "BEGIN {printf \"%.0f\", $temp_milli / 1000}"
}

_get_temp_linux_hwmon() {
    for dir in /sys/class/hwmon/hwmon*; do
        [[ -f "$dir/name" ]] || continue
        local name=$(<"$dir/name")
        [[ "$name" =~ ^(coretemp|k10temp|zenpower)$ ]] || continue
        for temp in "$dir"/temp*_input; do
            [[ -f "$temp" ]] || continue
            local temp_milli=$(<"$temp")
            awk "BEGIN {printf \"%.0f\", $temp_milli / 1000}"
            return 0
        done
    done
    return 1
}

_get_temp_linux_sensors() {
    has_cmd sensors || return 1
    local temp
    temp=$(sensors 2>/dev/null | grep -E "^(Package|Tctl|Tdie|CPU)" | head -1 | grep -oE '[0-9]+\.?[0-9]*' | head -1)
    [[ -z "$temp" ]] && temp=$(sensors 2>/dev/null | grep "Core 0" | grep -oE '[0-9]+\.?[0-9]*' | head -1)
    [[ -n "$temp" ]] && printf '%s' "$temp"
}

_get_temperature() {
    is_macos && return 1

    local source
    source=$(get_option "source")
    local temp=""

    case "$source" in
        cpu|coretemp)
            temp=$(_get_temp_hwmon_by_name "coretemp") || \
            temp=$(_get_temp_hwmon_by_name "k10temp") || \
            temp=$(_get_temp_hwmon_by_name "zenpower") || \
            temp=$(_get_temp_thermal_zone_by_type "x86_pkg_temp") || \
            temp=$(_get_temp_thermal_zone_by_type "TCPU") || \
            temp=$(_get_temp_hwmon_by_name "dell_smm") || \
            temp=$(_get_temp_linux_hwmon) ;;
        cpu-pkg|x86_pkg_temp)
            temp=$(_get_temp_thermal_zone_by_type "x86_pkg_temp") || temp=$(_get_temp_hwmon_by_name "coretemp") ;;
        cpu-acpi|tcpu)
            temp=$(_get_temp_thermal_zone_by_type "TCPU") ;;
        nvme|ssd)
            temp=$(_get_temp_hwmon_by_name "nvme") ;;
        wifi|wireless|iwlwifi)
            temp=$(_get_temp_hwmon_by_name "iwlwifi_1") || temp=$(_get_temp_thermal_zone_by_type "iwlwifi_1") ;;
        acpi|ambient|chassis)
            temp=$(_get_temp_thermal_zone_by_type "INT3400 Thermal") || temp=$(_get_temp_linux_sys) ;;
        dell|dell_smm)
            temp=$(_get_temp_hwmon_by_name "dell_smm") || temp=$(_get_temp_hwmon_by_name "dell_ddv") ;;
        auto|*)
            temp=$(_get_temp_linux_hwmon) || temp=$(_get_temp_linux_sys) || temp=$(_get_temp_linux_sensors) ;;
    esac

    [[ -n "$temp" ]] && printf '%s' "$temp"
}

# =============================================================================
# Main Logic
# =============================================================================

load_plugin() {
    is_macos && return 0

    local source
    source=$(get_option "source")
    local cache_key="temperature_${source}"

    local cached_value
    if cached_value=$(cache_get "$cache_key" "$CACHE_TTL"); then
        printf '%s' "$cached_value"
        return 0
    fi

    local temp
    temp=$(_get_temperature)
    [[ -z "$temp" ]] && return 0

    local unit result
    unit=$(get_option "unit")

    [[ "$unit" == "F" ]] && result="$(_celsius_to_fahrenheit "$temp")°F" || result="${temp}°C"

    cache_set "$cache_key" "$result"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
