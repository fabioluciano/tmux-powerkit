#!/usr/bin/env bash
# =============================================================================
# Plugin: hostname
# Description: Display current hostname
# Type: static (always visible, no threshold colors)
# Dependencies: None
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "format" "string" "short" "Hostname format (short|full)"

    # Icons
    declare_option "icon" "icon" "󰍹" "Plugin icon"

    # Colors
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"
}

plugin_init "hostname"

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'static'; }

plugin_get_display_info() { default_plugin_display_info "${1:-}"; }

# =============================================================================
# Main Logic
# =============================================================================

load_plugin() {
    local format
    format=$(get_option "format")
    case "$format" in
        full) hostname -f 2>/dev/null || hostname ;;
        short|*) hostname -s 2>/dev/null || hostname | cut -d. -f1 ;;
    esac
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
