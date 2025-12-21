#!/usr/bin/env bash
# =============================================================================
# Plugin: uptime
# Description: Display system uptime
# Type: static (always visible, informational)
# Dependencies: None
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Icons
    declare_option "icon" "icon" $'\ue382' "Plugin icon"

    # Colors
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Cache
    declare_option "cache_ttl" "number" "60" "Cache duration in seconds"
}

plugin_init "uptime"

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'static'; }

plugin_get_display_info() { default_plugin_display_info "${1:-}"; }

# =============================================================================
# Helper Functions
# =============================================================================

_format_uptime() {
    local seconds=$1
    local days=$((seconds / 86400))
    local hours=$(( (seconds % 86400) / 3600 ))
    local minutes=$(( (seconds % 3600) / 60 ))

    if [[ $days -gt 0 ]]; then
        printf '%dd %dh' "$days" "$hours"
    elif [[ $hours -gt 0 ]]; then
        printf '%dh %dm' "$hours" "$minutes"
    else
        printf '%dm' "$minutes"
    fi
}

_get_uptime_linux() {
    local uptime_seconds
    uptime_seconds=$(awk '{printf "%d", $1}' /proc/uptime 2>/dev/null)
    _format_uptime "$uptime_seconds"
}

_get_uptime_macos() {
    local uptime_seconds
    uptime_seconds=$(sysctl -n kern.boottime 2>/dev/null | awk -v current="$(date +%s)" '
        /sec =/ {gsub(/[{},:=]/," "); for(i=1;i<=NF;i++) if($i=="sec") {print current - $(i+1); exit}}')
    _format_uptime "$uptime_seconds"
}

# =============================================================================
# Main Logic
# =============================================================================

_compute_uptime() {
    local result
    if is_linux; then
        result=$(_get_uptime_linux)
    elif is_macos; then
        result=$(_get_uptime_macos)
    else
        result="N/A"
    fi
    printf '%s' "$result"
}

load_plugin() {
    cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_uptime
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
