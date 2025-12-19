#!/usr/bin/env bash
# Plugin: battery - Display battery percentage/time with dynamic colors
# Platforms: macOS (pmset), Linux (acpi/upower), WSL, Termux, BSD (apm)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "battery"

# Platform detection
is_wsl() { [[ -f /proc/version ]] && grep -qiE "microsoft|wsl" /proc/version 2>/dev/null; }
cmd() { require_cmd "$1" 1; }

# Get battery percentage
get_percentage() {
    if is_wsl; then
        local f=$(find /sys/class/power_supply/*/capacity 2>/dev/null | head -1)
        [[ -n "$f" ]] && cat "$f" 2>/dev/null
    elif is_macos && cmd pmset; then
        pmset -g batt 2>/dev/null | awk '/[0-9]+%/ {gsub(/[%;]/, "", $3); print $3; exit}'
    elif cmd acpi; then
        acpi -b 2>/dev/null | awk -F'[,%]' '/Battery/ {gsub(/ /, "", $2); print $2; exit}'
    elif cmd upower; then
        local bat=$(upower -e 2>/dev/null | grep -E 'battery|DisplayDevice' | tail -1)
        [[ -n "$bat" ]] && upower -i "$bat" 2>/dev/null | awk '/percentage:/ {gsub(/%/, ""); print $2}'
    elif cmd termux-battery-status; then
        { termux-battery-status | jq -r '.percentage'; } 2>/dev/null
    elif cmd apm; then
        apm -l 2>/dev/null | tr -d '%'
    fi
}

# Check if charging
is_charging() {
    if is_wsl; then
        local f=$(find /sys/class/power_supply/*/status 2>/dev/null | head -1)
        [[ -n "$f" ]] && grep -qi "^charging$" "$f" 2>/dev/null
    elif cmd pmset; then
        pmset -g batt 2>/dev/null | grep -q "AC Power"
    elif cmd acpi; then
        acpi -b 2>/dev/null | grep -qiE "^Battery.*: Charging"
    elif cmd upower; then
        local bat=$(upower -e 2>/dev/null | grep -E 'battery|DisplayDevice' | tail -1)
        [[ -n "$bat" ]] && upower -i "$bat" 2>/dev/null | grep -qiE "state:\s*(charging|fully-charged)"
    elif cmd termux-battery-status; then
        { termux-battery-status | jq -r '.status' | grep -qi "^charging$"; } 2>/dev/null
    else
        return 1
    fi
}

# Check if battery exists
has_battery() {
    if is_wsl; then
        [[ -n "$(find /sys/class/power_supply/*/capacity 2>/dev/null | head -1)" ]]
    elif cmd pmset; then
        pmset -g batt 2>/dev/null | grep -q "InternalBattery"
    elif cmd acpi; then
        acpi -b 2>/dev/null | grep -q "Battery"
    elif cmd upower; then
        local bat=$(upower -e 2>/dev/null | grep -E 'BAT|battery' | grep -v DisplayDevice | head -1)
        [[ -n "$bat" ]] && upower -i "$bat" 2>/dev/null | grep -q "power supply.*yes"
    elif cmd termux-battery-status; then
        termux-battery-status &>/dev/null
    elif cmd apm; then
        apm -l &>/dev/null
    else
        return 1
    fi
}

# Get time remaining
get_time() {
    if cmd pmset; then
        local out=$(pmset -g batt 2>/dev/null)
        if echo "$out" | grep -q "(no estimate)"; then
            echo "..."
        else
            echo "$out" | grep -oE '[0-9]+:[0-9]+' | head -1
        fi
    elif cmd acpi; then
        acpi -b 2>/dev/null | grep -oE '[0-9]+:[0-9]+:[0-9]+' | head -1 | cut -d: -f1-2
    elif cmd upower; then
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

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    local show="1" accent="" accent_icon="" icon=""
    local value=$(extract_numeric "$content")

    # Display condition check
    local cond=$(get_cached_option "@powerkit_plugin_battery_display_condition" "always")
    local thresh=$(get_cached_option "@powerkit_plugin_battery_display_threshold" "")
    [[ "$cond" != "always" && -n "$thresh" ]] && ! evaluate_condition "$value" "$cond" "$thresh" && show="0"

    # Default colors
    accent=$(get_cached_option "@powerkit_plugin_battery_accent_color" "$POWERKIT_PLUGIN_BATTERY_ACCENT_COLOR")
    accent_icon=$(get_cached_option "@powerkit_plugin_battery_accent_color_icon" "$POWERKIT_PLUGIN_BATTERY_ACCENT_COLOR_ICON")

    # Get thresholds
    local low_t=$(get_cached_option "@powerkit_plugin_battery_low_threshold" "$POWERKIT_PLUGIN_BATTERY_LOW_THRESHOLD")
    local mid_t=$(get_cached_option "@powerkit_plugin_battery_mid_threshold" "$POWERKIT_PLUGIN_BATTERY_MID_THRESHOLD")

    # Apply threshold colors regardless of charging state
    # (battery level alerts should persist even while charging)
    if [[ -n "$value" && "$value" -le "$low_t" ]]; then
        accent=$(get_cached_option "@powerkit_plugin_battery_low_accent_color" "$POWERKIT_PLUGIN_BATTERY_LOW_ACCENT_COLOR")
        accent_icon=$(get_cached_option "@powerkit_plugin_battery_low_accent_color_icon" "$POWERKIT_PLUGIN_BATTERY_LOW_ACCENT_COLOR_ICON")
        icon=$(get_cached_option "@powerkit_plugin_battery_icon_low" "$POWERKIT_PLUGIN_BATTERY_ICON_LOW")
    elif [[ -n "$value" && "$value" -le "$mid_t" ]]; then
        accent=$(get_cached_option "@powerkit_plugin_battery_mid_accent_color" "$POWERKIT_PLUGIN_BATTERY_MID_ACCENT_COLOR")
        accent_icon=$(get_cached_option "@powerkit_plugin_battery_mid_accent_color_icon" "$POWERKIT_PLUGIN_BATTERY_MID_ACCENT_COLOR_ICON")
    fi

    # Set charging icon (but keep threshold colors)
    if is_charging; then
        icon=$(get_cached_option "@powerkit_plugin_battery_icon_charging" "$POWERKIT_PLUGIN_BATTERY_ICON_CHARGING")
    fi

    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

load_plugin() {
    has_battery || return 0

    local cached
    if cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached"
        return 0
    fi

    local pct=$(get_percentage)
    [[ -z "$pct" ]] && return 0

    # Nova opção: ocultar se 100% e carregando
    local hide_full_charging=$(get_tmux_option "@powerkit_plugin_battery_hide_when_full_and_charging" "false")
    if [[ "$hide_full_charging" == "true" && "$pct" == "100" ]]; then
        if is_charging; then
            return 0
        fi
    fi

    local mode=$(get_tmux_option "@powerkit_plugin_battery_display_mode" "$POWERKIT_PLUGIN_BATTERY_DISPLAY_MODE")
    local result
    if [[ "$mode" == "time" ]]; then
        local t=$(get_time)
        result="${t:-${pct}%}"
    else
        result="${pct}%"
    fi

    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
