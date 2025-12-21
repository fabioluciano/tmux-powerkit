#!/usr/bin/env bash
# =============================================================================
# Plugin: wifi
# Description: Display WiFi network name and signal strength
# Type: conditional (hidden when disconnected or per option)
# Dependencies: networksetup (macOS), nmcli/iw/iwconfig (Linux - optional)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    if is_macos; then
        require_cmd "networksetup" 1  # Built-in, should always exist
    else
        require_any_cmd "nmcli" "iw" "iwconfig" 1  # Optional on Linux
    fi
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "show_ssid" "bool" "true" "Show WiFi network name"
    declare_option "show_ip" "bool" "false" "Show IP address instead of SSID"
    declare_option "show_signal" "bool" "false" "Show signal strength percentage"
    declare_option "hide_when_connected" "bool" "false" "Hide plugin when WiFi is connected"

    # Icons
    declare_option "icon" "icon" "󰤨" "Plugin icon"
    declare_option "icon_disconnected" "icon" "󰖪" "Icon when disconnected"

    # Colors - Default
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Colors - Disconnected state
    declare_option "disconnected_accent_color" "color" "error" "Background color when disconnected"
    declare_option "disconnected_accent_color_icon" "color" "error-strong" "Icon background color when disconnected"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

plugin_init "wifi"

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="${1:-}"
    local show="1" accent="" accent_icon="" icon=""

    if [[ -z "$content" || "$content" == "n/a" || "$content" == "N/A" ]]; then
        icon=$(get_option "icon_disconnected")
        accent=$(get_option "disconnected_accent_color")
        accent_icon=$(get_option "disconnected_accent_color_icon")
    else
        local hide_connected
        hide_connected=$(get_option "hide_when_connected")
        [[ "$hide_connected" == "true" ]] && { build_display_info "0" "" "" ""; return; }

        local show_signal
        show_signal=$(get_option "show_signal")
        if [[ "$show_signal" == "true" ]]; then
            # Use bash regex instead of echo | grep (performance: avoids fork)
            local signal=""
            [[ "$content" =~ ([0-9]+)% ]] && signal="${BASH_REMATCH[1]}"
            [[ -n "$signal" ]] && icon=$(_get_signal_icon "$signal")
        fi
    fi

    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Helper Functions - macOS
# =============================================================================

_get_wifi_macos_ipconfig() {
    local ssid
    ssid=$(ipconfig getsummary en0 2>/dev/null | awk '/ SSID :/{print $3}')
    [[ -n "$ssid" && "$ssid" != "<redacted>" && "$ssid" != *"redacted"* ]] && { printf '%s:75' "$ssid"; return 0; }
    return 1
}

_get_wifi_macos_system_profiler() {
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

_get_wifi_macos_airport() {
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

_get_wifi_macos_networksetup() {
    has_cmd networksetup || return 1
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

_get_wifi_macos() { _get_wifi_macos_ipconfig || _get_wifi_macos_system_profiler || _get_wifi_macos_airport || _get_wifi_macos_networksetup; }

# =============================================================================
# Helper Functions - Linux
# =============================================================================

_get_wifi_linux_nmcli() {
    has_cmd nmcli || return 1
    nmcli -t -f active,ssid,signal dev wifi 2>/dev/null | awk -F: '/^yes:/ && $2 != "" {gsub(/"/, "", $2); printf "%s:%d\n", $2, ($3 ? $3 : 0); exit 0} END {exit 1}'
}

_get_wifi_linux_iw() {
    has_cmd iw || return 1
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

_get_wifi_linux_iwconfig() {
    has_cmd iwconfig || return 1
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

_get_wifi_info() {
    is_macos && { _get_wifi_macos; return; }
    is_linux && { _get_wifi_linux_nmcli || _get_wifi_linux_iw || _get_wifi_linux_iwconfig; return; }
}

_get_wifi_ip() {
    local ip=""
    if is_macos; then
        ip=$(ipconfig getifaddr en0 2>/dev/null)
        [[ -z "$ip" ]] && { local iface; iface=$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi|AirPort/{getline; print $2}'); [[ -n "$iface" ]] && ip=$(ipconfig getifaddr "$iface" 2>/dev/null); }
    elif is_linux; then
        local iface
        has_cmd iw && iface=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
        for i in ${iface:-wlan0} wlan0 wlp0s20f3 wlp2s0; do
            ip=$(ip -4 addr show "$i" 2>/dev/null | awk '/inet /{print $2}' | cut -d'/' -f1)
            [[ -n "$ip" ]] && break
        done
        [[ -z "$ip" ]] && ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    printf '%s' "$ip"
}

_get_signal_icon() {
    local signal="$1"
    (( signal <= 20 )) && { printf '󰤯'; return; }
    (( signal <= 40 )) && { printf '󰤟'; return; }
    (( signal <= 60 )) && { printf '󰤢'; return; }
    (( signal <= 80 )) && { printf '󰤥'; return; }
    printf '󰤨'
}

# =============================================================================
# Main Logic
# =============================================================================

load_plugin() {
    local cached_value
    if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached_value"
        return 0
    fi

    local wifi_info
    wifi_info=$(_get_wifi_info)

    if [[ -z "$wifi_info" ]]; then
        cache_set "$CACHE_KEY" "N/A"
        printf 'N/A'
        return 0
    fi

    local ssid="${wifi_info%%:*}" signal="${wifi_info##*:}"
    local show_ssid show_ip show_signal display_text="" result
    show_ssid=$(get_option "show_ssid")
    show_ip=$(get_option "show_ip")
    show_signal=$(get_option "show_signal")

    [[ "$show_ip" == "true" ]] && display_text=$(_get_wifi_ip)
    [[ -z "$display_text" && "$show_ssid" == "true" ]] && display_text="$ssid"
    [[ -z "$display_text" ]] && display_text="$ssid"

    [[ "$show_signal" == "true" && -n "$display_text" ]] && result="${display_text} (${signal}%)" || result="$display_text"

    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
