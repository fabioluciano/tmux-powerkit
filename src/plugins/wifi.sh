#!/usr/bin/env bash
# =============================================================================
# Plugin: wifi
# Description: Display WiFi network name, IP and signal strength
# Type: conditional (hidden when disconnected unless configured)
# Dependencies: networksetup/ipconfig/airport (macOS), nmcli/iw/iwconfig (Linux)
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active: Connected to WiFi network
#   - inactive: Not connected to any WiFi
#
# Health:
#   - ok: Good signal strength (> 60%)
#   - warning: Weak signal (20-60%)
#   - error: Very weak signal (< 20%)
#
# Context:
#   - connected: Connected to WiFi
#   - disconnected: Not connected
#
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "wifi"
    metadata_set "name" "WiFi"
    metadata_set "description" "Display WiFi status, SSID, IP and signal strength"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    if is_macos; then
        require_cmd "networksetup" 1   # Built-in
        require_cmd "ipconfig" 1       # Built-in
        require_cmd "system_profiler" 1
    else
        require_cmd "nmcli" 1
        require_cmd "iw" 1
        require_cmd "iwconfig" 1
    fi
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Visibility: connected, disconnected, always
    declare_option "show_when" "string" "connected" "When to show: connected, disconnected, always"

    # Display format: ssid, ip, signal (comma-separated for multiple: ssid,signal)
    declare_option "format" "string" "ssid" "Display format: ssid, ip, signal (e.g., ssid,signal)"
    declare_option "separator" "string" " | " "Separator for composite format"
    declare_option "max_length" "number" "20" "Maximum length for display text"

    # Icons - signal-based
    declare_option "icon" "icon" $'\U000F092F' "WiFi connected (full signal)"
    declare_option "icon_excellent" "icon" $'\U000F0928' "Excellent signal (80-100%)"
    declare_option "icon_good" "icon" $'\U000F0925' "Good signal (60-80%)"
    declare_option "icon_fair" "icon" $'\U000F0922' "Fair signal (40-60%)"
    declare_option "icon_weak" "icon" $'\U000F091F' "Weak signal (20-40%)"
    declare_option "icon_poor" "icon" $'\U000F092B' "Poor/no signal (0-20%)"
    declare_option "icon_disconnected" "icon" $'\U000F092E' "Disconnected icon"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

# =============================================================================
# macOS WiFi Detection - Multiple Methods
# =============================================================================

# Method 1: ipconfig (fastest, requires Location Services)
_get_wifi_macos_ipconfig() {
    local ssid
    ssid=$(ipconfig getsummary en0 2>/dev/null | awk '/ SSID :/{print $3}')
    [[ -n "$ssid" && "$ssid" != "<redacted>" && "$ssid" != *"redacted"* ]] && {
        printf '%s:75' "$ssid"
        return 0
    }
    return 1
}

# Method 2: system_profiler (comprehensive, slower)
_get_wifi_macos_system_profiler() {
    local wifi_data
    wifi_data=$(system_profiler SPAirPortDataType 2>/dev/null | awk '
        /Status: Connected/ {connected = 1}
        /Current Network Information:/ {if (connected) {getline; gsub(/^[[:space:]]+|:$/, ""); ssid = $0}}
        /RSSI:/ {if (connected) {gsub(/[^-0-9]/, ""); rssi = $0}}
        END {if (connected && ssid) print ssid ":" rssi; else exit 1}
    ')
    [[ -z "$wifi_data" ]] && return 1

    local ssid="${wifi_data%%:*}" rssi="${wifi_data##*:}"
    [[ -z "$ssid" || "$ssid" == "<redacted>" || "$ssid" == *"redacted"* ]] && ssid="WiFi"

    # Convert RSSI to percentage (RSSI -100 = 0%, -50 = 100%)
    local signal=75
    if [[ -n "$rssi" && "$rssi" =~ ^-?[0-9]+$ ]]; then
        signal=$(( (rssi + 100) * 100 / 50 ))
        (( signal > 100 )) && signal=100
        (( signal < 0 )) && signal=0
    fi
    printf '%s:%d' "$ssid" "$signal"
}

# Method 3: airport utility (deprecated but reliable)
_get_wifi_macos_airport() {
    local airport="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
    [[ -x "$airport" ]] || return 1

    local info
    info=$("$airport" -I 2>/dev/null)
    [[ -z "$info" ]] && return 1
    echo "$info" | grep -qE "AirPort: Off|state: init" && return 1

    local ssid signal
    ssid=$(echo "$info" | awk -F': ' '/ SSID:/ {print $2}')
    signal=$(echo "$info" | awk -F': ' '/agrCtlRSSI:/ {print $2}')
    [[ -z "$ssid" ]] && return 1

    local signal_percent=75
    if [[ -n "$signal" ]]; then
        signal_percent=$(( (signal + 100) * 100 / 50 ))
        (( signal_percent > 100 )) && signal_percent=100
        (( signal_percent < 0 )) && signal_percent=0
    fi
    printf '%s:%d' "$ssid" "$signal_percent"
}

# Method 4: networksetup (fallback)
_get_wifi_macos_networksetup() {
    has_cmd networksetup || return 1

    local wifi_interface
    wifi_interface=$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi|AirPort/{getline; print $2}')
    [[ -z "$wifi_interface" ]] && wifi_interface="en0"

    local output
    output=$(networksetup -getairportnetwork "$wifi_interface" 2>/dev/null)
    echo "$output" | grep -q "not associated" && return 1

    local ssid="${output#Current Wi-Fi Network: }"
    [[ -z "$ssid" ]] && return 1
    printf '%s:75' "$ssid"
}

# macOS entry point - try all methods
_get_wifi_macos() {
    _get_wifi_macos_ipconfig 2>/dev/null ||
    _get_wifi_macos_system_profiler 2>/dev/null ||
    _get_wifi_macos_airport 2>/dev/null ||
    _get_wifi_macos_networksetup
}

# =============================================================================
# Linux WiFi Detection - Multiple Methods
# =============================================================================

# Method 1: nmcli (NetworkManager)
_get_wifi_linux_nmcli() {
    has_cmd nmcli || return 1

    local line
    line=$(nmcli -t -f active,ssid,signal dev wifi 2>/dev/null | awk -F: '
        /^yes:/ && $2 != "" {
            gsub(/"/, "", $2)
            printf "%s:%d", $2, ($3 ? $3 : 0)
            exit 0
        }
        END {exit 1}
    ')
    [[ -n "$line" ]] && printf '%s' "$line"
}

# Method 2: iw (modern)
_get_wifi_linux_iw() {
    has_cmd iw || return 1

    local interface
    interface=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
    [[ -z "$interface" ]] && return 1

    local info
    info=$(iw dev "$interface" link 2>/dev/null)
    echo "$info" | grep -q "Not connected" && return 1

    local ssid level signal
    ssid=$(echo "$info" | awk -F': ' '/SSID:/{print $2}')
    [[ -z "$ssid" ]] && return 1

    level=$(echo "$info" | awk '/signal:/{print $2}')
    signal=75
    if [[ -n "$level" ]]; then
        signal=$(( (level + 100) * 100 / 50 ))
        (( signal > 100 )) && signal=100
        (( signal < 0 )) && signal=0
    fi
    printf '%s:%d' "$ssid" "$signal"
}

# Method 3: iwconfig (legacy)
_get_wifi_linux_iwconfig() {
    has_cmd iwconfig || return 1

    local interface
    interface=$(iwconfig 2>&1 | grep -o "^[a-zA-Z0-9]*" | head -1)
    [[ -z "$interface" ]] && return 1

    local info
    info=$(iwconfig "$interface" 2>/dev/null)
    echo "$info" | grep -q 'ESSID:off/any' && return 1

    local ssid
    ssid=$(echo "$info" | grep -o 'ESSID:"[^"]*"' | cut -d'"' -f2)
    [[ -z "$ssid" ]] && return 1

    local quality signal=75
    quality=$(echo "$info" | grep -o 'Quality=[0-9]*/[0-9]*' | cut -d'=' -f2)
    if [[ -n "$quality" ]]; then
        local cur="${quality%%/*}" max="${quality##*/}"
        signal=$(( cur * 100 / max ))
    fi
    printf '%s:%d' "$ssid" "$signal"
}

# Linux entry point
_get_wifi_linux() {
    _get_wifi_linux_nmcli 2>/dev/null ||
    _get_wifi_linux_iw 2>/dev/null ||
    _get_wifi_linux_iwconfig
}

# =============================================================================
# IP Address Detection
# =============================================================================

_get_wifi_ip() {
    local ip=""

    if is_macos; then
        ip=$(ipconfig getifaddr en0 2>/dev/null)
        if [[ -z "$ip" ]]; then
            local iface
            iface=$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi|AirPort/{getline; print $2}')
            [[ -n "$iface" ]] && ip=$(ipconfig getifaddr "$iface" 2>/dev/null)
        fi
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

# =============================================================================
# Signal Icon Selection
# =============================================================================

_get_signal_icon() {
    local signal="${1:-0}"

    if (( signal >= 80 )); then
        get_option "icon_excellent"
    elif (( signal >= 60 )); then
        get_option "icon_good"
    elif (( signal >= 40 )); then
        get_option "icon_fair"
    elif (( signal >= 20 )); then
        get_option "icon_weak"
    else
        get_option "icon_poor"
    fi
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    local wifi_info

    if is_macos; then
        wifi_info=$(_get_wifi_macos)
    elif is_linux; then
        wifi_info=$(_get_wifi_linux)
    fi

    if [[ -n "$wifi_info" ]]; then
        local ssid="${wifi_info%%:*}"
        local signal="${wifi_info##*:}"

        plugin_data_set "connected" "1"
        plugin_data_set "ssid" "$ssid"
        plugin_data_set "signal" "${signal:-75}"
        plugin_data_set "ip" "$(_get_wifi_ip)"
    else
        plugin_data_set "connected" "0"
        plugin_data_set "ssid" ""
        plugin_data_set "signal" "0"
        plugin_data_set "ip" ""
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

plugin_get_state() {
    local connected show_when
    connected=$(plugin_data_get "connected")
    show_when=$(get_option "show_when")

    case "$show_when" in
        disconnected)
            [[ "$connected" != "1" ]] && printf 'active' || printf 'inactive'
            ;;
        always)
            printf 'active'
            ;;
        *)  # connected (default)
            [[ "$connected" == "1" ]] && printf 'active' || printf 'inactive'
            ;;
    esac
}

# =============================================================================
# Plugin Contract: Health
# =============================================================================
# Based on signal strength percentage

plugin_get_health() {
    local connected signal
    connected=$(plugin_data_get "connected")
    signal=$(plugin_data_get "signal")

    [[ "$connected" != "1" ]] && { printf 'ok'; return; }

    signal="${signal:-0}"

    if (( signal < 20 )); then
        printf 'error'
    elif (( signal < 60 )); then
        printf 'warning'
    else
        printf 'ok'
    fi
}

# =============================================================================
# Plugin Contract: Context
# =============================================================================

plugin_get_context() {
    local connected
    connected=$(plugin_data_get "connected")
    [[ "$connected" == "1" ]] && printf 'connected' || printf 'disconnected'
}

# =============================================================================
# Plugin Contract: Icon
# =============================================================================

plugin_get_icon() {
    local connected signal
    connected=$(plugin_data_get "connected")

    if [[ "$connected" != "1" ]]; then
        get_option "icon_disconnected"
        return
    fi

    signal=$(plugin_data_get "signal")
    _get_signal_icon "${signal:-75}"
}

# =============================================================================
# Plugin Contract: Render
# =============================================================================

plugin_render() {
    local connected
    connected=$(plugin_data_get "connected")

    # When disconnected, show "Disconnected" or nothing based on show_when
    if [[ "$connected" != "1" ]]; then
        local show_when
        show_when=$(get_option "show_when")
        [[ "$show_when" == "disconnected" || "$show_when" == "always" ]] && printf 'Disconnected'
        return
    fi

    local format separator max_len
    format=$(get_option "format")
    separator=$(get_option "separator")
    max_len=$(get_option "max_length")

    local ssid ip signal
    ssid=$(plugin_data_get "ssid")
    ip=$(plugin_data_get "ip")
    signal=$(plugin_data_get "signal")

    local parts=() part
    IFS=',' read -ra format_parts <<< "$format"

    for part in "${format_parts[@]}"; do
        case "$part" in
            ssid)   [[ -n "$ssid" ]] && parts+=("$ssid") ;;
            ip)     [[ -n "$ip" ]] && parts+=("$ip") ;;
            signal) [[ -n "$signal" ]] && parts+=("${signal}%") ;;
        esac
    done

    local output
    output=$(join_with_separator "$separator" "${parts[@]}")
    [[ -z "$output" ]] && output="${ssid:-WiFi}"

    if [[ "$max_len" -gt 0 && ${#output} -gt $max_len ]]; then
        output="${output:0:$((max_len-1))}…"
    fi

    printf '%s' "$output"
}

# =============================================================================
# Initialize Plugin
# =============================================================================

