#!/usr/bin/env bash
# Plugin: uptime - Display system uptime

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "uptime"

plugin_get_type() { printf 'static'; }

plugin_get_display_info() {
    local content="${1:-}"
    [[ -z "$content" || "$content" == "N/A" ]] && { build_display_info "0" "" "" ""; return; }
    build_display_info "1" "" "" ""
}

format_uptime() {
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

get_uptime_linux() {
    local uptime_seconds
    uptime_seconds=$(awk '{printf "%d", $1}' /proc/uptime 2>/dev/null)
    format_uptime "$uptime_seconds"
}

get_uptime_macos() {
    local uptime_seconds
    uptime_seconds=$(sysctl -n kern.boottime 2>/dev/null | awk -v current="$(date +%s)" '
        /sec =/ {gsub(/[{},:=]/," "); for(i=1;i<=NF;i++) if($i=="sec") {print current - $(i+1); exit}}')
    format_uptime "$uptime_seconds"
}

_compute_uptime() {
    local result
    if is_linux; then
        result=$(get_uptime_linux)
    elif is_macos; then
        result=$(get_uptime_macos)
    else
        result="N/A"
    fi
    printf '%s' "$result"
}

load_plugin() {
    cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_uptime
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
