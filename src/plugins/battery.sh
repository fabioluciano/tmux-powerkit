#!/usr/bin/env bash
# =============================================================================
# Plugin: battery
# Description: Display battery percentage/time with dynamic status
# Type: conditional (hidden on desktops without battery)
# Dependencies: pmset (macOS), upower/acpi (Linux), termux-battery-status, apm (BSD)
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active: Battery present and readable
#   - inactive: No battery detected (desktop, VM, etc.)
#   - degraded: Battery present but health is poor
#
# Health:
#   - ok: Battery level is good (above warning threshold), or fully charged
#   - warning: Battery level is low (below warning, above critical)
#   - error: Battery level is critical (below critical threshold)
#   - info: Battery is actively charging
#
# Context:
#   - charging: Battery is actively charging
#   - discharging: Battery is discharging (on battery power)
#   - charged: Battery is fully charged (100%)
#   - ac_power: Connected to AC but not charging (maintenance mode)
#
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "battery"
    metadata_set "name" "Battery"
    metadata_set "version" "2.1.0"
    metadata_set "description" "Display battery status with multi-platform support"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    if is_macos; then
        require_cmd "pmset" 1  # Optional but preferred
    elif is_wsl; then
        # WSL uses /sys/class/power_supply
        [[ -d /sys/class/power_supply ]] || return 1
    else
        # Linux - multiple options
        require_cmd "upower" 1
        require_cmd "acpi" 1
        require_cmd "termux-battery-status" 1
        require_cmd "apm" 1  # BSD
    fi
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display mode
    declare_option "display_mode" "string" "percentage" "Display mode (percentage|time)"
    declare_option "hide_when_full_and_charging" "bool" "false" "Hide when 100% and on AC"
    # Note: show_only_on_threshold is auto-injected globally

    declare_option "warning_threshold" "number" "30" "Warning threshold percentage"
    declare_option "critical_threshold" "number" "15" "Critical threshold percentage"

    # Icons
    declare_option "icon" "icon" $'\U000F0079' "Default battery icon (full)"
    declare_option "icon_charging" "icon" $'\U000F0084' "Charging/AC power icon"
    declare_option "icon_low" "icon" $'\U000F0083' "Low battery icon"
    declare_option "icon_critical" "icon" $'\U000F008E' "Critical battery icon"

    # Cache
    declare_option "cache_ttl" "number" "30" "Cache duration in seconds"
}

# =============================================================================
# Battery Detection Functions (Multi-platform)
# =============================================================================

# Check if battery exists
_has_battery() {
    if is_wsl; then
        [[ -n "$(find /sys/class/power_supply/*/capacity 2>/dev/null | head -1)" ]]
    elif is_macos && has_cmd pmset; then
        pmset -g batt 2>/dev/null | grep -q "InternalBattery"
    elif has_cmd acpi; then
        acpi -b 2>/dev/null | grep -q "Battery"
    elif has_cmd upower; then
        local bat
        bat=$(upower -e 2>/dev/null | grep -E 'BAT|battery' | grep -v DisplayDevice | head -1)
        [[ -n "$bat" ]] && upower -i "$bat" 2>/dev/null | grep -q "power supply.*yes"
    elif has_cmd termux-battery-status; then
        termux-battery-status &>/dev/null
    elif has_cmd apm; then
        apm -l &>/dev/null
    else
        # Fallback: check sysfs directly
        [[ -d /sys/class/power_supply ]] && ls /sys/class/power_supply/BAT* &>/dev/null
    fi
}

# Get battery percentage
_get_percentage() {
    local percent=""

    if is_wsl; then
        local f
        f=$(find /sys/class/power_supply/*/capacity 2>/dev/null | head -1)
        [[ -n "$f" ]] && percent=$(cat "$f" 2>/dev/null)
    elif is_macos && has_cmd pmset; then
        percent=$(pmset -g batt 2>/dev/null | awk '/[0-9]+%/ {gsub(/[%;]/, "", $3); print $3; exit}')
    elif has_cmd acpi; then
        percent=$(acpi -b 2>/dev/null | awk -F'[,%]' '/Battery/ {gsub(/ /, "", $2); print $2; exit}')
    elif has_cmd upower; then
        local bat
        bat=$(upower -e 2>/dev/null | grep -E 'battery|DisplayDevice' | tail -1)
        [[ -n "$bat" ]] && percent=$(upower -i "$bat" 2>/dev/null | awk '/percentage:/ {gsub(/%/, ""); print $2}')
    elif has_cmd termux-battery-status && has_cmd jq; then
        percent=$(termux-battery-status 2>/dev/null | jq -r '.percentage')
    elif has_cmd apm; then
        percent=$(apm -l 2>/dev/null | tr -d '%')
    else
        # Fallback: sysfs
        local bat
        for bat in /sys/class/power_supply/BAT*; do
            if [[ -f "$bat/capacity" ]]; then
                percent=$(cat "$bat/capacity" 2>/dev/null)
                break
            fi
        done
    fi

    echo "${percent:-0}"
}

# Get charging status
_get_charging_status() {
    local status="unknown"

    if is_wsl; then
        local f
        f=$(find /sys/class/power_supply/*/status 2>/dev/null | head -1)
        [[ -n "$f" ]] && status=$(cat "$f" 2>/dev/null | tr '[:upper:]' '[:lower:]')
    elif is_macos && has_cmd pmset; then
        local out
        out=$(pmset -g batt 2>/dev/null)
        if echo "$out" | grep -q "AC Power"; then
            if echo "$out" | grep -qE "charging|finishing charge"; then
                status="charging"
            elif echo "$out" | grep -q "charged"; then
                status="charged"
            else
                status="ac_power"
            fi
        else
            status="discharging"
        fi
    elif has_cmd acpi; then
        if acpi -b 2>/dev/null | grep -qiE "^Battery.*: Charging"; then
            status="charging"
        elif acpi -b 2>/dev/null | grep -qiE "^Battery.*: Full"; then
            status="charged"
        else
            status="discharging"
        fi
    elif has_cmd upower; then
        local bat state
        bat=$(upower -e 2>/dev/null | grep -E 'battery|DisplayDevice' | tail -1)
        if [[ -n "$bat" ]]; then
            state=$(upower -i "$bat" 2>/dev/null | grep -E "^\s*state:" | awk '{print $2}')
            case "$state" in
                charging) status="charging" ;;
                fully-charged) status="charged" ;;
                discharging) status="discharging" ;;
                *) status="unknown" ;;
            esac
        fi
    elif has_cmd termux-battery-status && has_cmd jq; then
        local ts
        ts=$(termux-battery-status 2>/dev/null | jq -r '.status' | tr '[:upper:]' '[:lower:]')
        case "$ts" in
            charging) status="charging" ;;
            full) status="charged" ;;
            *) status="discharging" ;;
        esac
    else
        # Fallback: sysfs
        local bat
        for bat in /sys/class/power_supply/BAT*; do
            if [[ -f "$bat/status" ]]; then
                status=$(cat "$bat/status" 2>/dev/null | tr '[:upper:]' '[:lower:]')
                break
            fi
        done
    fi

    # Normalize status
    case "$status" in
        charging|"not charging") echo "charging" ;;
        full|charged) echo "charged" ;;
        discharging) echo "discharging" ;;
        *) echo "unknown" ;;
    esac
}

# Get time remaining
_get_time_remaining() {
    local time=""

    if is_macos && has_cmd pmset; then
        local out
        out=$(pmset -g batt 2>/dev/null)
        if echo "$out" | grep -q "(no estimate)"; then
            time="..."
        else
            time=$(echo "$out" | grep -oE '[0-9]+:[0-9]+' | head -1)
        fi
    elif has_cmd acpi; then
        time=$(acpi -b 2>/dev/null | grep -oE '[0-9]+:[0-9]+:[0-9]+' | head -1 | cut -d: -f1-2)
    elif has_cmd upower; then
        local bat sec unit
        bat=$(upower -e 2>/dev/null | grep -E 'battery|DisplayDevice' | tail -1)
        if [[ -n "$bat" ]]; then
            sec=$(upower -i "$bat" 2>/dev/null | grep -E "time to (empty|full)" | awk '{print $4}')
            unit=$(upower -i "$bat" 2>/dev/null | grep -E "time to (empty|full)" | awk '{print $5}')
            case "$unit" in
                hours) time="${sec}h" ;;
                minutes) time="${sec}m" ;;
                seconds) time="${sec}s" ;;
                *) time="$sec" ;;
            esac
        fi
    fi

    echo "$time"
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    # Check if battery exists
    if ! _has_battery; then
        plugin_data_set "available" "0"
        return
    fi

    local percent status
    percent=$(_get_percentage)
    status=$(_get_charging_status)

    plugin_data_set "available" "1"
    plugin_data_set "percent" "$percent"
    plugin_data_set "status" "$status"

    # Determine if charging (for icon selection)
    case "$status" in
        charging|charged|ac_power)
            plugin_data_set "on_ac" "1"
            ;;
        *)
            plugin_data_set "on_ac" "0"
            ;;
    esac
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
# State reflects operational status:
#   - active: Battery present and working
#   - inactive: No battery detected
#   - degraded: Battery detected but with issues

plugin_get_state() {
    local available
    available=$(plugin_data_get "available")
    [[ "$available" == "1" ]] && printf 'active' || printf 'inactive'
}

# =============================================================================
# Plugin Contract: Health
# =============================================================================
# Health reflects battery level severity:
#   - ok: Above warning threshold, or fully charged
#   - warning: Below warning, above critical
#   - error: Below critical threshold
#   - info: Actively charging

plugin_get_health() {
    local percent status warn_th crit_th
    percent=$(plugin_data_get "percent")
    status=$(plugin_data_get "status")
    warn_th=$(get_option "warning_threshold")
    crit_th=$(get_option "critical_threshold")
    percent="${percent:-0}"
    warn_th="${warn_th:-30}"
    crit_th="${crit_th:-15}"

    # Actively charging is informational
    case "$status" in
        charging)
            printf 'info'
            return
            ;;
        charged|ac_power)
            # Fully charged or on AC power is ok (nothing to act on)
            printf 'ok'
            return
            ;;
    esac

    # Check thresholds for discharging
    if (( percent <= crit_th )); then
        printf 'error'
    elif (( percent <= warn_th )); then
        printf 'warning'
    else
        printf 'ok'
    fi
}

# =============================================================================
# Plugin Contract: Context
# =============================================================================
# Context provides power state:
#   - charging, discharging, charged, ac_power

plugin_get_context() {
    local status
    status=$(plugin_data_get "status")
    [[ -n "$status" ]] && printf '%s' "$status"
}

# =============================================================================
# Plugin Contract: Icon
# =============================================================================

plugin_get_icon() {
    local percent status health

    percent=$(plugin_data_get "percent")
    status=$(plugin_data_get "status")
    health=$(plugin_get_health)

    percent="${percent:-0}"

    case "$status" in
        charging|charged|ac_power)
            get_option "icon_charging"
            return
            ;;
    esac

    # Critical battery
    if [[ "$health" == "error" ]]; then
        get_option "icon_critical"
        return
    fi

    # Low battery (warning)
    if [[ "$health" == "warning" ]]; then
        get_option "icon_low"
        return
    fi

    # Default icon (battery ok)
    get_option "icon"
}

# =============================================================================
# Plugin Contract: Render
# =============================================================================

plugin_render() {
    local percent status mode hide_full

    percent=$(plugin_data_get "percent")
    status=$(plugin_data_get "status")
    mode=$(get_option "display_mode")
    hide_full=$(get_option "hide_when_full_and_charging")

    percent="${percent:-0}"

    # Hide when full and charging (plugin-specific behavior)
    if [[ "$hide_full" == "true" && "$percent" == "100" ]]; then
        case "$status" in
            charging|charged|ac_power)
                return  # Output nothing
                ;;
        esac
    fi

    # Note: show_only_on_threshold is handled by renderer via health

    # Render based on display mode
    case "$mode" in
        time)
            # Time mode - show remaining time
            # Don't show time when charging (doesn't make sense for "time to empty")
            if [[ "$status" == "discharging" ]]; then
                local time
                time=$(_get_time_remaining)
                if [[ -n "$time" && "$time" != "..." && "$time" != "0:00" ]]; then
                    printf '%s' "$time"
                    return
                fi
            fi
            # Fallback to percentage
            printf '%s%%' "$percent"
            ;;
        percentage|*)
            printf '%s%%' "$percent"
            ;;
    esac
}