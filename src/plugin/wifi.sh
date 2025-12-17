#!/usr/bin/env bash
# Plugin: wifi - Display WiFi network name and signal strength

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "wifi"

plugin_get_type() { printf 'conditional'; }

# macOS methods
get_wifi_macos_ipconfig() {
    local ssid
    ssid=$(ipconfig getsummary en0 2>/dev/null | awk '/ SSID :/{print $3}')
    [[ -n "$ssid" && "$ssid" != "<redacted>" && "$ssid" != *"redacted"* ]] && { printf '%s:75' "$ssid"; return 0; }
    return 1
}

get_wifi_macos_system_profiler() {
    local wifi_data
    wifi_data=$(system_profiler SPAirPortDataType 2>/dev/null | awk '
        /Status: Connected/ {connected = 1}
        /Current Network Information:/ {if (connected) getline; gsub(/^[[:space:]]+|:$/, ""); ssid = $0}
        /RSSI:/ {if (connected) {gsub(/[^-0-9]/, ""); rssi = $0}}
        END {if (connected && ssid) print ssid ":" rssi; else exit 1}
    ')
    [[ -z "$wifi_data" ]] && return 1
    
    local ssid="${wifi_data%%:*}" rssi="${wifi_data##*:}"
    [[ -z "$ssid" || "$ssid" == "<redacted>" || "$ssid" == *"redacted"* ]] && ssid="WiFi"
    
    local signal=75
    [[ -n "$rssi" && "$rssi" =~ ^-?[0-9]+$ ]] && { signal=$(( (rssi + 100) * 100 / 70 )); (( signal > 100 )) && signal=100; (( signal < 0 )) && signal=0; }
    printf '%s:%d' "$ssid" "$signal"
}

get_wifi_macos_airport() {
    local airport="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
    [[ -x "$airport" ]] || return 1
    local info=$("$airport" -I 2>/dev/null)
    [[ -z "$info" ]] && return 1
    echo "$info" | grep -qE "AirPort: Off|state: init" && return 1
    
    local ssid signal
    ssid=$(echo "$info" | awk -F': ' '/ SSID:/ {print $2}')
    signal=$(echo "$info" | awk -F': ' '/agrCtlRSSI:/ {print $2}')
    [[ -z "$ssid" ]] && return 1
    
    local signal_percent=75
    [[ -n "$signal" ]] && { signal_percent=$(( (signal + 100) * 100 / 70 )); (( signal_percent > 100 )) && signal_percent=100; (( signal_percent < 0 )) && signal_percent=0; }
    printf '%s:%d' "$ssid" "$signal_percent"
}

get_wifi_macos_networksetup() {
    require_cmd networksetup 1 || return 1
    local wifi_interface
    wifi_interface=$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi|AirPort/{getline; print $2}')
    [[ -z "$wifi_interface" ]] && wifi_interface="en0"
    local output
    output=$(networksetup -getairportnetwork "$wifi_interface" 2>/dev/null)
    echo "$output" | grep -q "not associated" && return 1
    local ssid=${output#Current Wi-Fi Network: }
    [[ -z "$ssid" ]] && return 1
    printf '%s:75' "$ssid"
}

get_wifi_macos() { get_wifi_macos_ipconfig || get_wifi_macos_system_profiler || get_wifi_macos_airport || get_wifi_macos_networksetup; }

# Linux methods
get_wifi_linux_nmcli() {
    require_cmd nmcli 1 || return 1
    nmcli -t -f active,ssid,signal dev wifi 2>/dev/null | awk -F: '/^yes:/ && $2 != "" {gsub(/"/, "", $2); printf "%s:%d\n", $2, ($3 ? $3 : 0); exit 0} END {exit 1}'
}

get_wifi_linux_iw() {
    require_cmd iw 1 || return 1
    local interface
    interface=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
    [[ -z "$interface" ]] && return 1
    local info
    info=$(iw dev "$interface" link 2>/dev/null)
    echo "$info" | grep -q "Not connected" && return 1
    local ssid
    ssid=$(echo "$info" | awk -F': ' '/SSID:/{print $2}')
    [[ -z "$ssid" ]] && return 1
    local level signal=0
    level=$(echo "$info" | awk '/signal:/{print $2}')
    [[ -n "$level" ]] && { signal=$(( (level + 100) * 100 / 70 )); (( signal > 100 )) && signal=100; (( signal < 0 )) && signal=0; }
    printf '%s:%d' "$ssid" "$signal"
}

get_wifi_linux_iwconfig() {
    require_cmd iwconfig 1 || return 1
    local interface
    interface=$(iwconfig 2>&1 | grep -o "^[a-zA-Z0-9]*" | head -1)
    [[ -z "$interface" ]] && return 1
    local info
    info=$(iwconfig "$interface" 2>/dev/null)
    echo "$info" | grep -q "ESSID:off/any" && return 1
    local ssid
    ssid=$(echo "$info" | grep -o 'ESSID:"[^"]*"' | cut -d'"' -f2)
    [[ -z "$ssid" ]] && return 1
    local quality signal=0
    quality=$(echo "$info" | grep -o 'Quality=[0-9]*/[0-9]*' | cut -d'=' -f2)
    [[ -n "$quality" ]] && { local cur=${quality%%/*} max=${quality##*/}; signal=$(( cur * 100 / max )); }
    printf '%s:%d' "$ssid" "$signal"
}

get_wifi_info() {
    is_macos && { get_wifi_macos; return; }
    is_linux && { get_wifi_linux_nmcli || get_wifi_linux_iw || get_wifi_linux_iwconfig; return; }
}

get_wifi_ip() {
    local ip=""
    if is_macos; then
        ip=$(ipconfig getifaddr en0 2>/dev/null)
        [[ -z "$ip" ]] && { local iface; iface=$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi|AirPort/{getline; print $2}'); [[ -n "$iface" ]] && ip=$(ipconfig getifaddr "$iface" 2>/dev/null); }
    elif is_linux; then
        local iface
        require_cmd iw 1 && iface=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
        for i in ${iface:-wlan0} wlan0 wlp0s20f3 wlp2s0; do
            ip=$(ip -4 addr show "$i" 2>/dev/null | awk '/inet /{print $2}' | cut -d'/' -f1)
            [[ -n "$ip" ]] && break
        done
        [[ -z "$ip" ]] && ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    printf '%s' "$ip"
}

get_signal_icon() {
    local signal="$1"
    (( signal <= 20 )) && { printf '󰤯'; return; }
    (( signal <= 40 )) && { printf '󰤟'; return; }
    (( signal <= 60 )) && { printf '󰤢'; return; }
    (( signal <= 80 )) && { printf '󰤥'; return; }
    printf '󰤨'
}

plugin_get_display_info() {
    local content="${1:-}"
    local show="1" accent="" accent_icon="" icon=""
    
    if [[ -z "$content" || "$content" == "n/a" || "$content" == "N/A" ]]; then
        icon=$(get_cached_option "@powerkit_plugin_wifi_icon_disconnected" "$POWERKIT_PLUGIN_WIFI_ICON_DISCONNECTED")
        accent=$(get_cached_option "@powerkit_plugin_wifi_disconnected_accent_color" "$POWERKIT_PLUGIN_WIFI_DISCONNECTED_ACCENT_COLOR")
        accent_icon=$(get_cached_option "@powerkit_plugin_wifi_disconnected_accent_color_icon" "$POWERKIT_PLUGIN_WIFI_DISCONNECTED_ACCENT_COLOR_ICON")
    else
        local hide_connected
        hide_connected=$(get_cached_option "@powerkit_plugin_wifi_hide_when_connected" "$POWERKIT_PLUGIN_WIFI_HIDE_WHEN_CONNECTED")
        [[ "$hide_connected" == "true" ]] && { build_display_info "0" "" "" ""; return; }
        
        local show_signal
        show_signal=$(get_cached_option "@powerkit_plugin_wifi_show_signal" "$POWERKIT_PLUGIN_WIFI_SHOW_SIGNAL")
        if [[ "$show_signal" == "true" ]]; then
            local signal
            signal=$(echo "$content" | grep -oE '[0-9]+%' | tr -d '%')
            [[ -n "$signal" ]] && icon=$(get_signal_icon "$signal")
        fi
    fi
    
    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

load_plugin() {
    local cached_value
    if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached_value"
        return 0
    fi
    
    local wifi_info
    wifi_info=$(get_wifi_info)
    
    if [[ -z "$wifi_info" ]]; then
        cache_set "$CACHE_KEY" "N/A"
        printf 'N/A'
        return 0
    fi
    
    local ssid="${wifi_info%%:*}" signal="${wifi_info##*:}"
    local show_ssid show_ip show_signal display_text="" result
    show_ssid=$(get_cached_option "@powerkit_plugin_wifi_show_ssid" "$POWERKIT_PLUGIN_WIFI_SHOW_SSID")
    show_ip=$(get_cached_option "@powerkit_plugin_wifi_show_ip" "$POWERKIT_PLUGIN_WIFI_SHOW_IP")
    show_signal=$(get_cached_option "@powerkit_plugin_wifi_show_signal" "$POWERKIT_PLUGIN_WIFI_SHOW_SIGNAL")
    
    [[ "$show_ip" == "true" ]] && display_text=$(get_wifi_ip)
    [[ -z "$display_text" && "$show_ssid" == "true" ]] && display_text="$ssid"
    [[ -z "$display_text" ]] && display_text="$ssid"
    
    [[ "$show_signal" == "true" && -n "$display_text" ]] && result="${display_text} (${signal}%)" || result="$display_text"
    
    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
