#!/usr/bin/env bash
# Plugin: disk - Display disk usage for a mount point

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "disk"

# Configuration
_mount=$(get_tmux_option "@powerkit_plugin_disk_mount" "$POWERKIT_PLUGIN_DISK_MOUNT")
_format=$(get_tmux_option "@powerkit_plugin_disk_format" "$POWERKIT_PLUGIN_DISK_FORMAT")

get_disk_info() {
    local mount="$1"
    local format="$2"
    df -Pk "$mount" 2>/dev/null | awk -v fmt="$format" -v KB="$POWERKIT_BYTE_KB" \
        -v MB="$POWERKIT_BYTE_MB" -v GB="$POWERKIT_BYTE_GB" -v TB="$POWERKIT_BYTE_TB" '
        NR==2 {
            gsub(/%/, "", $5)
            if ($2 > 0 && $5 >= 0) {
                used = $3 * KB; free = $4 * KB; total = $2 * KB
                if (fmt == "usage") printf "%.1f/%.1f", used/GB, total/GB
                else if (fmt == "free") {
                    if (free >= TB) printf "%.1fT", free/TB
                    else if (free >= GB) printf "%.1fG", free/GB
                    else if (free >= MB) printf "%.0fM", free/MB
                    else printf "%.0fK", free/KB
                }
                else printf "%3d%%", $5
            } else print "N/A"
        }'
}

_compute_disk() {
    get_disk_info "$_mount" "$_format"
}

plugin_get_type() { printf 'static'; }

plugin_get_display_info() {
    local content="${1:-}"
    [[ -z "$content" || "$content" == "N/A" ]] && { build_display_info "0" "" "" ""; return; }
    build_display_info "1" "" "" ""
}

load_plugin() {
    cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_disk
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
