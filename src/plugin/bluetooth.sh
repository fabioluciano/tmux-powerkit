#!/usr/bin/env bash
# Plugin: bluetooth - Display Bluetooth status and connected devices

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "bluetooth"

# Configuration
_show_device=$(get_tmux_option "@powerkit_plugin_bluetooth_show_device" "$POWERKIT_PLUGIN_BLUETOOTH_SHOW_DEVICE")
_show_battery=$(get_tmux_option "@powerkit_plugin_bluetooth_show_battery" "$POWERKIT_PLUGIN_BLUETOOTH_SHOW_BATTERY")
_battery_type=$(get_tmux_option "@powerkit_plugin_bluetooth_battery_type" "${POWERKIT_PLUGIN_BLUETOOTH_BATTERY_TYPE:-min}")
_format=$(get_tmux_option "@powerkit_plugin_bluetooth_format" "$POWERKIT_PLUGIN_BLUETOOTH_FORMAT")
_max_len=$(get_tmux_option "@powerkit_plugin_bluetooth_max_length" "$POWERKIT_PLUGIN_BLUETOOTH_MAX_LENGTH")

# macOS: blueutil or system_profiler
get_bt_macos() {
    if require_cmd blueutil 1; then
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

    require_cmd system_profiler 1 || return 1
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

# Linux: bluetoothctl or hcitool
get_bt_linux() {
    if require_cmd bluetoothctl 1; then
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

    require_cmd hcitool 1 || return 1
    hcitool dev 2>/dev/null | grep -q "hci" || { echo "off:"; return; }
    local mac=$(hcitool con 2>/dev/null | grep -v "Connections:" | head -1 | awk '{print $3}')
    if [[ -n "$mac" ]]; then
        local name=$(hcitool name "$mac" 2>/dev/null)
        echo "connected:${name:-Device}"
    else
        echo "on:"
    fi
}

get_bt_info() { is_macos && get_bt_macos || get_bt_linux; }

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local status="${1%%:*}"
    local accent="" accent_icon="" icon=""
    case "$status" in
        off)
            icon=$(get_cached_option "@powerkit_plugin_bluetooth_icon_off" "$POWERKIT_PLUGIN_BLUETOOTH_ICON_OFF")
            accent=$(get_cached_option "@powerkit_plugin_bluetooth_off_accent_color" "$POWERKIT_PLUGIN_BLUETOOTH_OFF_ACCENT_COLOR")
            accent_icon=$(get_cached_option "@powerkit_plugin_bluetooth_off_accent_color_icon" "$POWERKIT_PLUGIN_BLUETOOTH_OFF_ACCENT_COLOR_ICON")
            ;;
        connected)
            icon=$(get_cached_option "@powerkit_plugin_bluetooth_icon_connected" "$POWERKIT_PLUGIN_BLUETOOTH_ICON_CONNECTED")
            accent=$(get_cached_option "@powerkit_plugin_bluetooth_connected_accent_color" "$POWERKIT_PLUGIN_BLUETOOTH_CONNECTED_ACCENT_COLOR")
            accent_icon=$(get_cached_option "@powerkit_plugin_bluetooth_connected_accent_color_icon" "$POWERKIT_PLUGIN_BLUETOOTH_CONNECTED_ACCENT_COLOR_ICON")
            ;;
        on)
            accent=$(get_cached_option "@powerkit_plugin_bluetooth_accent_color" "$POWERKIT_PLUGIN_BLUETOOTH_ACCENT_COLOR")
            accent_icon=$(get_cached_option "@powerkit_plugin_bluetooth_accent_color_icon" "$POWERKIT_PLUGIN_BLUETOOTH_ACCENT_COLOR_ICON")
            ;;
    esac
    build_display_info "1" "$accent" "$accent_icon" "$icon"
}

fmt_device() {
    local e="$1"
    local name="${e%%@*}"
    local battery_str="${e#*@}"
    
    if [[ "$_show_battery" != "true" || -z "$battery_str" ]]; then
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
    local bat_display=""
    case "$_battery_type" in
        left)
            [[ -n "${bats[L]}" ]] && bat_display="L:${bats[L]}%"
            ;;
        right)
            [[ -n "${bats[R]}" ]] && bat_display="R:${bats[R]}%"
            ;;
        case)
            [[ -n "${bats[C]}" ]] && bat_display="C:${bats[C]}%"
            ;;
        all)
            local bat_parts=()
            [[ -n "${bats[L]}" ]] && bat_parts+=("L:${bats[L]}%")
            [[ -n "${bats[R]}" ]] && bat_parts+=("R:${bats[R]}%")
            [[ -n "${bats[C]}" ]] && bat_parts+=("C:${bats[C]}%")
            [[ -n "${bats[B]}" ]] && bat_parts+=("${bats[B]}%")
            bat_display=$(printf '%s / ' "${bat_parts[@]}" | sed 's/ \/ $//')
            ;;
        min|*)
            # For TWS (L/R): show minimum, ignore case
            # For single battery: show it
            if [[ -n "${bats[L]}" && -n "${bats[R]}" ]]; then
                local left=${bats[L]} right=${bats[R]}
                local min=$((left < right ? left : right))
                bat_display="$min%"
            elif [[ -n "${bats[L]}" ]]; then
                bat_display="${bats[L]}%"
            elif [[ -n "${bats[R]}" ]]; then
                bat_display="${bats[R]}%"
            elif [[ -n "${bats[B]}" ]]; then
                bat_display="${bats[B]}%"
            elif [[ -n "${bats[C]}" ]]; then
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

    local info=$(get_bt_info)
    [[ -z "$info" ]] && return 0

    local status="${info%%:*}" devs="${info#*:}" result=""
    case "$status" in
        off) return 0 ;;
        on) result="on:ON" ;;
        connected)
            if [[ "$_show_device" == "true" && -n "$devs" ]]; then
                local txt="" cnt=$(echo "$devs" | tr '|' '\n' | wc -l | tr -d ' ')
                case "$_format" in
                    count) [[ $cnt -eq 1 ]] && txt="1 device" || txt="$cnt devices" ;;
                    all)
                        local IFS='|'
                        for e in $devs; do
                            [[ -n "$txt" ]] && txt+=", "
                            txt+=$(fmt_device "$e")
                        done
                        ;;
                    first|*) txt=$(fmt_device "${devs%%|*}") ;;
                esac
                [[ ${#txt} -gt $_max_len ]] && txt="${txt:0:$((_max_len-1))}…"
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
