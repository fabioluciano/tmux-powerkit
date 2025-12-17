#!/usr/bin/env bash
# Plugin: external_ip - Display external (public) IP address

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "external_ip"

_compute_external_ip() {
    require_cmd curl || return 1
    local ip
    ip=$(safe_curl "https://api.ipify.org" 3)
    [[ -n "$ip" ]] && printf '%s' "$ip"
}

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="${1:-}"
    [[ -z "$content" ]] && { build_display_info "0" "" "" ""; return; }
    build_display_info "1" "" "" ""
}

load_plugin() {
    # Use defer_plugin_load for network operations with lazy loading
    defer_plugin_load "$CACHE_KEY" cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_external_ip
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
