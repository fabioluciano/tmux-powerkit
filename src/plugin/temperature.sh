#!/usr/bin/env bash
# Plugin: temperature - Display CPU/system temperature with threshold colors

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "temperature"

plugin_get_type() { printf 'conditional'; }

celsius_to_fahrenheit() {
    awk "BEGIN {printf \"%.0f\", ($1 * 9/5) + 32}"
}

get_temp_thermal_zone_by_type() {
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

get_temp_hwmon_by_name() {
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

get_temp_linux_sys() {
    local thermal_zone="/sys/class/thermal/thermal_zone0/temp"
    [[ -f "$thermal_zone" ]] || return 1
    local temp_milli=$(<"$thermal_zone")
    [[ -n "$temp_milli" ]] && awk "BEGIN {printf \"%.0f\", $temp_milli / 1000}"
}

get_temp_linux_hwmon() {
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

get_temp_linux_sensors() {
    require_cmd sensors 1 || return 1
    local temp
    temp=$(sensors 2>/dev/null | grep -E "^(Package|Tctl|Tdie|CPU)" | head -1 | grep -oE '[0-9]+\.?[0-9]*' | head -1)
    [[ -z "$temp" ]] && temp=$(sensors 2>/dev/null | grep "Core 0" | grep -oE '[0-9]+\.?[0-9]*' | head -1)
    [[ -n "$temp" ]] && printf '%s' "$temp"
}

get_temperature() {
    is_macos && return 1
    
    local source
    source=$(get_cached_option "@powerkit_plugin_temperature_source" "$POWERKIT_PLUGIN_TEMPERATURE_SOURCE")
    local temp=""
    
    case "$source" in
        cpu|coretemp)
            temp=$(get_temp_hwmon_by_name "coretemp") || \
            temp=$(get_temp_hwmon_by_name "k10temp") || \
            temp=$(get_temp_hwmon_by_name "zenpower") || \
            temp=$(get_temp_thermal_zone_by_type "x86_pkg_temp") || \
            temp=$(get_temp_thermal_zone_by_type "TCPU") || \
            temp=$(get_temp_hwmon_by_name "dell_smm") || \
            temp=$(get_temp_linux_hwmon) ;;
        cpu-pkg|x86_pkg_temp)
            temp=$(get_temp_thermal_zone_by_type "x86_pkg_temp") || temp=$(get_temp_hwmon_by_name "coretemp") ;;
        cpu-acpi|tcpu)
            temp=$(get_temp_thermal_zone_by_type "TCPU") ;;
        nvme|ssd)
            temp=$(get_temp_hwmon_by_name "nvme") ;;
        wifi|wireless|iwlwifi)
            temp=$(get_temp_hwmon_by_name "iwlwifi_1") || temp=$(get_temp_thermal_zone_by_type "iwlwifi_1") ;;
        acpi|ambient|chassis)
            temp=$(get_temp_thermal_zone_by_type "INT3400 Thermal") || temp=$(get_temp_linux_sys) ;;
        dell|dell_smm)
            temp=$(get_temp_hwmon_by_name "dell_smm") || temp=$(get_temp_hwmon_by_name "dell_ddv") ;;
        auto|*)
            temp=$(get_temp_linux_hwmon) || temp=$(get_temp_linux_sys) || temp=$(get_temp_linux_sensors) ;;
    esac
    
    [[ -n "$temp" ]] && printf '%s' "$temp"
}

plugin_get_display_info() {
    local content="${1:-}"
    local show="1" accent="" accent_icon="" icon=""
    
    local value
    value=$(echo "$content" | grep -oE '[0-9]+' | head -1)
    [[ -z "$value" ]] && { build_display_info "0" "" "" ""; return; }
    
    local warning_threshold critical_threshold hide_below unit
    warning_threshold=$(get_cached_option "@powerkit_plugin_temperature_warning_threshold" "$POWERKIT_PLUGIN_TEMPERATURE_WARNING_THRESHOLD")
    critical_threshold=$(get_cached_option "@powerkit_plugin_temperature_critical_threshold" "$POWERKIT_PLUGIN_TEMPERATURE_CRITICAL_THRESHOLD")
    hide_below=$(get_cached_option "@powerkit_plugin_temperature_hide_below_threshold" "$POWERKIT_PLUGIN_TEMPERATURE_HIDE_BELOW_THRESHOLD")
    unit=$(get_cached_option "@powerkit_plugin_temperature_unit" "$POWERKIT_PLUGIN_TEMPERATURE_UNIT")
    
    [[ "$unit" == "F" ]] && {
        warning_threshold=$(celsius_to_fahrenheit "$warning_threshold")
        critical_threshold=$(celsius_to_fahrenheit "$critical_threshold")
        [[ -n "$hide_below" ]] && hide_below=$(celsius_to_fahrenheit "$hide_below")
    }
    
    # Hide if below threshold
    [[ -n "$hide_below" && "$value" -lt "$hide_below" ]] && { build_display_info "0" "" "" ""; return; }
    
    if [[ "$value" -ge "$critical_threshold" ]]; then
        accent=$(get_cached_option "@powerkit_plugin_temperature_critical_accent_color" "$POWERKIT_PLUGIN_TEMPERATURE_CRITICAL_ACCENT_COLOR")
        accent_icon=$(get_cached_option "@powerkit_plugin_temperature_critical_accent_color_icon" "$POWERKIT_PLUGIN_TEMPERATURE_CRITICAL_ACCENT_COLOR_ICON")
        icon=$(get_cached_option "@powerkit_plugin_temperature_icon_hot" "$POWERKIT_PLUGIN_TEMPERATURE_ICON_HOT")
    elif [[ "$value" -ge "$warning_threshold" ]]; then
        accent=$(get_cached_option "@powerkit_plugin_temperature_warning_accent_color" "$POWERKIT_PLUGIN_TEMPERATURE_WARNING_ACCENT_COLOR")
        accent_icon=$(get_cached_option "@powerkit_plugin_temperature_warning_accent_color_icon" "$POWERKIT_PLUGIN_TEMPERATURE_WARNING_ACCENT_COLOR_ICON")
    fi
    
    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

load_plugin() {
    is_macos && return 0
    
    local source
    source=$(get_cached_option "@powerkit_plugin_temperature_source" "$POWERKIT_PLUGIN_TEMPERATURE_SOURCE")
    local cache_key="temperature_${source}"
    
    local cached_value
    if cached_value=$(cache_get "$cache_key" "$CACHE_TTL"); then
        printf '%s' "$cached_value"
        return 0
    fi
    
    local temp
    temp=$(get_temperature)
    [[ -z "$temp" ]] && return 0
    
    local unit result
    unit=$(get_cached_option "@powerkit_plugin_temperature_unit" "$POWERKIT_PLUGIN_TEMPERATURE_UNIT")
    
    [[ "$unit" == "F" ]] && result="$(celsius_to_fahrenheit "$temp")°F" || result="${temp}°C"
    
    cache_set "$cache_key" "$result"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
