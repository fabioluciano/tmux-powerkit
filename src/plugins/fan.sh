#!/usr/bin/env bash
# =============================================================================
# Plugin: fan
# Description: Display fan speed (RPM) for system cooling fans
# Dependencies:
#   macOS: osx-cpu-temp/smctemp/istats (optional)
#   Linux: hwmon/sysfs (built-in) or sensors (optional)
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active: Fan speed detected
#   - inactive: No fan or 0 RPM
#
# Health:
#   - ok: Normal fan speed
#   - warning: Fan speed above warning threshold
#   - error: Fan speed above critical threshold
#
# Context:
#   - silent, quiet, normal, loud, max based on RPM
#
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "fan"
    metadata_set "name" "Fan"
    metadata_set "description" "Display fan speed (RPM)"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    if is_macos; then
        require_any_cmd "osx-cpu-temp" "smctemp" "istats" 1  # Optional
    else
        # Linux - sysfs is always available, tools are optional
        require_cmd "sensors" 1  # Optional
    fi
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "source" "string" "auto" "Fan source (auto|dell|thinkpad|hwmon)"
    declare_option "format" "string" "rpm" "Display format (rpm|krpm|full)"
    declare_option "hide_when_idle" "bool" "false" "Hide when fan is idle (0 RPM)"
    declare_option "selection" "string" "active" "Fan selection (active|all)"
    declare_option "separator" "string" " | " "Separator between multiple fans"

    # Icons
    declare_option "icon" "icon" $'\U000F0210' "Fan icon"
    declare_option "icon_fast" "icon" $'\U000F0211' "Fast fan icon"

    # Thresholds (RPM)
    declare_option "warning_threshold" "number" "4000" "Warning threshold in RPM"
    declare_option "critical_threshold" "number" "6000" "Critical threshold in RPM"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

plugin_get_state() {
    local rpm=$(plugin_data_get "rpm")
    [[ "${rpm:-0}" -gt 0 ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() {
    local rpm warn_th crit_th
    rpm=$(plugin_data_get "rpm")
    warn_th=$(get_option "warning_threshold")
    crit_th=$(get_option "critical_threshold")

    rpm="${rpm:-0}"
    warn_th="${warn_th:-4000}"
    crit_th="${crit_th:-6000}"

    if (( rpm >= crit_th )); then
        printf 'error'
    elif (( rpm >= warn_th )); then
        printf 'warning'
    else
        printf 'ok'
    fi
}

plugin_get_context() {
    local rpm=$(plugin_data_get "rpm")
    rpm="${rpm:-0}"

    if (( rpm == 0 )); then
        printf 'silent'
    elif (( rpm < 2000 )); then
        printf 'quiet'
    elif (( rpm < 4000 )); then
        printf 'normal'
    elif (( rpm < 5500 )); then
        printf 'loud'
    else
        printf 'max'
    fi
}

plugin_get_icon() {
    local rpm warn_th
    rpm=$(plugin_data_get "rpm")
    warn_th=$(get_option "warning_threshold")

    if (( ${rpm:-0} >= ${warn_th:-4000} )); then
        get_option "icon_fast"
    else
        get_option "icon"
    fi
}

# =============================================================================
# Linux: hwmon/sysfs Detection
# =============================================================================

_get_fan_hwmon() {
    # Read from hwmon subsystem (first non-zero fan)
    for dir in /sys/class/hwmon/hwmon*; do
        [[ -d "$dir" ]] || continue
        for fan_file in "$dir"/fan*_input; do
            [[ -f "$fan_file" ]] || continue
            local rpm
            rpm=$(<"$fan_file" 2>/dev/null)
            [[ -n "$rpm" && "$rpm" -gt 0 ]] && { printf '%s' "$rpm"; return 0; }
        done
    done
    return 1
}

_get_all_fans_hwmon() {
    local hide_idle="$1"
    local fans=()

    for dir in /sys/class/hwmon/hwmon*; do
        [[ -d "$dir" ]] || continue
        for fan_file in "$dir"/fan*_input; do
            [[ -f "$fan_file" ]] || continue
            local rpm
            rpm=$(<"$fan_file" 2>/dev/null)
            [[ -z "$rpm" ]] && continue
            [[ "$hide_idle" == "true" && "$rpm" -eq 0 ]] && continue
            fans+=("$rpm")
        done
    done

    printf '%s\n' "${fans[@]}"
}

# =============================================================================
# Linux: Dell/ThinkPad Specific
# =============================================================================

_get_fan_dell() {
    for dir in /sys/class/hwmon/hwmon*; do
        [[ -f "$dir/name" && "$(<"$dir/name")" == "dell_smm" ]] || continue
        for fan in "$dir"/fan*_input; do
            [[ -f "$fan" ]] || continue
            local rpm
            rpm=$(<"$fan" 2>/dev/null)
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

# =============================================================================
# macOS: Fan Detection
# =============================================================================

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

    # istats fallback
    if has_cmd istats; then
        local rpm
        rpm=$(istats fan speed --value-only 2>/dev/null | head -1)
        [[ -n "$rpm" && "$rpm" -gt 0 ]] && { printf '%s' "$rpm"; return 0; }
    fi

    return 1
}

# =============================================================================
# Main Detection
# =============================================================================

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
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    local hide_idle selection
    hide_idle=$(get_option "hide_when_idle")
    selection=$(get_option "selection")

    local rpm

    case "$selection" in
        all)
            # Get all fans, store first for health calculation
            local fans
            fans=$(_get_all_fans_hwmon "$hide_idle" | head -1)
            rpm="${fans:-0}"
            ;;
        *)
            rpm=$(_get_fan_speed) || rpm=0
            ;;
    esac

    [[ "$hide_idle" == "true" && "${rpm:-0}" -eq 0 ]] && return 0

    plugin_data_set "rpm" "${rpm:-0}"
    plugin_data_set "selection" "$selection"
}

# =============================================================================
# Plugin Contract: Render (TEXT ONLY)
# =============================================================================

plugin_render() {
    local rpm selection separator hide_idle
    rpm=$(plugin_data_get "rpm")
    selection=$(plugin_data_get "selection")
    separator=$(get_option "separator")
    hide_idle=$(get_option "hide_when_idle")

    [[ -z "$rpm" || "$rpm" -eq 0 ]] && return 0

    if [[ "$selection" == "all" ]] && is_linux; then
        # Show all fans
        local result_parts=()
        while IFS= read -r fan_rpm; do
            [[ -z "$fan_rpm" ]] && continue
            result_parts+=("$(_format_rpm "$fan_rpm")")
        done < <(_get_all_fans_hwmon "$hide_idle")

        [[ ${#result_parts[@]} -gt 0 ]] && join_with_separator "$separator" "${result_parts[@]}"
    else
        _format_rpm "$rpm"
    fi
}
