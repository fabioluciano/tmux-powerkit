#!/usr/bin/env bash
# =============================================================================
# Plugin: fan
# Description: Display fan speed (RPM) for system cooling fans
# Dependencies: None (uses sysfs on Linux, osx-cpu-temp/smctemp on macOS)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    require_any_cmd "osx-cpu-temp" "smctemp" "sensors" 1  # All optional
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "source" "string" "auto" "Fan source (auto|dell|thinkpad|hwmon)"
    declare_option "format" "string" "krpm" "Display format (krpm|full|rpm)"
    declare_option "hide_when_idle" "bool" "false" "Hide when fan is idle (0 RPM)"
    declare_option "selection" "string" "active" "Fan selection (active|all)"
    declare_option "separator" "string" " | " "Separator between multiple fans"
    declare_option "show_when_unavailable" "bool" "false" "Show placeholder when unavailable"
    declare_option "placeholder" "string" "--" "Placeholder text when unavailable"

    # Icons
    declare_option "icon" "icon" $'\uefa7' "Plugin icon (normal speed)"
    declare_option "icon_fast" "icon" "" "Plugin icon (high speed)"

    # Colors
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Thresholds
    declare_option "warning_threshold" "number" "3000" "Warning threshold in RPM"
    declare_option "critical_threshold" "number" "5000" "Critical threshold in RPM"

    # Cache
    declare_option "cache_ttl" "number" "10" "Cache duration in seconds"
}

plugin_init "fan"

# =============================================================================
# Main Logic
# =============================================================================

_get_fan_hwmon() {
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

_get_all_fans_hwmon() {
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

_get_fan_dell() {
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

_get_fan_thinkpad() {
    local fan_file="/proc/acpi/ibm/fan"
    [[ -f "$fan_file" ]] || return 1
    local rpm
    rpm=$(awk '/^speed:/ {print $2}' "$fan_file" 2>/dev/null)
    [[ -n "$rpm" && "$rpm" -gt 0 ]] && { printf '%s' "$rpm"; return 0; }
    return 1
}

_get_fan_macos() {
    # osx-cpu-temp (most common)
    if has_cmd osx-cpu-temp; then
        local output rpm
        output=$(osx-cpu-temp -f 2>/dev/null)
        if [[ "$output" != *"Num fans: 0"* ]]; then
            rpm=$(printf '%s' "$output" | grep -oE '[0-9]+ RPM' | head -1 | grep -oE '[0-9]+')
            [[ -n "$rpm" && "$rpm" -gt 0 ]] && { printf '%s' "$rpm"; return 0; }
        fi
    fi

    # smctemp fallback
    if has_cmd smctemp; then
        local rpm
        rpm=$(smctemp -f 2>/dev/null | grep -oE '[0-9]+' | head -1)
        [[ -n "$rpm" && "$rpm" -gt 0 ]] && { printf '%s' "$rpm"; return 0; }
    fi

    return 1
}

_get_fan_speed() {
    local source
    source=$(get_option "source")

    case "$source" in
        dell)     _get_fan_dell ;;
        thinkpad) _get_fan_thinkpad ;;
        hwmon)    _get_fan_hwmon ;;
        *)
            if is_macos; then
                _get_fan_macos
            else
                _get_fan_dell || _get_fan_thinkpad || _get_fan_hwmon
            fi
            ;;
    esac
}

_format_rpm() {
    local rpm="$1"
    local format
    format=$(get_option "format")

    case "$format" in
        krpm) awk "BEGIN {printf \"%.1fk\", $rpm / 1000}" ;;
        full) printf '%s RPM' "$rpm" ;;
        *)    printf '%s' "$rpm" ;;
    esac
}

# =============================================================================
# Plugin Contract Implementation
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
        icon=$(get_option "icon_fast")
    fi

    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

load_plugin() {
    local cached
    if cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached"
        return 0
    fi

    local hide_idle fan_selection fan_separator
    hide_idle=$(get_option "hide_when_idle")
    fan_selection=$(get_option "selection")
    fan_separator=$(get_option "separator")

    local result=""

    case "$fan_selection" in
        all)
            # Show all fans with separator
            local fan_rpms=()
            while IFS= read -r rpm; do
                [[ -z "$rpm" ]] && continue
                fan_rpms+=("$(_format_rpm "$rpm")")
            done < <(_get_all_fans_hwmon "$hide_idle")

            [[ ${#fan_rpms[@]} -eq 0 ]] && return 0
            result=$(join_with_separator "$fan_separator" "${fan_rpms[@]}")
            ;;
        *)
            # Default: first non-zero fan
            local rpm
            rpm=$(_get_fan_speed) || return 0
            [[ -z "$rpm" ]] && return 0
            [[ "$hide_idle" == "true" && "$rpm" -eq 0 ]] && return 0
            result=$(_format_rpm "$rpm")
            ;;
    esac

    [[ -z "$result" ]] && return 0

    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
