#!/usr/bin/env bash
# =============================================================================
# Plugin: bluetooth
# Description: Display Bluetooth status and connected devices
# Type: conditional (always visible, shows different states)
# Dependencies: macOS: blueutil/system_profiler, Linux: bluetoothctl/hcitool
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    if is_macos; then
        require_cmd "blueutil" 1  # Optional on macOS
    else
        require_any_cmd "bluetoothctl" "hcitool" || return 1
    fi
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "show_when_off" "bool" "false" "Show plugin when Bluetooth is off"
    declare_option "show_device" "bool" "true" "Show connected device name"
    declare_option "show_battery" "bool" "false" "Show device battery level"
    declare_option "battery_type" "string" "min" "Battery display type (min|left|right|case|all)"
    declare_option "format" "string" "first" "Device display format (first|count|all)"
    declare_option "max_length" "number" "25" "Maximum device name length"

    # Icons
    declare_option "icon" "icon" $'\U000F00AF' "Plugin icon (default/on state)"
    declare_option "icon_off" "icon" $'\U000F00B2' "Icon when Bluetooth is off"
    declare_option "icon_connected" "icon" $'\U000F00B1' "Icon when device is connected"

    # Colors - Default (on state)
    declare_option "accent_color" "color" "secondary" "Background color (on state)"
    declare_option "accent_color_icon" "color" "active" "Icon background color (on state)"

    # Colors - Off state
    declare_option "off_accent_color" "color" "secondary" "Background color when off"
    declare_option "off_accent_color_icon" "color" "active" "Icon background color when off"

    # Colors - Connected state
    declare_option "connected_accent_color" "color" "success" "Background color when connected"
    declare_option "connected_accent_color_icon" "color" "success-strong" "Icon background color when connected"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

plugin_init "bluetooth"

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local status="${1%%:*}"
    local accent="" accent_icon="" icon=""
    case "$status" in
        off)
            icon=$(get_option "icon_off")
            accent=$(get_option "off_accent_color")
            accent_icon=$(get_option "off_accent_color_icon")
            ;;
        connected)
            icon=$(get_option "icon_connected")
            accent=$(get_option "connected_accent_color")
            accent_icon=$(get_option "connected_accent_color_icon")
            ;;
        on)
            accent=$(get_option "accent_color")
            accent_icon=$(get_option "accent_color_icon")
            ;;
    esac
    build_display_info "1" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Main Logic
# =============================================================================

_get_bt_macos() {
    if has_cmd blueutil; then
        [[ "$(blueutil -p)" == "0" ]] && { echo "off:"; return; }
        local devs="" line name mac bat sp_bat
        
        # Get battery info from system_profiler (since blueutil doesn't provide it for AirPods)
        local sp_info=$(system_profiler SPBluetoothDataType 2>/dev/null)
        
        while IFS= read -r line; do
            name=""
            mac=""
            bat=""
            [[ "$line" =~ name:\ \"([^\"]+)\" ]] && name="${BASH_REMATCH[1]}"
            [[ "$line" =~ address:\ ([0-9a-f:-]+) ]] && mac="${BASH_REMATCH[1]}"
            [[ -z "$name" ]] && continue
            
            # Try blueutil first (for devices that report battery)
            bat=$(blueutil --info "$mac" 2>/dev/null | grep -i battery | grep -oE '[0-9]+' | head -1)
            
            # Fallback to system_profiler for devices like AirPods
            local battery_info=""
            if [[ -z "$bat" && -n "$sp_info" ]]; then
                # Extract all battery information for this device
                # Use grep with device name, then AWK to extract batteries
                battery_info=$(echo "$sp_info" | grep -A 20 "$name" | awk '
                    /Battery Level:/ {
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
            
            [[ -n "$devs" ]] && devs+="|"
            # Format: name@battery_info (e.g. "AirPods@L=68:R=67:C=60" or "Magic Mouse@B=75")
            if [[ -n "$bat" ]]; then
                devs+="${name}@B=${bat}"
            elif [[ -n "$battery_info" ]]; then
                devs+="${name}@${battery_info}"
            else
                devs+="${name}@"
            fi
        done <<< "$(blueutil --connected 2>/dev/null)"
        [[ -n "$devs" ]] && echo "connected:$devs" || echo "on:"
        return
    fi

    has_cmd system_profiler || return 1
    local info=$(system_profiler SPBluetoothDataType 2>/dev/null)
    [[ -z "$info" ]] && return 1
    echo "$info" | grep -q "State: On" || { echo "off:"; return; }

    local devs=$(echo "$info" | awk '
        /^[[:space:]]+Connected:$/ { in_con=1; next }
        /^[[:space:]]+Not Connected:$/ { exit }
        in_con && /^[[:space:]]+[^[:space:]].*:$/ && !/Address:|Vendor|Product|Firmware|Minor|Serial|Chipset|State|Discoverable|Transport|Supported|RSSI|Services|Battery/ {
            if (dev != "") print dev "@" batteries
            gsub(/^[[:space:]]+|:$/, ""); dev=$0; batteries=""
        }
        in_con && /Battery Level:/ {
            # Extract battery type and value
            type = ""
            if (/Left/) type = "L"
            else if (/Right/) type = "R"
            else if (/Case/) type = "C"
            else type = "B"  # Generic battery
            
            match($0, /[0-9]+/)
            if (RSTART) {
                val = substr($0, RSTART, RLENGTH)
                if (batteries != "") batteries = batteries ":"
                batteries = batteries type "=" val
            }
        }
        END { if (dev != "") print dev "@" batteries }
    ' | tr '\n' '|' | sed 's/|$//')
    [[ -n "$devs" ]] && echo "connected:$devs" || echo "on:"
}

_get_bt_linux() {
    if has_cmd bluetoothctl; then
        local pwr
        pwr=$(timeout 2 bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2}') || return 1
        [[ -z "$pwr" ]] && return 1
        [[ "$pwr" != "yes" ]] && { echo "off:"; return; }
        local devs=""
        devs=$(timeout 2 bluetoothctl devices Connected 2>/dev/null | cut -d' ' -f3- | tr '\n' '|' | sed 's/|$//') || devs=""
        if [[ -z "$devs" ]]; then
            local mac name
            while read -r _ mac _; do
                [[ -z "$mac" ]] && continue
                timeout 2 bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes" || continue
                name=$(timeout 2 bluetoothctl info "$mac" 2>/dev/null | awk '/Name:/ {$1=""; print substr($0,2)}')
                [[ -n "$name" ]] && devs+="${devs:+|}$name"
            done <<< "$(timeout 2 bluetoothctl devices 2>/dev/null)"
        fi
        [[ -n "$devs" ]] && echo "connected:$devs" || echo "on:"
        return
    fi

    has_cmd hcitool || return 1
    hcitool dev 2>/dev/null | grep -q "hci" || { echo "off:"; return; }
    local mac=$(hcitool con 2>/dev/null | grep -v "Connections:" | head -1 | awk '{print $3}')
    if [[ -n "$mac" ]]; then
        local name=$(hcitool name "$mac" 2>/dev/null)
        echo "connected:${name:-Device}"
    else
        echo "on:"
    fi
}

_get_bt_info() { is_macos && _get_bt_macos || _get_bt_linux; }

_fmt_device() {
    local e="$1"
    local name="${e%%@*}"
    local battery_str="${e#*@}"

    local show_battery battery_type
    show_battery=$(get_option "show_battery")
    battery_type=$(get_option "battery_type")

    if [[ "$show_battery" != "true" || -z "$battery_str" ]]; then
        echo "$name"
        return
    fi

    # Parse battery info: B=75 or L=68:R=67:C=60
    declare -A bats
    local IFS=':'
    for bat_entry in $battery_str; do
        local type="${bat_entry%%=*}"
        local val="${bat_entry#*=}"
        [[ -n "$type" && -n "$val" ]] && bats[$type]="$val"
    done

    # Determine what to display based on battery_type
    # Note: Use ${bats[X]:-} syntax to avoid "unbound variable" error with set -eu
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
            local bat_parts=()
            [[ -n "${bats[L]:-}" ]] && bat_parts+=("L:${bats[L]}%")
            [[ -n "${bats[R]:-}" ]] && bat_parts+=("R:${bats[R]}%")
            [[ -n "${bats[C]:-}" ]] && bat_parts+=("C:${bats[C]}%")
            [[ -n "${bats[B]:-}" ]] && bat_parts+=("${bats[B]}%")
            bat_display=$(printf '%s / ' "${bat_parts[@]}" | sed 's/ \/ $//')
            ;;
        min|*)
            # For TWS (L/R): show minimum, ignore case
            # For single battery: show it
            if [[ -n "${bats[L]:-}" && -n "${bats[R]:-}" ]]; then
                local left=${bats[L]} right=${bats[R]}
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

load_plugin() {
    local cached
    if cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached"
        return 0
    fi

    local show_device format max_len
    show_device=$(get_option "show_device")
    format=$(get_option "format")
    max_len=$(get_option "max_length")

    local info=$(_get_bt_info)
    [[ -z "$info" ]] && return 0

    local status="${info%%:*}" devs="${info#*:}" result=""
    local show_when_off
    show_when_off=$(get_option "show_when_off")

    case "$status" in
        off)
            if [[ "$show_when_off" == "true" ]]; then
                result="off:OFF"
            else
                return 0
            fi
            ;;
        on) result="on:ON" ;;
        connected)
            if [[ "$show_device" == "true" && -n "$devs" ]]; then
                local txt="" cnt=$(echo "$devs" | tr '|' '\n' | wc -l | tr -d ' ')
                case "$format" in
                    count) [[ $cnt -eq 1 ]] && txt="1 device" || txt="$cnt devices" ;;
                    all)
                        local IFS='|'
                        for e in $devs; do
                            [[ -n "$txt" ]] && txt+=", "
                            txt+=$(_fmt_device "$e")
                        done
                        ;;
                    first|*) txt=$(_fmt_device "${devs%%|*}") ;;
                esac
                [[ ${#txt} -gt $max_len ]] && txt="${txt:0:$((max_len-1))}…"
                result="connected:$txt"
            else
                result="connected:Connected"
            fi
            ;;
    esac

    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { out=$(load_plugin); printf '%s' "${out#*:}"; } || true
