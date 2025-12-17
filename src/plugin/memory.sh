#!/usr/bin/env bash
# Plugin: memory - Display memory usage percentage

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "memory"

plugin_get_type() { printf 'static'; }

plugin_get_display_info() {
    local content="${1:-}"
    [[ -z "$content" || "$content" == "N/A" ]] && { build_display_info "0" "" "" ""; return; }
    build_display_info "1" "" "" ""
}

bytes_to_human() {
    local bytes=$1
    local gb=$((bytes / 1073741824))
    
    if [[ $gb -gt 0 ]]; then
        awk -v b="$bytes" 'BEGIN {printf "%.1fG", b / 1073741824}'
    else
        printf '%dM' "$((bytes / POWERKIT_BYTE_MB))"
    fi
}

get_memory_linux() {
    local format
    format=$(get_cached_option "@powerkit_plugin_memory_format" "$POWERKIT_PLUGIN_MEMORY_FORMAT")
    
    local mem_info mem_total mem_available mem_used percent
    mem_info=$(awk '
        /^MemTotal:/ {total=$2}
        /^MemAvailable:/ {available=$2}
        /^MemFree:/ {free=$2}
        /^Buffers:/ {buffers=$2}
        /^Cached:/ {cached=$2}
        END {
            if (available > 0) { print total, available }
            else { print total, (free + buffers + cached) }
        }
    ' /proc/meminfo)
    
    read -r mem_total mem_available <<< "$mem_info"
    mem_used=$((mem_total - mem_available))
    percent=$(( (mem_used * 100) / mem_total ))
    
    if [[ "$format" == "usage" ]]; then
        printf '%s/%s' "$(bytes_to_human $((mem_used * POWERKIT_BYTE_KB)))" "$(bytes_to_human $((mem_total * POWERKIT_BYTE_KB)))"
    else
        printf '%3d%%' "$percent"
    fi
}

get_memory_macos() {
    local format
    format=$(get_cached_option "@powerkit_plugin_memory_format" "$POWERKIT_PLUGIN_MEMORY_FORMAT")
    
    local mem_total percent mem_used
    local free_percent
    free_percent=$(memory_pressure 2>/dev/null | awk '/System-wide memory free percentage:/ {print $5}' | tr -d '%')
    
    if [[ -n "$free_percent" && "$free_percent" =~ ^[0-9]+$ ]]; then
        percent=$((100 - free_percent))
        mem_total=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
        mem_used=$((mem_total * percent / 100))
    else
        local page_size pages_used
        page_size=$(sysctl -n hw.pagesize 2>/dev/null || echo 4096)
        mem_total=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
        pages_used=$(vm_stat | awk '
            /Pages active:/ {active = $3; gsub(/\./, "", active)}
            /Pages wired down:/ {wired = $4; gsub(/\./, "", wired)}
            END {print active + wired}
        ')
        mem_used=$((pages_used * page_size))
        percent=$(( (mem_used * 100) / mem_total ))
    fi
    
    if [[ "$format" == "usage" ]]; then
        printf '%s/%s' "$(bytes_to_human "$mem_used")" "$(bytes_to_human "$mem_total")"
    else
        printf '%3d%%' "$percent"
    fi
}

_compute_memory() {
    if is_linux; then
        get_memory_linux
    elif is_macos; then
        get_memory_macos
    else
        printf 'N/A'
    fi
}

load_plugin() {
    cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_memory
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
