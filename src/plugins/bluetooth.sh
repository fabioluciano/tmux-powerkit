#!/usr/bin/env bash
# =============================================================================
# Plugin: bluetooth
# Description: Display Bluetooth status and connected devices with battery info
# Type: conditional (shows different states: off, on, connected)
# Dependencies: macOS: blueutil/system_profiler, Linux: bluetoothctl/hcitool
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - inactive: Bluetooth adapter is off or unavailable
#   - active: Bluetooth is on (no devices connected)
#   - active: Bluetooth is on with connected devices
#
# Health:
#   - ok: Bluetooth working normally
#   - info: Devices connected
#   - warning: Low battery on connected device (< 20%)
#
# Context:
#   - off: Bluetooth is disabled
#   - on: Bluetooth enabled, no connections
#   - connected: One or more devices connected
#
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "bluetooth"
    metadata_set "name" "Bluetooth"
    metadata_set "description" "Display Bluetooth status and connected devices"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    if is_macos; then
        require_cmd "blueutil" 1       # Optional but preferred
        require_cmd "system_profiler" 1 # Fallback
    else
        require_cmd "bluetoothctl" 1   # Preferred
        require_cmd "hcitool" 1        # Fallback
    fi
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options (visibility controlled by renderer via state/health)
    declare_option "show_device" "bool" "true" "Show connected device name"
    declare_option "show_battery" "bool" "true" "Show device battery level"
    declare_option "battery_type" "string" "min" "Battery display (min|left|right|case|all)"
    declare_option "format" "string" "all" "Device format (first|count|all)"
    declare_option "max_length" "number" "50" "Maximum device name length"

    # Icons
    declare_option "icon" "icon" $'\U000F00AF' "Default Bluetooth icon (on state)"
    declare_option "icon_off" "icon" $'\U000F00B2' "Icon when Bluetooth is off"
    declare_option "icon_connected" "icon" $'\U000F00B1' "Icon when device is connected"

    # Battery warning threshold
    declare_option "battery_warning_threshold" "number" "20" "Low battery warning threshold"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

# =============================================================================
# macOS Bluetooth Detection
# =============================================================================

# Get Bluetooth status and connected devices on macOS via blueutil
_get_bt_macos_blueutil() {
    has_cmd blueutil || return 1

    # Check power state
    [[ "$(blueutil -p 2>/dev/null)" == "0" ]] && { echo "off:"; return 0; }

    local devices="" line name mac bat sp_info battery_info

    # Get system_profiler info for battery details (AirPods, etc.)
    sp_info=$(system_profiler SPBluetoothDataType 2>/dev/null)

    while IFS= read -r line; do
        name="" mac="" bat=""

        # Parse blueutil output: name: "...", address: XX:XX:...
        [[ "$line" =~ name:\ \"([^\"]+)\" ]] && name="${BASH_REMATCH[1]}"
        [[ "$line" =~ address:\ ([0-9a-fA-F:-]+) ]] && mac="${BASH_REMATCH[1]}"
        [[ -z "$name" ]] && continue

        # Try blueutil for battery first
        bat=$(blueutil --info "$mac" 2>/dev/null | grep -i battery | grep -oE '[0-9]+' | head -1)

        # Fallback: system_profiler for devices like AirPods
        battery_info=""
        if [[ -z "$bat" && -n "$sp_info" ]]; then
            battery_info=$(echo "$sp_info" | awk -v device="$name" '
                # Start capturing when we find our device
                $0 ~ device ":" { in_device=1; next }
                # Stop when we hit another device or Not Connected section
                in_device && /^[[:space:]]+[A-Za-z].*:$/ && !/Battery Level:/ { exit }
                in_device && /Not Connected:/ { exit }
                # Capture battery info while in our device section
                in_device && /Battery Level:/ {
                    type = ""
                    if (/Left/) type = "L"
                    else if (/Right/) type = "R"
                    else if (/Case/) type = "C"
                    else type = "B"

                    match($0, /[0-9]+/)
                    if (RSTART) {
                        val = substr($0, RSTART, RLENGTH)
                        if (batteries != "") batteries = batteries ":"
                        batteries = batteries type "=" val
                    }
                }
                END { print batteries }
            ')
        fi

        [[ -n "$devices" ]] && devices+="|"
        if [[ -n "$bat" ]]; then
            devices+="${name}@B=${bat}"
        elif [[ -n "$battery_info" ]]; then
            devices+="${name}@${battery_info}"
        else
            devices+="${name}@"
        fi
    done <<< "$(blueutil --connected 2>/dev/null)"

    [[ -n "$devices" ]] && echo "connected:$devices" || echo "on:"
}

# Get Bluetooth status on macOS via system_profiler (fallback)
_get_bt_macos_profiler() {
    has_cmd system_profiler || return 1

    local info
    info=$(system_profiler SPBluetoothDataType 2>/dev/null)
    [[ -z "$info" ]] && return 1

    # Check if Bluetooth is on
    echo "$info" | grep -q "State: On" || { echo "off:"; return 0; }

    local devices
    devices=$(echo "$info" | awk '
        /^[[:space:]]+Connected:$/ { in_con=1; next }
        /^[[:space:]]+Not Connected:$/ { exit }
        in_con && /^[[:space:]]+[^[:space:]].*:$/ && !/Address:|Vendor|Product|Firmware|Minor|Serial|Chipset|State|Discoverable|Transport|Supported|RSSI|Services|Battery/ {
            if (dev != "") print dev "@" batteries
            gsub(/^[[:space:]]+|:$/, ""); dev=$0; batteries=""
        }
        in_con && /Battery Level:/ {
            type = ""
            if (/Left/) type = "L"
            else if (/Right/) type = "R"
            else if (/Case/) type = "C"
            else type = "B"

            match($0, /[0-9]+/)
            if (RSTART) {
                val = substr($0, RSTART, RLENGTH)
                if (batteries != "") batteries = batteries ":"
                batteries = batteries type "=" val
            }
        }
        END { if (dev != "") print dev "@" batteries }
    ')
    # Replace newlines with | using parameter expansion, then remove trailing |
    devices="${devices//$'\n'/|}"
    devices="${devices%|}"

    [[ -n "$devices" ]] && echo "connected:$devices" || echo "on:"
}

# macOS entry point
_get_bt_macos() {
    _get_bt_macos_blueutil 2>/dev/null || _get_bt_macos_profiler
}

# =============================================================================
# Linux Bluetooth Detection
# =============================================================================

# Get Bluetooth status via bluetoothctl
_get_bt_linux_bluetoothctl() {
    has_cmd bluetoothctl || return 1

    local power
    power=$(timeout 2 bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2}')
    [[ -z "$power" ]] && return 1
    [[ "$power" != "yes" ]] && { echo "off:"; return 0; }

    local devices=""

    # Try "devices Connected" first (newer bluetoothctl)
    local raw_devices
    raw_devices=$(timeout 2 bluetoothctl devices Connected 2>/dev/null | cut -d' ' -f3-)
    # Replace newlines with | using parameter expansion, then remove trailing |
    devices="${raw_devices//$'\n'/|}"
    devices="${devices%|}"

    # Fallback: check each device
    if [[ -z "$devices" ]]; then
        local mac name
        while read -r _ mac _; do
            [[ -z "$mac" ]] && continue
            timeout 2 bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes" || continue
            name=$(timeout 2 bluetoothctl info "$mac" 2>/dev/null | awk '/Name:/ {$1=""; print substr($0,2)}')
            [[ -n "$name" ]] && devices+="${devices:+|}${name}@"
        done <<< "$(timeout 2 bluetoothctl devices 2>/dev/null)"
    else
        # Add empty battery field for consistency using parameter expansion
        # devices="name1|name2|name3" -> "name1@|name2@|name3@"
        devices="${devices//|/@|}"
        devices="${devices}@"
    fi

    [[ -n "$devices" ]] && echo "connected:$devices" || echo "on:"
}

# Get Bluetooth status via hcitool (legacy fallback)
_get_bt_linux_hcitool() {
    has_cmd hcitool || return 1

    # Check if adapter exists
    hcitool dev 2>/dev/null | grep -q "hci" || { echo "off:"; return 0; }

    local mac name
    mac=$(hcitool con 2>/dev/null | grep -v "Connections:" | head -1 | awk '{print $3}')

    if [[ -n "$mac" ]]; then
        name=$(hcitool name "$mac" 2>/dev/null)
        echo "connected:${name:-Device}@"
    else
        echo "on:"
    fi
}

# Linux entry point
_get_bt_linux() {
    _get_bt_linux_bluetoothctl 2>/dev/null || _get_bt_linux_hcitool
}

# =============================================================================
# Battery Parsing
# =============================================================================

# Parse battery string and return formatted display
# Input: "L=68:R=67:C=60" or "B=75" or empty
# Output depends on battery_type option
_format_device_battery() {
    local name="$1"
    local battery_str="$2"
    local show_battery battery_type

    show_battery=$(get_option "show_battery")
    battery_type=$(get_option "battery_type")

    # No battery display requested or no battery data
    if [[ "$show_battery" != "true" || -z "$battery_str" ]]; then
        echo "$name"
        return
    fi

    # Só exibe bateria se houver valor numérico válido
    if ! echo "$battery_str" | grep -Eq '[0-9]'; then
        echo "$name"
        return
    fi

    # Parse battery info into associative array
    declare -A bats
    local IFS=':'
    for entry in $battery_str; do
        local type="${entry%%=*}"
        local val="${entry#*=}"
        [[ -n "$type" && -n "$val" ]] && bats[$type]="$val"
    done

    local bat_display=""
    case "$battery_type" in
        left)
            [[ -n "${bats[L]:-}" ]] && bat_display="L:${bats[L]}%"
            ;;
        right)
            [[ -n "${bats[R]:-}" ]] && bat_display="R:${bats[R]}%"
            ;;
        case)
            [[ -n "${bats[C]:-}" ]] && bat_display="C:${bats[C]}%"
            ;;
        all)
            local parts=()
            [[ -n "${bats[L]:-}" ]] && parts+=("L:${bats[L]}%")
            [[ -n "${bats[R]:-}" ]] && parts+=("R:${bats[R]}%")
            [[ -n "${bats[C]:-}" ]] && parts+=("C:${bats[C]}%")
            [[ -n "${bats[B]:-}" ]] && parts+=("${bats[B]}%")
            bat_display=$(printf '%s / ' "${parts[@]}" 2>/dev/null | sed 's/ \/ $//')
            ;;
        min|*)
            # For TWS (L/R): show minimum (ignore case)
            # For single battery: show it
            if [[ -n "${bats[L]:-}" && -n "${bats[R]:-}" ]]; then
                local left="${bats[L]}" right="${bats[R]}"
                local min=$((left < right ? left : right))
                bat_display="$min%"
            elif [[ -n "${bats[L]:-}" ]]; then
                bat_display="${bats[L]}%"
            elif [[ -n "${bats[R]:-}" ]]; then
                bat_display="${bats[R]}%"
            elif [[ -n "${bats[B]:-}" ]]; then
                bat_display="${bats[B]}%"
            elif [[ -n "${bats[C]:-}" ]]; then
                bat_display="${bats[C]}%"
            fi
            ;;
    esac

    [[ -n "$bat_display" ]] && echo "$name ($bat_display)" || echo "$name"
}

# Get minimum battery level from all connected devices
_get_min_battery() {
    local devices="$1"
    local min_bat=100

    local IFS='|'
    for dev in $devices; do
        local battery_str="${dev#*@}"
        [[ -z "$battery_str" ]] && continue

        for entry in ${battery_str//:/ }; do
            local val="${entry#*=}"
            [[ "$val" =~ ^[0-9]+$ ]] && (( val < min_bat )) && min_bat=$val
        done
    done

    echo "$min_bat"
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    local info

    if is_macos; then
        info=$(_get_bt_macos)
    else
        info=$(_get_bt_linux)
    fi

    [[ -z "$info" ]] && info="off:"

    local status="${info%%:*}"
    local devices="${info#*:}"

    plugin_data_set "status" "$status"
    plugin_data_set "devices" "$devices"

    # Count connected devices using parameter expansion (count | separators + 1)
    if [[ -n "$devices" && "$status" == "connected" ]]; then
        local count sep_only
        sep_only="${devices//[^|]/}"
        count=$(( ${#sep_only} + 1 ))
        plugin_data_set "device_count" "$count"
        plugin_data_set "min_battery" "$(_get_min_battery "$devices")"
    else
        plugin_data_set "device_count" "0"
        plugin_data_set "min_battery" "100"
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
# State reflects Bluetooth operational status:
#   - active: Bluetooth is on (with or without devices)
#   - inactive: Bluetooth is off

plugin_get_state() {
    local status
    status=$(plugin_data_get "status")

    case "$status" in
        on|connected) printf 'active' ;;
        *)            printf 'inactive' ;;
    esac
}

# =============================================================================
# Plugin Contract: Health
# =============================================================================
# Health reflects device battery status:
#   - ok: No devices or all batteries > threshold
#   - info: Devices connected (informational)
#   - warning: Low battery on connected device

plugin_get_health() {
    local status min_bat warn_th
    status=$(plugin_data_get "status")
    min_bat=$(plugin_data_get "min_battery")
    warn_th=$(get_option "battery_warning_threshold")

    min_bat="${min_bat:-100}"
    warn_th="${warn_th:-20}"

    # Bluetooth on with no devices: info
    if [[ "$status" == "on" ]]; then
        printf 'info'
        return
    fi

    # Connected: warning if low battery, otherwise ok
    if [[ "$status" == "connected" ]]; then
        if (( min_bat < warn_th )); then
            printf 'warning'
        else
            printf 'good'
        fi
        return
    fi

    printf 'good'
}

# =============================================================================
# Plugin Contract: Context
# =============================================================================
# Context provides Bluetooth state:
#   - off, on, connected

plugin_get_context() {
    local status
    status=$(plugin_data_get "status")
    printf '%s' "${status:-off}"
}

# =============================================================================
# Plugin Contract: Icon
# =============================================================================

plugin_get_icon() {
    local status
    status=$(plugin_data_get "status")

    case "$status" in
        connected) get_option "icon_connected" ;;
        on)        get_option "icon" ;;
        *)         get_option "icon_off" ;;
    esac
}

# =============================================================================
# Plugin Contract: Render
# =============================================================================

plugin_render() {
    local status devices format max_len
    status=$(plugin_data_get "status")
    devices=$(plugin_data_get "devices")
    format=$(get_option "format")
    max_len=$(get_option "max_length")
    max_len="${max_len:-25}"

    case "$status" in
        off)
            # Não exibe nada quando off
            return
            ;;
        on)
            printf 'ON'
            ;;
        connected)
            if [[ -n "$devices" ]]; then
                local text="" count
                count=$(plugin_data_get "device_count")

                case "$format" in
                    count)
                        if [[ "$count" == "1" ]]; then
                            text="1 device"
                        else
                            text="$count devices"
                        fi
                        ;;
                    all)
                        local device_names=()
                        local IFS='|'
                        for dev in $devices; do
                            local name="${dev%%@*}"
                            local bat="${dev#*@}"
                            device_names+=("$(_format_device_battery "$name" "$bat")")
                        done
                        text=$(join_with_separator " | " "${device_names[@]}")
                        ;;
                    first|*)
                        local first="${devices%%|*}"
                        local name="${first%%@*}"
                        local bat="${first#*@}"
                        text=$(_format_device_battery "$name" "$bat")
                        ;;
                esac

                # Truncate at word boundary if necessary
                if [[ ${#text} -gt $max_len ]]; then
                    text=$(truncate_words "$text" "$max_len" "…")
                fi

                printf '%s' "$text"
            else
                printf 'Connected'
            fi
            ;;
    esac
}

# =============================================================================
# Initialize Plugin
# =============================================================================

