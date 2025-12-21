#!/usr/bin/env bash
# =============================================================================
# Plugin: external_ip
# Description: Display external (public) IP address
# Type: conditional (hidden when offline)
# Dependencies: curl
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    require_cmd "curl" || return 1
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Icons
    declare_option "icon" "icon" $'\U000F0A5F' "Plugin icon"

    # Colors
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Cache
    declare_option "cache_ttl" "number" "600" "Cache duration in seconds"
}

plugin_init "external_ip"

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() { default_plugin_display_info "${1:-}"; }

# =============================================================================
# Main Logic
# =============================================================================

_compute_external_ip() {
    has_cmd curl || return 1

    local external_ip
    external_ip=$(safe_curl "https://api.ipify.org" 3)
    [[ -n "$external_ip" ]] && printf '%s' "$external_ip"
}

load_plugin() {
    cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_external_ip
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
