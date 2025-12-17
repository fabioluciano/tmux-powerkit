#!/usr/bin/env bash
# =============================================================================
# Plugin: vpn
# Description: Display VPN connection status
# Dependencies: None (supports WireGuard, OpenVPN, Tailscale, FortiClient, etc.)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "vpn"

# =============================================================================
# VPN Detection Functions
# =============================================================================

check_cloudflare_warp() {
    local status
    status=$(warp-cli status 2>/dev/null) || return 1
    echo "$status" | grep -q "Connected" && { echo "Cloudflare WARP"; return 0; }
    return 1
}

check_forticlient() {
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

check_wireguard() {
    local iface
    iface=$(wg show interfaces 2>/dev/null | head -1) || return 1
    [[ -n "$iface" ]] && { echo "WireGuard"; return 0; }
    return 1
}

check_tailscale() {
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

check_openvpn() {
    pgrep -x "openvpn" &>/dev/null || return 1
    local cfg name
    cfg=$(pgrep -a openvpn 2>/dev/null | grep -o -- '--config [^ ]*' | head -1 | awk '{print $2}')
    [[ -n "$cfg" ]] && name=$(basename "$cfg" .ovpn 2>/dev/null || basename "$cfg" .conf 2>/dev/null)
    echo "${name:-OpenVPN}"
    return 0
}

check_macos_vpn() {
    is_macos || return 1
    local vpn
    vpn=$(scutil --nc list 2>/dev/null | grep -E "^\*.*Connected" | sed 's/.*"\([^"]*\)".*/\1/' | head -1)
    [[ -n "$vpn" ]] && { echo "$vpn"; return 0; }
    return 1
}

check_networkmanager() {
    require_cmd nmcli 1 || return 1
    local vpn
    vpn=$(nmcli -t -f NAME,TYPE,STATE connection show --active 2>/dev/null | grep ":vpn:activated" | cut -d: -f1 | head -1)
    [[ -n "$vpn" ]] && { echo "$vpn"; return 0; }
    return 1
}

check_tun_interface() {
    if is_linux; then
        ip link show 2>/dev/null | grep -qE "tun[0-9]+|tap[0-9]+" && { echo "VPN"; return 0; }
    else
        ifconfig 2>/dev/null | grep -qE "^tun[0-9]+|^tap[0-9]+" && { echo "VPN"; return 0; }
    fi
    return 1
}

# =============================================================================
# Main Detection
# =============================================================================

get_vpn_status() {
    local name
    
    # Check VPNs in order of specificity
    name=$(check_cloudflare_warp) && { echo "$name"; return 0; }
    name=$(check_forticlient) && { echo "$name"; return 0; }
    name=$(check_tailscale) && { echo "$name"; return 0; }
    name=$(check_wireguard) && { echo "$name"; return 0; }
    name=$(check_openvpn) && { echo "$name"; return 0; }
    
    if is_macos; then
        name=$(check_macos_vpn) && { echo "$name"; return 0; }
    else
        name=$(check_networkmanager) && { echo "$name"; return 0; }
    fi
    
    name=$(check_tun_interface) && { echo "$name"; return 0; }
    
    return 1
}

# =============================================================================
# Plugin Interface
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    [[ -n "$content" ]] && echo "1:::" || echo "0:::"
}

# =============================================================================
# Main
# =============================================================================

load_plugin() {
    local cached
    cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL") && { printf '%s' "$cached"; return 0; }
    
    local name max_len
    name=$(get_vpn_status) || return 0
    
    max_len=$(get_tmux_option "@powerkit_plugin_vpn_max_length" "$POWERKIT_PLUGIN_VPN_MAX_LENGTH")
    [[ ${#name} -gt $max_len ]] && name="${name:0:$((max_len-1))}…"
    
    cache_set "$CACHE_KEY" "$name"
    printf '%s' "$name"
}

# Only run if executed directly (not sourced)
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
