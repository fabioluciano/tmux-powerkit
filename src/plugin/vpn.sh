#!/usr/bin/env bash
# =============================================================================
# Plugin: vpn
# Description: Display VPN connection status
# Dependencies: At least one VPN tool (warp-cli, tailscale, wg, openvpn, nmcli, scutil)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    # Need at least one VPN detection tool
    if is_macos; then
        require_any_cmd "warp-cli" "tailscale" "wg" "openvpn" "scutil" || return 1
    else
        require_any_cmd "warp-cli" "tailscale" "wg" "openvpn" "nmcli" || return 1
    fi
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "max_length" "number" "20" "Maximum length for VPN name"

    # Icons
    declare_option "icon" "icon" $'\ue672' "Plugin icon"

    # Colors - Default
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

plugin_init "vpn"

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    [[ -n "$content" ]] && echo "1:::" || echo "0:::"
}

# =============================================================================
# Helper Functions - VPN Detection
# =============================================================================

_check_cloudflare_warp() {
    local status
    status=$(warp-cli status 2>/dev/null) || return 1
    echo "$status" | grep -q "Connected" && { echo "Cloudflare WARP"; return 0; }
    return 1
}

_check_forticlient() {
    # CLI method
    local status
    if status=$(forticlient vpn status 2>/dev/null || forticlient status 2>/dev/null); then
        echo "$status" | grep -q "Connected" && {
            echo "$status" | grep "VPN name:" | sed 's/.*VPN name: //;s/^[[:space:]]*//' | head -1
            return 0
        }
    fi

    # Process check
    pgrep -x "openfortivpn" &>/dev/null && { echo "FortiVPN"; return 0; }

    # macOS FortiClient
    if is_macos && pgrep -f "FortiClient" &>/dev/null; then
        local name
        name=$(scutil --nc list 2>/dev/null | grep -i "forti" | grep -E "^\*.*Connected" | sed 's/.*"\([^"]*\)".*/\1/')
        [[ -n "$name" ]] && { echo "$name"; return 0; }
        pgrep -f "FortiTray" &>/dev/null && ifconfig 2>/dev/null | grep -q "ppp0" && { echo "FortiClient"; return 0; }
    fi

    return 1
}

_check_wireguard() {
    local iface
    iface=$(wg show interfaces 2>/dev/null | head -1) || return 1
    [[ -n "$iface" ]] && { echo "WireGuard"; return 0; }
    return 1
}

_check_tailscale() {
    local status state
    status=$(tailscale status --json 2>/dev/null) || return 1
    state=$(echo "$status" | grep -o '"BackendState":"[^"]*"' | cut -d'"' -f4)
    [[ "$state" == "Running" ]] && {
        local name
        name=$(echo "$status" | grep -o '"HostName":"[^"]*"' | head -1 | cut -d'"' -f4)
        echo "${name:-Tailscale}"
        return 0
    }
    return 1
}

_check_openvpn() {
    pgrep -x "openvpn" &>/dev/null || return 1
    local cfg name
    cfg=$(pgrep -a openvpn 2>/dev/null | grep -o -- '--config [^ ]*' | head -1 | awk '{print $2}')
    [[ -n "$cfg" ]] && name=$(basename "$cfg" .ovpn 2>/dev/null || basename "$cfg" .conf 2>/dev/null)
    echo "${name:-OpenVPN}"
    return 0
}

_check_macos_vpn() {
    is_macos || return 1
    local vpn
    vpn=$(scutil --nc list 2>/dev/null | grep -E "^\*.*Connected" | sed 's/.*"\([^"]*\)".*/\1/' | head -1)
    [[ -n "$vpn" ]] && { echo "$vpn"; return 0; }
    return 1
}

_check_networkmanager() {
    has_cmd nmcli || return 1
    local vpn
    vpn=$(nmcli -t -f NAME,TYPE,STATE connection show --active 2>/dev/null | grep ":vpn:activated" | cut -d: -f1 | head -1)
    [[ -n "$vpn" ]] && { echo "$vpn"; return 0; }
    return 1
}

_check_tun_interface() {
    if is_linux; then
        ip link show 2>/dev/null | grep -qE "tun[0-9]+|tap[0-9]+" && { echo "VPN"; return 0; }
    else
        ifconfig 2>/dev/null | grep -qE "^tun[0-9]+|^tap[0-9]+" && { echo "VPN"; return 0; }
    fi
    return 1
}

_get_vpn_status() {
    local name

    # Check VPNs in order of specificity
    name=$(_check_cloudflare_warp) && { echo "$name"; return 0; }
    name=$(_check_forticlient) && { echo "$name"; return 0; }
    name=$(_check_tailscale) && { echo "$name"; return 0; }
    name=$(_check_wireguard) && { echo "$name"; return 0; }
    name=$(_check_openvpn) && { echo "$name"; return 0; }

    if is_macos; then
        name=$(_check_macos_vpn) && { echo "$name"; return 0; }
    else
        name=$(_check_networkmanager) && { echo "$name"; return 0; }
    fi

    name=$(_check_tun_interface) && { echo "$name"; return 0; }

    return 1
}

# =============================================================================
# Main Logic
# =============================================================================

load_plugin() {
    local cached
    cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL") && { printf '%s' "$cached"; return 0; }

    local name max_len
    name=$(_get_vpn_status) || return 0

    max_len=$(get_option "max_length")
    [[ ${#name} -gt $max_len ]] && name="${name:0:$((max_len-1))}…"

    cache_set "$CACHE_KEY" "$name"
    printf '%s' "$name"
}

# Only run if executed directly (not sourced)
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
