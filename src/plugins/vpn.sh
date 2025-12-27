#!/usr/bin/env bash
# =============================================================================
# Plugin: vpn
# Description: Display VPN connection status with multi-provider detection
# Type: conditional (shown only when VPN is connected)
# Dependencies: warp-cli, tailscale, wg, openvpn, nmcli, scutil (all optional)
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active: VPN is connected
#   - inactive: VPN is not connected (plugin hidden when conditional)
#
# Health:
#   - ok: VPN connected successfully
#   - info: VPN disconnected (informational, not an error)
#
# Context:
#   - warp: Cloudflare WARP
#   - forticlient: FortiClient VPN
#   - wireguard: WireGuard
#   - tailscale: Tailscale
#   - openvpn: OpenVPN
#   - system: macOS/NetworkManager native VPN
#   - interface: Generic tun/tap interface detected
#
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "vpn"
    metadata_set "name" "VPN"
    metadata_set "description" "Display VPN connection status with multi-provider detection"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    # All VPN tools are optional - we use whatever is available
    # At minimum we can detect via network interfaces
    if is_macos; then
        require_cmd "warp-cli" 1      # Optional: Cloudflare WARP
        require_cmd "tailscale" 1     # Optional: Tailscale
        require_cmd "wg" 1            # Optional: WireGuard
        require_cmd "scutil" 1        # Optional: macOS native VPN
    else
        require_cmd "warp-cli" 1      # Optional: Cloudflare WARP
        require_cmd "tailscale" 1     # Optional: Tailscale
        require_cmd "wg" 1            # Optional: WireGuard
        require_cmd "nmcli" 1         # Optional: NetworkManager
    fi
    # Always return success - we can fallback to interface detection
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options (visibility controlled by renderer via state)
    declare_option "show_name" "bool" "true" "Show VPN connection/provider name"
    declare_option "max_length" "number" "20" "Maximum length for VPN name"
    declare_option "truncate_suffix" "string" "…" "Suffix when name is truncated"

    # Interface detection fallback
    declare_option "interfaces" "string" "tun,tap,ppp,utun,ipsec,wg" "VPN interface prefixes (comma-separated)"

    # Icons
    declare_option "icon" "icon" $'\U000F0582' "VPN connected icon (󰖂)"
    declare_option "icon_disconnected" "icon" $'\U000F0FC6' "VPN disconnected icon (󰿆)"

    # Provider-specific icons (optional overrides)
    declare_option "icon_warp" "icon" "" "Cloudflare WARP icon (empty = use default)"
    declare_option "icon_tailscale" "icon" "" "Tailscale icon (empty = use default)"
    declare_option "icon_wireguard" "icon" "" "WireGuard icon (empty = use default)"

    # Cache
    declare_option "cache_ttl" "number" "10" "Cache duration in seconds"
}

# =============================================================================
# VPN Provider Detection Functions
# =============================================================================

# Cloudflare WARP detection
_detect_warp() {
    has_cmd warp-cli || return 1
    local status
    status=$(warp-cli status 2>/dev/null) || return 1
    echo "$status" | grep -q "Connected" && {
        plugin_data_set "provider" "warp"
        echo "Cloudflare WARP"
        return 0
    }
    return 1
}

# FortiClient VPN detection (CLI, process, macOS app)
_detect_forticlient() {
    # Method 1: forticlient CLI
    if has_cmd forticlient; then
        local status
        if status=$(forticlient vpn status 2>/dev/null || forticlient status 2>/dev/null); then
            if echo "$status" | grep -q "Connected"; then
                local name
                name=$(echo "$status" | grep "VPN name:" | sed 's/.*VPN name: //;s/^[[:space:]]*//' | head -1)
                plugin_data_set "provider" "forticlient"
                echo "${name:-FortiClient}"
                return 0
            fi
        fi
    fi

    # Method 2: openfortivpn process
    if pgrep -x "openfortivpn" &>/dev/null; then
        plugin_data_set "provider" "forticlient"
        echo "FortiVPN"
        return 0
    fi

    # Method 3: macOS FortiClient app
    if is_macos; then
        if pgrep -f "FortiClient" &>/dev/null || pgrep -f "FortiTray" &>/dev/null; then
            local name
            name=$(scutil --nc list 2>/dev/null | grep -i "forti" | grep -E "^\*.*Connected" | sed 's/.*"\([^"]*\)".*/\1/' | head -1)
            if [[ -n "$name" ]]; then
                plugin_data_set "provider" "forticlient"
                echo "$name"
                return 0
            fi
            # Check ppp0 interface as last resort
            if ifconfig 2>/dev/null | grep -q "ppp0"; then
                plugin_data_set "provider" "forticlient"
                echo "FortiClient"
                return 0
            fi
        fi
    fi

    return 1
}

# WireGuard detection
_detect_wireguard() {
    has_cmd wg || return 1
    local iface
    iface=$(wg show interfaces 2>/dev/null | head -1)
    if [[ -n "$iface" ]]; then
        plugin_data_set "provider" "wireguard"
        plugin_data_set "interface" "$iface"
        echo "WireGuard"
        return 0
    fi
    return 1
}

# Tailscale detection
_detect_tailscale() {
    has_cmd tailscale || return 1
    local status state
    status=$(tailscale status --json 2>/dev/null) || return 1
    state=$(echo "$status" | grep -o '"BackendState":"[^"]*"' | cut -d'"' -f4)
    if [[ "$state" == "Running" ]]; then
        local hostname
        hostname=$(echo "$status" | grep -o '"HostName":"[^"]*"' | head -1 | cut -d'"' -f4)
        plugin_data_set "provider" "tailscale"
        echo "${hostname:-Tailscale}"
        return 0
    fi
    return 1
}

# OpenVPN detection
_detect_openvpn() {
    pgrep -x "openvpn" &>/dev/null || return 1
    local cfg name
    cfg=$(pgrep -a openvpn 2>/dev/null | grep -o -- '--config [^ ]*' | head -1 | awk '{print $2}')
    if [[ -n "$cfg" ]]; then
        name=$(basename "$cfg" .ovpn 2>/dev/null)
        [[ "$name" == "$cfg" ]] && name=$(basename "$cfg" .conf 2>/dev/null)
    fi
    plugin_data_set "provider" "openvpn"
    echo "${name:-OpenVPN}"
    return 0
}

# macOS native VPN (scutil)
_detect_macos_vpn() {
    is_macos || return 1
    local vpn
    vpn=$(scutil --nc list 2>/dev/null | grep -E "^\*.*Connected" | sed 's/.*"\([^"]*\)".*/\1/' | head -1)
    if [[ -n "$vpn" ]]; then
        plugin_data_set "provider" "system"
        echo "$vpn"
        return 0
    fi
    return 1
}

# NetworkManager VPN (Linux)
_detect_networkmanager() {
    has_cmd nmcli || return 1
    local vpn
    vpn=$(nmcli -t -f NAME,TYPE,STATE connection show --active 2>/dev/null | grep ":vpn:activated" | cut -d: -f1 | head -1)
    if [[ -n "$vpn" ]]; then
        plugin_data_set "provider" "system"
        echo "$vpn"
        return 0
    fi
    return 1
}

# Generic interface detection (fallback)
_detect_interface() {
    local interfaces prefixes iface
    interfaces=$(get_option "interfaces")
    IFS=',' read -ra prefixes <<< "$interfaces"

    if is_macos; then
        local active_interfaces
        active_interfaces=$(ifconfig -lu 2>/dev/null)
        for prefix in "${prefixes[@]}"; do
            iface=$(echo "$active_interfaces" | tr ' ' '\n' | grep "^${prefix}[0-9]*" | head -1)
            if [[ -n "$iface" ]]; then
                plugin_data_set "provider" "interface"
                plugin_data_set "interface" "$iface"
                echo "$iface"
                return 0
            fi
        done
    else
        for prefix in "${prefixes[@]}"; do
            if ip link show 2>/dev/null | grep -q "^[0-9]*: ${prefix}"; then
                iface=$(ip link show 2>/dev/null | grep "^[0-9]*: ${prefix}" | head -1 | awk -F': ' '{print $2}' | cut -d'@' -f1)
                if [[ -n "$iface" ]]; then
                    plugin_data_set "provider" "interface"
                    plugin_data_set "interface" "$iface"
                    echo "$iface"
                    return 0
                fi
            fi
        done
    fi

    return 1
}

# Main detection orchestrator - checks all providers in order of specificity
_detect_vpn() {
    local name

    # Check providers in order of specificity (most specific first)
    name=$(_detect_warp) && { echo "$name"; return 0; }
    name=$(_detect_forticlient) && { echo "$name"; return 0; }
    name=$(_detect_tailscale) && { echo "$name"; return 0; }
    name=$(_detect_wireguard) && { echo "$name"; return 0; }
    name=$(_detect_openvpn) && { echo "$name"; return 0; }

    # Platform-specific system VPNs
    if is_macos; then
        name=$(_detect_macos_vpn) && { echo "$name"; return 0; }
    else
        name=$(_detect_networkmanager) && { echo "$name"; return 0; }
    fi

    # Fallback to interface detection
    name=$(_detect_interface) && { echo "$name"; return 0; }

    return 1
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    local name

    # Reset provider data
    plugin_data_set "provider" ""
    plugin_data_set "interface" ""

    name=$(_detect_vpn)
    if [[ -n "$name" ]]; then
        plugin_data_set "connected" "1"
        plugin_data_set "name" "$name"
    else
        plugin_data_set "connected" "0"
        plugin_data_set "name" ""
    fi
}

# =============================================================================
# Plugin Contract: Type and Presence
# =============================================================================

plugin_get_content_type() {
    printf 'dynamic'
}

plugin_get_presence() {
    # VPN is typically only shown when connected
    printf 'conditional'
}

# =============================================================================
# Plugin Contract: State
# =============================================================================
# State reflects the operational status:
#   - active: VPN is connected
#   - inactive: VPN is not connected

plugin_get_state() {
    local connected
    connected=$(plugin_data_get "connected")
    [[ "$connected" == "1" ]] && printf 'active' || printf 'inactive'
}

# =============================================================================
# Plugin Contract: Health
# =============================================================================
# Health reflects the quality/severity:
#   - ok: VPN connected (everything is fine)
#   - info: VPN disconnected (informational, user may want to know)

plugin_get_health() {
    local connected
    connected=$(plugin_data_get "connected")
    [[ "$connected" == "1" ]] && printf 'ok' || printf 'info'
}

# =============================================================================
# Plugin Contract: Context
# =============================================================================
# Context provides additional information about the VPN provider:
#   - warp, forticlient, wireguard, tailscale, openvpn, system, interface

plugin_get_context() {
    local provider
    provider=$(plugin_data_get "provider")
    [[ -n "$provider" ]] && printf '%s' "$provider"
}

# =============================================================================
# Plugin Contract: Icon
# =============================================================================
# Icon selection based on state and context

plugin_get_icon() {
    local connected provider icon

    connected=$(plugin_data_get "connected")

    if [[ "$connected" != "1" ]]; then
        get_option "icon_disconnected"
        return
    fi

    # Check for provider-specific icon
    provider=$(plugin_data_get "provider")
    case "$provider" in
        warp)
            icon=$(get_option "icon_warp")
            ;;
        tailscale)
            icon=$(get_option "icon_tailscale")
            ;;
        wireguard)
            icon=$(get_option "icon_wireguard")
            ;;
    esac

    # Use provider icon if set, otherwise default
    if [[ -n "$icon" ]]; then
        printf '%s' "$icon"
    else
        get_option "icon"
    fi
}

# =============================================================================
# Plugin Contract: Render
# =============================================================================
# Render returns TEXT ONLY (no colors, no icons per contract)

plugin_render() {
    local connected show_name name max_len suffix

    connected=$(plugin_data_get "connected")
    show_name=$(get_option "show_name")
    name=$(plugin_data_get "name")
    max_len=$(get_option "max_length")
    suffix=$(get_option "truncate_suffix")

    # If disconnected, show nothing (renderer handles via state)
    if [[ "$connected" != "1" ]]; then
        return
    fi

    # Connected - show name or generic "VPN"
    if [[ "$show_name" == "true" && -n "$name" ]]; then
        if [[ "$max_len" -gt 0 ]]; then
            printf '%s' "$(truncate_text "$name" "$max_len" "$suffix")"
        else
            printf '%s' "$name"
        fi
    else
        printf 'VPN'
    fi
}

# =============================================================================
# Initialize Plugin
# =============================================================================

