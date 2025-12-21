#!/usr/bin/env bash
# =============================================================================
# Plugin: memory
# Description: Display memory usage percentage or usage stats
# Type: conditional (with threshold support)
# Dependencies: None (uses /proc/meminfo, memory_pressure, or vm_stat)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "format" "string" "percent" "Display format: percent or usage"

    # Icons
    declare_option "icon" "icon" $'\uefc5' "Plugin icon"

    # Colors
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Thresholds
    declare_option "threshold_mode" "string" "normal" "Threshold mode (none|normal|inverted)"
    declare_option "warning_threshold" "number" "80" "Warning threshold percentage"
    declare_option "critical_threshold" "number" "90" "Critical threshold percentage"
    declare_option "show_only_warning" "bool" "false" "Only show when threshold exceeded"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

plugin_init "memory"

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

# Get current memory percentage for threshold detection
# (can't rely on global variable because cache may skip _compute_memory)
_get_current_memory_percent() {
    if is_linux; then
        awk '
            /^MemTotal:/ {total=$2}
            /^MemAvailable:/ {available=$2}
            /^MemFree:/ {free=$2}
            /^Buffers:/ {buffers=$2}
            /^Cached:/ {cached=$2}
            END {
                if (available > 0) { avail = available }
                else { avail = free + buffers + cached }
                used = total - avail
                printf "%.0f", (used * 100) / total
            }
        ' /proc/meminfo
    elif is_macos; then
        local free_percent
        free_percent=$(memory_pressure 2>/dev/null | awk '/System-wide memory free percentage:/ {print $5}' | tr -d '%')
        if [[ -n "$free_percent" && "$free_percent" =~ ^[0-9]+$ ]]; then
            echo "$((100 - free_percent))"
        else
            local page_size mem_total pages_used mem_used
            page_size=$(sysctl -n hw.pagesize 2>/dev/null || echo 4096)
            mem_total=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
            pages_used=$(vm_stat | awk '
                /Pages active:/ {active = $3; gsub(/\./, "", active)}
                /Pages wired down:/ {wired = $4; gsub(/\./, "", wired)}
                END {print active + wired}
            ')
            mem_used=$((pages_used * page_size))
            echo "$(( (mem_used * 100) / mem_total ))"
        fi
    else
        echo "0"
    fi
}

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="${1:-}"
    local mem_percent
    mem_percent=$(_get_current_memory_percent)
    threshold_plugin_display_info "$content" "$mem_percent"
}

# =============================================================================
# Helper Functions
# =============================================================================

_bytes_to_human() {
    local bytes=$1
    local gb=$((bytes / POWERKIT_BYTE_GB))

    if [[ $gb -gt 0 ]]; then
        awk -v b="$bytes" -v GB="$POWERKIT_BYTE_GB" 'BEGIN {printf "%.1fG", b / GB}'
    else
        printf '%dM' "$((bytes / POWERKIT_BYTE_MB))"
    fi
}

_get_memory_linux() {
    local format
    format=$(get_option "format")

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
        printf '%s/%s' "$(_bytes_to_human $((mem_used * POWERKIT_BYTE_KB)))" "$(_bytes_to_human $((mem_total * POWERKIT_BYTE_KB)))"
    else
        printf '%3d%%' "$percent"
    fi
}

_get_memory_macos() {
    local format
    format=$(get_option "format")

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
        printf '%s/%s' "$(_bytes_to_human "$mem_used")" "$(_bytes_to_human "$mem_total")"
    else
        printf '%3d%%' "$percent"
    fi
}

# =============================================================================
# Main Logic
# =============================================================================

_compute_memory() {
    if is_linux; then
        _get_memory_linux
    elif is_macos; then
        _get_memory_macos
    else
        printf 'N/A'
    fi
}

load_plugin() {
    cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_memory
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
