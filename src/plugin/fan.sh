#!/usr/bin/env bash
# =============================================================================
# Plugin: fan
# Description: Display fan speed (RPM) for system cooling fans
# Dependencies: None (uses sysfs on Linux, osx-cpu-temp/smctemp on macOS)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "fan"

# =============================================================================
# Fan Speed Functions
# =============================================================================

get_fan_hwmon() {
    # Linux: Read from hwmon subsystem (first non-zero fan)
    for dir in /sys/class/hwmon/hwmon*; do
        [[ -d "$dir" ]] || continue
        for fan_file in "$dir"/fan*_input; do
            [[ -f "$fan_file" ]] || continue
            local rpm
            rpm=$(<"$fan_file")
            [[ -n "$rpm" && "$rpm" -gt 0 ]] && { printf '%s' "$rpm"; return 0; }
        done
    done
    return 1
}

get_all_fans_hwmon() {
    # Get all fans from hwmon subsystem
    local hide_idle="$1"
    local fans=()

    for dir in /sys/class/hwmon/hwmon*; do
        [[ -d "$dir" ]] || continue
        for fan_file in "$dir"/fan*_input; do
            [[ -f "$fan_file" ]] || continue
            local rpm
            rpm=$(<"$fan_file")
            [[ -z "$rpm" ]] && continue
            [[ "$hide_idle" == "true" && "$rpm" -eq 0 ]] && continue
            fans+=("$rpm")
        done
    done

    printf '%s\n' "${fans[@]}"
}

get_fan_dell() {
    for dir in /sys/class/hwmon/hwmon*; do
        [[ -f "$dir/name" && "$(<"$dir/name")" == "dell_smm" ]] || continue
        for fan in "$dir"/fan*_input; do
            [[ -f "$fan" ]] || continue
            local rpm
            rpm=$(<"$fan")
            [[ -n "$rpm" && "$rpm" -gt 0 ]] && { printf '%s' "$rpm"; return 0; }
        done
    done
    return 1
}

get_fan_thinkpad() {
    local fan_file="/proc/acpi/ibm/fan"
    [[ -f "$fan_file" ]] || return 1
    local rpm
    rpm=$(awk '/^speed:/ {print $2}' "$fan_file" 2>/dev/null)
    [[ -n "$rpm" && "$rpm" -gt 0 ]] && { printf '%s' "$rpm"; return 0; }
    return 1
}

get_fan_macos() {
    # osx-cpu-temp (most common)
    if require_cmd osx-cpu-temp 1; then
        local output rpm
        output=$(osx-cpu-temp -f 2>/dev/null)
        if [[ "$output" != *"Num fans: 0"* ]]; then
            rpm=$(printf '%s' "$output" | grep -oE '[0-9]+ RPM' | head -1 | grep -oE '[0-9]+')
            [[ -n "$rpm" && "$rpm" -gt 0 ]] && { printf '%s' "$rpm"; return 0; }
        fi
    fi

    # smctemp fallback
    if require_cmd smctemp 1; then
        local rpm
        rpm=$(smctemp -f 2>/dev/null | grep -oE '[0-9]+' | head -1)
        [[ -n "$rpm" && "$rpm" -gt 0 ]] && { printf '%s' "$rpm"; return 0; }
    fi

    return 1
}

get_fan_speed() {
    local source
    source=$(get_cached_option "@powerkit_plugin_fan_source" "$POWERKIT_PLUGIN_FAN_SOURCE")

    case "$source" in
        dell)     get_fan_dell ;;
        thinkpad) get_fan_thinkpad ;;
        hwmon)    get_fan_hwmon ;;
        *)
            if is_macos; then
                get_fan_macos
            else
                get_fan_dell || get_fan_thinkpad || get_fan_hwmon
            fi
            ;;
    esac
}

format_rpm() {
    local rpm="$1"
    local format
    format=$(get_cached_option "@powerkit_plugin_fan_format" "$POWERKIT_PLUGIN_FAN_FORMAT")

    case "$format" in
        krpm) awk "BEGIN {printf \"%.1fk\", $rpm / 1000}" ;;
        full) printf '%s RPM' "$rpm" ;;
        *)    printf '%s' "$rpm" ;;
    esac
}

# =============================================================================
# Plugin Interface
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="${1:-}"
    local show="1" accent="" accent_icon="" icon=""

    [[ -z "$content" ]] && { build_display_info "0" "" "" ""; return; }

    local value threshold_result
    value=$(extract_numeric "$content")
    [[ -z "$value" ]] && { build_display_info "0" "" "" ""; return; }

    # Apply threshold colors using centralized helper
    if threshold_result=$(apply_threshold_colors "$value" "fan"); then
        accent="${threshold_result%%:*}"
        accent_icon="${threshold_result#*:}"
        icon=$(get_cached_option "@powerkit_plugin_fan_icon_fast" "$POWERKIT_PLUGIN_FAN_ICON_FAST")
    fi

    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Main
# =============================================================================

load_plugin() {
    local cached
    if cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached"
        return 0
    fi

    local hide_idle fan_selection fan_separator
    hide_idle=$(get_cached_option "@powerkit_plugin_fan_hide_when_idle" "$POWERKIT_PLUGIN_FAN_HIDE_WHEN_IDLE")
    fan_selection=$(get_cached_option "@powerkit_plugin_fan_selection" "$POWERKIT_PLUGIN_FAN_SELECTION")
    fan_separator=$(get_cached_option "@powerkit_plugin_fan_separator" "$POWERKIT_PLUGIN_FAN_SEPARATOR")

    local result=""

    case "$fan_selection" in
        all)
            # Show all fans with separator
            local fan_rpms=()
            while IFS= read -r rpm; do
                [[ -z "$rpm" ]] && continue
                fan_rpms+=("$(format_rpm "$rpm")")
            done < <(get_all_fans_hwmon "$hide_idle")

            [[ ${#fan_rpms[@]} -eq 0 ]] && return 0
            result=$(join_with_separator "$fan_separator" "${fan_rpms[@]}")
            ;;
        *)
            # Default: first non-zero fan
            local rpm
            rpm=$(get_fan_speed) || return 0
            [[ -z "$rpm" ]] && return 0
            [[ "$hide_idle" == "true" && "$rpm" -eq 0 ]] && return 0
            result=$(format_rpm "$rpm")
            ;;
    esac

    [[ -z "$result" ]] && return 0

    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
