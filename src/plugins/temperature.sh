#!/usr/bin/env bash
# =============================================================================
# Plugin: temperature
# Description: Display CPU/system temperature with threshold colors
# Type: conditional (can hide when below threshold or unavailable)
# Dependencies: sensors (Linux - optional), powerkit-temperature binary (macOS)
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active: Temperature sensor available
#   - inactive: No temperature sensor available
#
# Health:
#   - ok: Temperature below warning threshold
#   - warning: Temperature at warning level
#   - error: Temperature at critical level
#
# Context:
#   - normal: Temperature is normal
#   - warm: Temperature is elevated (warning)
#   - hot: Temperature is critical
#
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "temperature"
    metadata_set "name" "Temperature"
    metadata_set "description" "Display CPU/system temperature with threshold support"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    if is_linux; then
        require_cmd "sensors" 1  # Optional, can use sysfs
    elif is_macos; then
        # macOS: prefer native binary (downloaded on-demand from releases)
        # Falls back to osx-cpu-temp/smctemp/iStats if binary not available
        require_macos_binary "powerkit-temperature" "temperature" || true
    fi
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    # Linux sources: auto|cpu|cpu-pkg|cpu-acpi|nvme|wifi|acpi|dell
    # macOS sources: auto|cpu-cluster|gpu|soc|battery|wifi or specific SMC key (e.g., Tp0f, TC0P)
    # Use 'powerkit-temperature -l' to list available sensors on macOS
    declare_option "source" "string" "auto" "Temperature source (auto, or SMC key like Tp0f, TC0P)"
    declare_option "unit" "string" "C" "Temperature unit (C or F)"
    declare_option "show_unit" "bool" "true" "Show unit symbol (°C/°F)"
    declare_option "hide_below_threshold" "number" "" "Hide plugin when temp is below this value (°C)"

    # Icons
    declare_option "icon" "icon" $'\U0000F2CB' "Plugin icon"
    declare_option "icon_warning" "icon" $'\U0000F2C9' "Icon for warning temperature"
    declare_option "icon_hot" "icon" $'\U0000EF2A' "Icon for critical temperature"

    # Thresholds (in Celsius, higher = worse)
    declare_option "warning_threshold" "number" "70" "Warning threshold in °C"
    declare_option "critical_threshold" "number" "85" "Critical threshold in °C"

    # Note: show_only_on_threshold is auto-injected globally

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

# =============================================================================
# Temperature Conversion
# =============================================================================

_celsius_to_fahrenheit() {
    local c="$1"
    awk "BEGIN {printf \"%.0f\", ($c * 9/5) + 32}"
}

# =============================================================================
# Linux Temperature Detection
# =============================================================================

# Get temperature from thermal_zone by type
_get_temp_thermal_zone_by_type() {
    local zone_type="$1"

    for zone in /sys/class/thermal/thermal_zone*; do
        [[ -f "$zone/type" ]] || continue
        [[ "$(<"$zone/type")" == "$zone_type" ]] || continue
        [[ -f "$zone/temp" ]] || continue

        local temp_milli
        temp_milli=$(<"$zone/temp")
        [[ -n "$temp_milli" && "$temp_milli" =~ ^[0-9]+$ ]] && {
            awk "BEGIN {printf \"%.0f\", $temp_milli / 1000}"
            return 0
        }
    done
    return 1
}

# Get temperature from hwmon by name
_get_temp_hwmon_by_name() {
    local sensor_name="$1"

    for dir in /sys/class/hwmon/hwmon*; do
        [[ -f "$dir/name" && "$(<"$dir/name")" == "$sensor_name" ]] || continue

        for temp_file in "$dir"/temp*_input; do
            [[ -f "$temp_file" ]] || continue
            local temp_milli
            temp_milli=$(<"$temp_file")
            [[ -n "$temp_milli" && "$temp_milli" =~ ^[0-9]+$ ]] && {
                awk "BEGIN {printf \"%.0f\", $temp_milli / 1000}"
                return 0
            }
        done
    done
    return 1
}

# Generic thermal_zone0 fallback
_get_temp_linux_sys() {
    local thermal_zone="/sys/class/thermal/thermal_zone0/temp"
    [[ -f "$thermal_zone" ]] || return 1

    local temp_milli
    temp_milli=$(<"$thermal_zone")
    [[ -n "$temp_milli" && "$temp_milli" =~ ^[0-9]+$ ]] && \
        awk "BEGIN {printf \"%.0f\", $temp_milli / 1000}"
}

# Auto-detect from hwmon (coretemp, k10temp, zenpower)
_get_temp_linux_hwmon() {
    for dir in /sys/class/hwmon/hwmon*; do
        [[ -f "$dir/name" ]] || continue
        local name
        name=$(<"$dir/name")
        [[ "$name" =~ ^(coretemp|k10temp|zenpower)$ ]] || continue

        for temp in "$dir"/temp*_input; do
            [[ -f "$temp" ]] || continue
            local temp_milli
            temp_milli=$(<"$temp")
            [[ -n "$temp_milli" && "$temp_milli" =~ ^[0-9]+$ ]] && {
                awk "BEGIN {printf \"%.0f\", $temp_milli / 1000}"
                return 0
            }
        done
    done
    return 1
}

# Use sensors command
_get_temp_linux_sensors() {
    has_cmd sensors || return 1

    local temp
    # Try common patterns
    temp=$(sensors 2>/dev/null | grep -E "^(Package|Tctl|Tdie|CPU)" | head -1 | grep -oE '[0-9]+\.?[0-9]*' | head -1)
    [[ -z "$temp" ]] && temp=$(sensors 2>/dev/null | grep "Core 0" | grep -oE '[0-9]+\.?[0-9]*' | head -1)

    [[ -n "$temp" ]] && printf '%.0f' "$temp"
}

# Linux entry point with source selection
_get_temp_linux() {
    local source="$1"
    local temp=""

    case "$source" in
        cpu|coretemp)
            temp=$(_get_temp_hwmon_by_name "coretemp") ||
            temp=$(_get_temp_hwmon_by_name "k10temp") ||
            temp=$(_get_temp_hwmon_by_name "zenpower") ||
            temp=$(_get_temp_thermal_zone_by_type "x86_pkg_temp") ||
            temp=$(_get_temp_thermal_zone_by_type "TCPU") ||
            temp=$(_get_temp_hwmon_by_name "dell_smm") ||
            temp=$(_get_temp_linux_hwmon)
            ;;
        cpu-pkg|x86_pkg_temp)
            temp=$(_get_temp_thermal_zone_by_type "x86_pkg_temp") ||
            temp=$(_get_temp_hwmon_by_name "coretemp")
            ;;
        cpu-acpi|tcpu)
            temp=$(_get_temp_thermal_zone_by_type "TCPU")
            ;;
        nvme|ssd)
            temp=$(_get_temp_hwmon_by_name "nvme")
            ;;
        wifi|wireless|iwlwifi)
            temp=$(_get_temp_hwmon_by_name "iwlwifi_1") ||
            temp=$(_get_temp_thermal_zone_by_type "iwlwifi_1")
            ;;
        acpi|ambient|chassis)
            temp=$(_get_temp_thermal_zone_by_type "INT3400 Thermal") ||
            temp=$(_get_temp_linux_sys)
            ;;
        dell|dell_smm)
            temp=$(_get_temp_hwmon_by_name "dell_smm") ||
            temp=$(_get_temp_hwmon_by_name "dell_ddv")
            ;;
        auto|*)
            temp=$(_get_temp_linux_hwmon) ||
            temp=$(_get_temp_linux_sys) ||
            temp=$(_get_temp_linux_sensors)
            ;;
    esac

    [[ -n "$temp" ]] && printf '%s' "$temp"
}

# =============================================================================
# macOS Temperature Detection
# =============================================================================

_get_temp_macos() {
    local source="$1"
    local temp
    local powerkit_temp="${POWERKIT_ROOT}/bin/powerkit-temperature"

    # Try powerkit-temperature first (works on Apple Silicon and Intel)
    if [[ -x "$powerkit_temp" ]]; then
        case "$source" in
            auto|"")
                # Default: highest temperature
                temp=$("$powerkit_temp" 2>/dev/null)
                ;;
            cpu-cluster|cpu)
                # CPU cluster (P-Cluster for Apple Silicon)
                temp=$("$powerkit_temp" -s Tp0f 2>/dev/null)
                [[ -z "$temp" || "$temp" == "-1" ]] && temp=$("$powerkit_temp" -s TC0P 2>/dev/null)
                ;;
            gpu)
                # GPU
                temp=$("$powerkit_temp" -s Tg0j 2>/dev/null)
                [[ -z "$temp" || "$temp" == "-1" ]] && temp=$("$powerkit_temp" -s TG0D 2>/dev/null)
                ;;
            soc)
                # SoC (Apple Silicon only)
                temp=$("$powerkit_temp" -s Ts0S 2>/dev/null)
                ;;
            battery)
                # Battery
                temp=$("$powerkit_temp" -s TB0T 2>/dev/null)
                ;;
            wifi)
                # WiFi module
                temp=$("$powerkit_temp" -s TW0P 2>/dev/null)
                ;;
            *)
                # Specific SMC key (e.g., Tp0f, TC0P)
                temp=$("$powerkit_temp" -s "$source" 2>/dev/null)
                ;;
        esac
        [[ -n "$temp" && "$temp" =~ ^[0-9]+$ ]] && { printf '%s' "$temp"; return 0; }
    fi

    # Fallback: Try osx-cpu-temp (Intel only)
    if has_cmd osx-cpu-temp; then
        local output
        output=$(osx-cpu-temp 2>/dev/null)
        # Output format: "XX.X°C"
        temp="${output%%°*}"
        [[ -n "$temp" ]] && { printf '%.0f' "$temp" 2>/dev/null; return 0; }
    fi

    # Fallback: Try smctemp
    if has_cmd smctemp; then
        temp=$(smctemp -c 2>/dev/null | head -1)
        [[ -n "$temp" ]] && { printf '%.0f' "$temp" 2>/dev/null; return 0; }
    fi

    return 1
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    local temp source

    source=$(get_option "source")

    if is_linux; then
        temp=$(_get_temp_linux "$source")
    elif is_macos; then
        temp=$(_get_temp_macos "$source")
    fi

    if [[ -n "$temp" && "$temp" =~ ^[0-9]+$ ]]; then
        plugin_data_set "temp_c" "$temp"
        plugin_data_set "available" "1"
    else
        plugin_data_set "temp_c" "0"
        plugin_data_set "available" "0"
    fi
}

# =============================================================================
# Plugin Contract: Type and Presence
# =============================================================================

plugin_get_content_type() {
    printf 'dynamic'
}

plugin_get_presence() {
    printf 'conditional'
}

# =============================================================================
# Plugin Contract: State
# =============================================================================

plugin_get_state() {
    local available
    available=$(plugin_data_get "available")
    [[ "$available" == "1" ]] && printf 'active' || printf 'inactive'
}

# =============================================================================
# Plugin Contract: Health
# =============================================================================

plugin_get_health() {
    local temp warn_th crit_th
    temp=$(plugin_data_get "temp_c")
    warn_th=$(get_option "warning_threshold")
    crit_th=$(get_option "critical_threshold")

    # Higher is worse (default behavior)
    evaluate_threshold_health "${temp:-0}" "${warn_th:-70}" "${crit_th:-85}"
}

# =============================================================================
# Plugin Contract: Context
# =============================================================================

plugin_get_context() {
    local health
    health=$(plugin_get_health)

    case "$health" in
        error)   printf 'hot' ;;
        warning) printf 'warm' ;;
        *)       printf 'normal' ;;
    esac
}

# =============================================================================
# Plugin Contract: Icon
# =============================================================================

plugin_get_icon() {
    local health icon_warn icon_hot

    health=$(plugin_get_health)
    icon_warn=$(get_option "icon_warning")
    icon_hot=$(get_option "icon_hot")

    case "$health" in
        error)
            [[ -n "$icon_hot" ]] && printf '%s' "$icon_hot" || get_option "icon"
            return
            ;;
        warning)
            [[ -n "$icon_warn" ]] && printf '%s' "$icon_warn" || get_option "icon"
            return
            ;;
        *)
            get_option "icon"
            return
            ;;
    esac
}

# =============================================================================
# Plugin Contract: Render
# =============================================================================

plugin_render() {
    local temp_c unit show_unit hide_below
    temp_c=$(plugin_data_get "temp_c")
    unit=$(get_option "unit")
    show_unit=$(get_option "show_unit")
    hide_below=$(get_option "hide_below_threshold")

    [[ -z "$temp_c" || "$temp_c" == "0" ]] && return

    # Convert thresholds if using Fahrenheit
    local display_temp="$temp_c"
    local unit_symbol="°C"
    local hide_below_converted="$hide_below"

    if [[ "$unit" == "F" ]]; then
        display_temp=$(_celsius_to_fahrenheit "$temp_c")
        unit_symbol="°F"
        [[ -n "$hide_below" ]] && hide_below_converted=$(_celsius_to_fahrenheit "$hide_below")
    fi

    # Hide if below threshold (plugin-specific behavior)
    if [[ -n "$hide_below_converted" && "$display_temp" -lt "$hide_below_converted" ]]; then
        return  # Output nothing
    fi

    # Note: show_only_on_threshold is handled by renderer via health

    # Format output
    if [[ "$show_unit" == "true" ]]; then
        printf '%s%s' "$display_temp" "$unit_symbol"
    else
        printf '%s' "$display_temp"
    fi
}

# =============================================================================
# Initialize Plugin
# =============================================================================

