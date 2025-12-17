#!/usr/bin/env bash
# Plugin: hostname - Display current hostname

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_get_type() { printf 'static'; }

plugin_get_display_info() {
    build_display_info "1" "" "" ""
}

load_plugin() {
    local fmt=$(get_tmux_option "@powerkit_plugin_hostname_format" "$POWERKIT_PLUGIN_HOSTNAME_FORMAT")
    case "$fmt" in
        full) hostname -f 2>/dev/null || hostname ;;
        short|*) hostname -s 2>/dev/null || hostname | cut -d. -f1 ;;
    esac
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
