#!/usr/bin/env bash
# =============================================================================
# Plugin: vpn
# Description: Display VPN connection status
# Type: conditional (shown only when VPN is connected)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "vpn"
    metadata_set "name" "VPN"
    metadata_set "description" "Display VPN connection status"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    # All VPN tools are optional - we use whatever is available
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display format: name, ip, provider
    declare_option "format" "string" "name" "What to display: name, ip, provider"
    declare_option "max_length" "number" "20" "Maximum length for display text"

    # Optional providers
    declare_option "detect_private_relay" "bool" "false" "Detect iCloud Private Relay (macOS)"

    # Interface detection fallback (Linux only)
    declare_option "interfaces" "string" "tun,tap,ppp,wg" "VPN interface prefixes"

    # Icon
    declare_option "icon" "icon" $'\U000F0483' "VPN icon (󱒃)"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

# =============================================================================
# VPN Detection Functions
# =============================================================================

_detect_warp() {
    has_cmd warp-cli || return 1
    local status
    status=$(warp-cli status 2>/dev/null) || return 1
    if echo "$status" | grep -q "Connected"; then
        plugin_data_set "provider" "warp"
        plugin_data_set "name" "Cloudflare WARP"
        return 0
    fi
    return 1
}

_detect_forticlient() {
    if has_cmd forticlient; then
        local status
        if status=$(forticlient vpn status 2>/dev/null || forticlient status 2>/dev/null); then
            if echo "$status" | grep -q "Connected"; then
                local name
                name=$(echo "$status" | grep "VPN name:" | sed 's/.*VPN name: //;s/^[[:space:]]*//' | head -1)
                plugin_data_set "provider" "forticlient"
                plugin_data_set "name" "${name:-FortiClient}"
                return 0
            fi
        fi
    fi

    if pgrep -x "openfortivpn" &>/dev/null; then
        plugin_data_set "provider" "forticlient"
        plugin_data_set "name" "FortiVPN"
        return 0
    fi

    if is_macos; then
        if pgrep -f "FortiClient" &>/dev/null || pgrep -f "FortiTray" &>/dev/null; then
            local name
            name=$(scutil --nc list 2>/dev/null | grep -i "forti" | grep -E "^\*.*Connected" | sed 's/.*"\([^"]*\)".*/\1/' | head -1)
            if [[ -n "$name" ]]; then
                plugin_data_set "provider" "forticlient"
                plugin_data_set "name" "$name"
                return 0
            fi
            if ifconfig 2>/dev/null | grep -q "ppp0"; then
                plugin_data_set "provider" "forticlient"
                plugin_data_set "name" "FortiClient"
                return 0
            fi
        fi
    fi

    return 1
}

_detect_wireguard() {
    has_cmd wg || return 1
    local iface
    iface=$(wg show interfaces 2>/dev/null | head -1)
    if [[ -n "$iface" ]]; then
        plugin_data_set "provider" "wireguard"
        plugin_data_set "name" "WireGuard"
        plugin_data_set "interface" "$iface"
        return 0
    fi
    return 1
}

_detect_tailscale() {
    has_cmd tailscale || return 1
    local status state
    status=$(tailscale status --json 2>/dev/null) || return 1
    state=$(echo "$status" | grep -o '"BackendState":"[^"]*"' | cut -d'"' -f4)
    if [[ "$state" == "Running" ]]; then
        local hostname ip
        hostname=$(echo "$status" | grep -o '"HostName":"[^"]*"' | head -1 | cut -d'"' -f4)
        ip=$(tailscale ip -4 2>/dev/null | head -1)
        plugin_data_set "provider" "tailscale"
        plugin_data_set "name" "${hostname:-Tailscale}"
        plugin_data_set "ip" "$ip"
        return 0
    fi
    return 1
}

_detect_openvpn() {
    pgrep -x "openvpn" &>/dev/null || return 1
    local cfg name
    cfg=$(pgrep -a openvpn 2>/dev/null | grep -o -- '--config [^ ]*' | head -1 | awk '{print $2}')
    if [[ -n "$cfg" ]]; then
        name=$(basename "$cfg" .ovpn 2>/dev/null)
        [[ "$name" == "$cfg" ]] && name=$(basename "$cfg" .conf 2>/dev/null)
    fi
    plugin_data_set "provider" "openvpn"
    plugin_data_set "name" "${name:-OpenVPN}"
    return 0
}

_detect_macos_vpn() {
    is_macos || return 1
    local vpn
    vpn=$(scutil --nc list 2>/dev/null | grep -E "^\*.*Connected" | sed 's/.*"\([^"]*\)".*/\1/' | head -1)
    if [[ -n "$vpn" ]]; then
        plugin_data_set "provider" "system"
        plugin_data_set "name" "$vpn"
        return 0
    fi
    return 1
}

_detect_private_relay() {
    is_macos || return 1

    # Check if networkserviceproxy daemon is running (handles Private Relay)
    pgrep -q "networkserviceproxy" 2>/dev/null || return 1

    # Check if there are utun interfaces with default routes (Private Relay creates these)
    # Private Relay typically creates utun interfaces for its QUIC tunnels
    local utun_routes
    utun_routes=$(netstat -rn 2>/dev/null | grep -c "default.*utun")

    # If we have multiple utun default routes and the proxy daemon is running,
    # Private Relay is likely active
    if [[ "$utun_routes" -ge 2 ]]; then
        plugin_data_set "provider" "private_relay"
        plugin_data_set "name" "Private Relay"
        return 0
    fi

    return 1
}

_detect_networkmanager() {
    has_cmd nmcli || return 1
    local vpn ip
    vpn=$(nmcli -t -f NAME,TYPE,STATE connection show --active 2>/dev/null | grep ":vpn:activated" | cut -d: -f1 | head -1)
    if [[ -n "$vpn" ]]; then
        ip=$(nmcli -t -f IP4.ADDRESS connection show "$vpn" 2>/dev/null | cut -d: -f2 | cut -d/ -f1 | head -1)
        plugin_data_set "provider" "system"
        plugin_data_set "name" "$vpn"
        plugin_data_set "ip" "$ip"
        return 0
    fi
    return 1
}

_detect_interface() {
    # Generic interface detection - Linux only
    # macOS utun/ppp interfaces are too common (iCloud, etc.) to be reliable
    is_macos && return 1

    local interfaces prefixes iface
    interfaces=$(get_option "interfaces")
    IFS=',' read -ra prefixes <<< "$interfaces"

    for prefix in "${prefixes[@]}"; do
        if ip link show 2>/dev/null | grep -q "^[0-9]*: ${prefix}"; then
            iface=$(ip link show 2>/dev/null | grep "^[0-9]*: ${prefix}" | head -1 | awk -F': ' '{print $2}' | cut -d'@' -f1)
            if [[ -n "$iface" ]]; then
                plugin_data_set "provider" "interface"
                plugin_data_set "name" "$iface"
                plugin_data_set "interface" "$iface"
                return 0
            fi
        fi
    done

    return 1
}

_detect_vpn() {
    _detect_warp && return 0
    _detect_forticlient && return 0
    _detect_tailscale && return 0
    _detect_wireguard && return 0
    _detect_openvpn && return 0

    if is_macos; then
        _detect_macos_vpn && return 0
        # Optional: iCloud Private Relay
        [[ "$(get_option "detect_private_relay")" == "true" ]] && _detect_private_relay && return 0
    else
        _detect_networkmanager && return 0
    fi

    _detect_interface && return 0
    return 1
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    plugin_data_set "connected" "0"
    plugin_data_set "provider" ""
    plugin_data_set "name" ""
    plugin_data_set "ip" ""
    plugin_data_set "interface" ""

    if _detect_vpn; then
        plugin_data_set "connected" "1"
    fi
}

# =============================================================================
# Plugin Contract: Type and Presence
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

# =============================================================================
# Plugin Contract: State and Health
# =============================================================================

plugin_get_state() {
    local connected
    connected=$(plugin_data_get "connected")
    [[ "$connected" == "1" ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() {
    printf 'info'
}

plugin_get_context() {
    plugin_data_get "provider"
}

# =============================================================================
# Plugin Contract: Icon
# =============================================================================

plugin_get_icon() {
    get_option "icon"
}

# =============================================================================
# Plugin Contract: Render
# =============================================================================

plugin_render() {
    local connected format max_len output
    connected=$(plugin_data_get "connected")

    [[ "$connected" != "1" ]] && return

    format=$(get_option "format")
    max_len=$(get_option "max_length")

    case "$format" in
        ip)
            output=$(plugin_data_get "ip")
            [[ -z "$output" ]] && output=$(plugin_data_get "name")
            ;;
        provider)
            output=$(plugin_data_get "provider")
            [[ -z "$output" ]] && output="VPN"
            ;;
        *)
            output=$(plugin_data_get "name")
            [[ -z "$output" ]] && output="VPN"
            ;;
    esac

    if [[ "$max_len" -gt 0 && ${#output} -gt $max_len ]]; then
        output="${output:0:$((max_len-1))}…"
    fi

    printf '%s' "$output"
}
