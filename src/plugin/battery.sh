#!/usr/bin/env bash
# =============================================================================
# Plugin: battery
# Description: Display battery percentage/time with dynamic colors
# Type: conditional (hidden based on display conditions and battery presence)
# Dependencies: macOS: pmset (optional), Linux: upower/acpi (optional), Termux: termux-battery-status (optional), BSD: apm (optional)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    if is_macos; then
        require_cmd "pmset" 1  # Optional
    else
        require_cmd "upower" 1  # Optional
    fi
    require_cmd "jq" 1  # Optional (for termux)
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display behavior
    declare_option "display_mode" "string" "percentage" "Display mode (percentage|time)"
    declare_option "hide_when_full_and_charging" "bool" "false" "Hide when 100% and charging"

    # Icons (Nerd Font)
    declare_option "icon" "icon" $'\U000F0079' "Plugin icon (default)"
    declare_option "icon_charging" "icon" $'\U000F0084' "Icon when charging"
    declare_option "icon_low" "icon" $'\U000F0083' "Icon when battery is low"

    # Colors (default state)
    declare_option "accent_color" "color" "secondary" "Background color (default)"
    declare_option "accent_color_icon" "color" "active" "Icon background color (default)"

    # Thresholds (uses inverted mode: lower value = worse)
    declare_option "threshold_mode" "string" "inverted" "Threshold mode (none|normal|inverted)"
    declare_option "warning_threshold" "number" "50" "Warning threshold (battery <= this shows warning)"
    declare_option "critical_threshold" "number" "30" "Critical threshold (battery <= this shows error)"
    declare_option "show_only_warning" "bool" "false" "Only show when threshold exceeded"

    # Cache
    declare_option "cache_ttl" "number" "60" "Cache duration in seconds"
}

plugin_init "battery"

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

# Store last computed value for threshold display info
_BATTERY_LAST_VALUE=""

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"

    # Use threshold_plugin_display_info for standard threshold/visibility handling
    local result
    result=$(threshold_plugin_display_info "$content" "$_BATTERY_LAST_VALUE")

    # Parse result to potentially override icon
    local show accent accent_icon icon
    IFS=':' read -r show accent accent_icon icon <<< "$result"

    # Override icon based on state
    if [[ "$show" == "1" ]]; then
        local critical_threshold
        critical_threshold=$(get_option "critical_threshold")

        # Use low icon when critical
        if [[ -n "$_BATTERY_LAST_VALUE" && "$_BATTERY_LAST_VALUE" -le "$critical_threshold" ]]; then
            icon=$(get_option "icon_low")
        fi

        # Override icon when charging
        if is_charging; then
            icon=$(get_option "icon_charging")
        fi
    fi

    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Main Logic
# =============================================================================

get_percentage() {
    if is_wsl; then
        local f=$(find /sys/class/power_supply/*/capacity 2>/dev/null | head -1)
        [[ -n "$f" ]] && cat "$f" 2>/dev/null
    elif is_macos && has_cmd pmset; then
        pmset -g batt 2>/dev/null | awk '/[0-9]+%/ {gsub(/[%;]/, "", $3); print $3; exit}'
    elif has_cmd acpi; then
        acpi -b 2>/dev/null | awk -F'[,%]' '/Battery/ {gsub(/ /, "", $2); print $2; exit}'
    elif has_cmd upower; then
        local bat=$(upower -e 2>/dev/null | grep -E 'battery|DisplayDevice' | tail -1)
        [[ -n "$bat" ]] && upower -i "$bat" 2>/dev/null | awk '/percentage:/ {gsub(/%/, ""); print $2}'
    elif has_cmd termux-battery-status; then
        { termux-battery-status | jq -r '.percentage'; } 2>/dev/null
    elif has_cmd apm; then
        apm -l 2>/dev/null | tr -d '%'
    fi
}

# Check if charging
is_charging() {
    if is_wsl; then
        local f=$(find /sys/class/power_supply/*/status 2>/dev/null | head -1)
        [[ -n "$f" ]] && grep -qi "^charging$" "$f" 2>/dev/null
    elif has_cmd pmset; then
        pmset -g batt 2>/dev/null | grep -q "AC Power"
    elif has_cmd acpi; then
        acpi -b 2>/dev/null | grep -qiE "^Battery.*: Charging"
    elif has_cmd upower; then
        local bat=$(upower -e 2>/dev/null | grep -E 'battery|DisplayDevice' | tail -1)
        [[ -n "$bat" ]] && upower -i "$bat" 2>/dev/null | grep -qiE "state:\s*(charging|fully-charged)"
    elif has_cmd termux-battery-status; then
        { termux-battery-status | jq -r '.status' | grep -qi "^charging$"; } 2>/dev/null
    else
        return 1
    fi
}

# Check if battery exists
has_battery() {
    if is_wsl; then
        [[ -n "$(find /sys/class/power_supply/*/capacity 2>/dev/null | head -1)" ]]
    elif has_cmd pmset; then
        pmset -g batt 2>/dev/null | grep -q "InternalBattery"
    elif has_cmd acpi; then
        acpi -b 2>/dev/null | grep -q "Battery"
    elif has_cmd upower; then
        local bat=$(upower -e 2>/dev/null | grep -E 'BAT|battery' | grep -v DisplayDevice | head -1)
        [[ -n "$bat" ]] && upower -i "$bat" 2>/dev/null | grep -q "power supply.*yes"
    elif has_cmd termux-battery-status; then
        termux-battery-status &>/dev/null
    elif has_cmd apm; then
        apm -l &>/dev/null
    else
        return 1
    fi
}

get_time() {
    if has_cmd pmset; then
        local out=$(pmset -g batt 2>/dev/null)
        if echo "$out" | grep -q "(no estimate)"; then
            echo "..."
        else
            echo "$out" | grep -oE '[0-9]+:[0-9]+' | head -1
        fi
    elif has_cmd acpi; then
        acpi -b 2>/dev/null | grep -oE '[0-9]+:[0-9]+:[0-9]+' | head -1 | cut -d: -f1-2
    elif has_cmd upower; then
        local bat=$(upower -e 2>/dev/null | grep -E 'battery|DisplayDevice' | tail -1)
        if [[ -n "$bat" ]]; then
            local sec=$(upower -i "$bat" 2>/dev/null | grep -E "time to (empty|full)" | awk '{print $4}')
            local unit=$(upower -i "$bat" 2>/dev/null | grep -E "time to (empty|full)" | awk '{print $5}')
            case "$unit" in
                hours) echo "${sec}h" ;;
                minutes) echo "${sec}m" ;;
                *) echo "$sec" ;;
            esac
        fi
    fi
}

_compute_battery() {
    local pct=$(get_percentage)
    [[ -z "$pct" ]] && return 0

    # Store for threshold_plugin_display_info
    _BATTERY_LAST_VALUE="$pct"

    # Hide if 100% and charging
    local hide_full_charging=$(get_option "hide_when_full_and_charging")
    if [[ "$hide_full_charging" == "true" && "$pct" == "100" ]] && is_charging; then
        return 0
    fi

    local mode=$(get_option "display_mode")
    if [[ "$mode" == "time" ]]; then
        # When charging, time remaining doesn't make sense - hide
        if is_charging; then
            return 0
        fi
        local t=$(get_time)
        # If no time estimate, hide
        if [[ -z "$t" || "$t" == "..." || "$t" == "0:00" ]]; then
            return 0
        fi
        format_duration "$t"
    else
        printf '%s%%' "$pct"
    fi
}

load_plugin() {
    has_battery || return 0
    cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_battery
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
