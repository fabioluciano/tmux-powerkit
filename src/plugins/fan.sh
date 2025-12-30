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
    # Fanless Macs don't have fans - return 1 to mark as unavailable
    if is_macos && is_fanless_mac; then
        return 1
    fi

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
    declare_option "format" "string" "icon_k" "Display format (rpm|krpm|number|icon|icon_k)"
    declare_option "selection" "string" "active" "Fan selection: active (RPM>0) or all (include idle)"
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
    # Fanless Macs - always inactive
    is_fanless_mac && { printf 'inactive'; return; }

    local rpm=$(plugin_data_get "rpm")
    [[ "${rpm:-0}" -gt 0 ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() {
    local rpm warn_th crit_th
    rpm=$(plugin_data_get "rpm")
    warn_th=$(get_option "warning_threshold")
    crit_th=$(get_option "critical_threshold")

    # Higher is worse (default behavior)
    evaluate_threshold_health "${rpm:-0}" "${warn_th:-4000}" "${crit_th:-6000}"
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
    # Note: Using cat instead of $(<file) for sysfs compatibility
    for dir in /sys/class/hwmon/hwmon*; do
        [[ -d "$dir" ]] || continue
        for fan_file in "$dir"/fan*_input; do
            [[ -f "$fan_file" ]] || continue
            local rpm
            rpm=$(cat "$fan_file" 2>/dev/null)
            [[ -n "$rpm" && "$rpm" -gt 0 ]] && { printf '%s' "$rpm"; return 0; }
        done
    done
    return 1
}

_get_all_fans_hwmon() {
    local filter_idle="$1"
    local fans=()

    for dir in /sys/class/hwmon/hwmon*; do
        [[ -d "$dir" ]] || continue
        for fan_file in "$dir"/fan*_input; do
            [[ -f "$fan_file" ]] || continue
            local rpm
            rpm=$(cat "$fan_file" 2>/dev/null | tr -d '[:space:]')
            [[ -z "$rpm" || ! "$rpm" =~ ^[0-9]+$ ]] && continue
            # Filter idle fans (0 RPM) when filter_idle is true
            if [[ "$filter_idle" == "true" ]] && (( rpm == 0 )); then
                continue
            fi
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
        [[ -f "$dir/name" && "$(cat "$dir/name" 2>/dev/null)" == "dell_smm" ]] || continue
        for fan in "$dir"/fan*_input; do
            [[ -f "$fan" ]] || continue
            local rpm
            rpm=$(cat "$fan" 2>/dev/null)
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
    local format icon
    format=$(get_option "format")

    case "$format" in
        number)  printf '%s' "$rpm" ;;
        krpm)    awk "BEGIN {printf \"%.1fk\", $rpm / 1000}" ;;
        icon)
            icon=$(get_option "icon")
            printf '%s %s' "$icon" "$rpm"
            ;;
        icon_k)
            icon=$(get_option "icon")
            awk -v icon="$icon" "BEGIN {printf \"%s %.1fk\", icon, $rpm / 1000}"
            ;;
        *)       printf '%s' "$rpm" ;;
    esac
}

# Get the unit suffix based on format (appended once at the end)
_get_unit_suffix() {
    local format
    format=$(get_option "format")

    case "$format" in
        number|icon)  printf ' RPM' ;;
        krpm|icon_k)  printf ' RPM' ;;
        *)            printf ' RPM' ;;
    esac
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    # Fanless Macs - skip collection
    is_fanless_mac && return 0

    local selection
    selection=$(get_option "selection")

    local rpm all_rpms

    if is_linux; then
        # selection=active: only fans with RPM > 0
        # selection=all: all fans including idle (RPM = 0)
        local filter_idle="true"
        [[ "$selection" == "all" ]] && filter_idle="false"

        all_rpms=$(_get_all_fans_hwmon "$filter_idle")

        # No fans found - plugin will be inactive
        [[ -z "$all_rpms" ]] && return 0

        # Store max RPM for health calculation (highest speed = most stressed)
        rpm=$(echo "$all_rpms" | sort -rn | head -1 | tr -d '[:space:]')
        rpm="${rpm:-0}"
        plugin_data_set "all_rpms" "$all_rpms"
    else
        # macOS: single fan value
        rpm=$(_get_fan_speed) || rpm=0
        plugin_data_set "all_rpms" "$rpm"
    fi

    # No active fans - plugin will be inactive
    (( rpm == 0 )) && return 0

    plugin_data_set "rpm" "$rpm"
}

# =============================================================================
# Plugin Contract: Render (TEXT ONLY)
# =============================================================================

plugin_render() {
    local rpm separator
    rpm=$(plugin_data_get "rpm")
    separator=$(get_option "separator")

    [[ -z "$rpm" || "$rpm" -eq 0 ]] && return 0

    # Show all collected fans (active or all depending on selection)
    local all_rpms
    all_rpms=$(plugin_data_get "all_rpms")
    [[ -z "$all_rpms" ]] && { printf '%s%s' "$(_format_rpm "$rpm")" "$(_get_unit_suffix)"; return; }

    local result_parts=()
    while IFS= read -r fan_rpm; do
        [[ -z "$fan_rpm" ]] && continue
        result_parts+=("$(_format_rpm "$fan_rpm")")
    done <<< "$all_rpms"

    # Join fan values and append unit suffix once at the end
    local output=""
    if [[ ${#result_parts[@]} -gt 1 ]]; then
        output=$(join_with_separator "$separator" "${result_parts[@]}")
    elif [[ ${#result_parts[@]} -eq 1 ]]; then
        output="${result_parts[0]}"
    fi

    printf '%s%s' "$output" "$(_get_unit_suffix)"
}
