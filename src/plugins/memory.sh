#!/usr/bin/env bash
# =============================================================================
# Plugin: memory
# Description: Display memory usage percentage or absolute usage
# Type: conditional (with threshold support)
# Dependencies: None (/proc/meminfo on Linux, memory_pressure/vm_stat on macOS)
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active: Memory metrics are available
#   - inactive: Unable to read memory metrics
#
# Health:
#   - ok: Memory usage below warning threshold
#   - warning: Memory usage above warning but below critical
#   - error: Memory usage above critical threshold
#
# Context:
#   - normal_load: Memory usage is normal
#   - high_load: Memory usage is elevated (warning level)
#   - critical_load: Memory usage is critical
#
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "memory"
    metadata_set "name" "Memory"
    metadata_set "description" "Display memory usage with threshold support"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    if is_macos; then
        require_cmd "memory_pressure" 1  # Preferred
        require_cmd "vm_stat" 1          # Fallback
        require_cmd "sysctl" 1           # For total memory
    else
        [[ -f /proc/meminfo ]] || return 1
    fi
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display format
    declare_option "format" "string" "usage" "Display format (percent|usage|used)"

    # Icons
    declare_option "icon" "icon" $'\U0000efc5' "Plugin icon"
    # Thresholds (higher = worse)
    declare_option "warning_threshold" "number" "80" "Warning threshold percentage"
    declare_option "critical_threshold" "number" "90" "Critical threshold percentage"

    # Note: show_only_on_threshold is auto-injected globally

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

# =============================================================================
# Linux Memory Detection
# =============================================================================

_collect_linux() {
    local mem_info mem_total mem_available mem_used percent

    # Parse /proc/meminfo
    # MemAvailable is preferred (kernel 3.14+), fallback to Free+Buffers+Cached
    mem_info=$(awk '
        /^MemTotal:/ {total=$2}
        /^MemAvailable:/ {available=$2}
        /^MemFree:/ {free=$2}
        /^Buffers:/ {buffers=$2}
        /^Cached:/ {cached=$2}
        END {
            if (available > 0) { avail = available }
            else { avail = free + buffers + cached }
            print total, avail
        }
    ' /proc/meminfo 2>/dev/null)

    [[ -z "$mem_info" ]] && { echo "0 0 0"; return; }

    read -r mem_total mem_available <<< "$mem_info"
    mem_used=$((mem_total - mem_available))

    # Calculate percentage (mem_total is in KB)
    percent=$(calc_percent "$mem_used" "$mem_total")

    # Ensure valid range
    (( percent > 100 )) && percent=100
    (( percent < 0 )) && percent=0

    # Convert KB to bytes for consistency
    local used_bytes=$((mem_used * 1024))
    local total_bytes=$((mem_total * 1024))

    echo "$percent $used_bytes $total_bytes"
}

# =============================================================================
# macOS Memory Detection
# =============================================================================

# Via memory_pressure (most accurate)
_collect_macos_memory_pressure() {
    has_cmd memory_pressure || return 1

    local free_percent mem_total percent mem_used

    free_percent=$(memory_pressure 2>/dev/null | awk '/System-wide memory free percentage:/ {print $5}' | tr -d '%')

    [[ -z "$free_percent" || ! "$free_percent" =~ ^[0-9]+$ ]] && return 1

    percent=$((100 - free_percent))
    mem_total=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    mem_used=$((mem_total * percent / 100))

    echo "$percent $mem_used $mem_total"
}

# Via vm_stat (fallback)
_collect_macos_vm_stat() {
    has_cmd vm_stat || return 1

    local page_size mem_total pages_used mem_used percent

    page_size=$(sysctl -n hw.pagesize 2>/dev/null || echo 4096)
    mem_total=$(sysctl -n hw.memsize 2>/dev/null || echo 0)

    # vm_stat shows pages: active + wired = used
    pages_used=$(vm_stat 2>/dev/null | awk '
        /Pages active:/ {active = $3; gsub(/\./, "", active)}
        /Pages wired down:/ {wired = $4; gsub(/\./, "", wired)}
        END {print (active + 0) + (wired + 0)}
    ')

    [[ -z "$pages_used" ]] && return 1

    mem_used=$((pages_used * page_size))

    percent=$(calc_percent "$mem_used" "$mem_total")

    echo "$percent $mem_used $mem_total"
}

_collect_macos() {
    _collect_macos_memory_pressure 2>/dev/null || _collect_macos_vm_stat
}

# =============================================================================
# Utility Functions
# =============================================================================

_bytes_to_human() {
    local bytes="$1"
    bytes="${bytes:-0}"

    local gb=$((bytes / 1073741824))

    if [[ $gb -gt 0 ]]; then
        awk -v b="$bytes" 'BEGIN {printf "%.1fG", b / 1073741824}'
    else
        awk -v b="$bytes" 'BEGIN {printf "%.0fM", b / 1048576}'
    fi
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    local data percent used total

    if is_macos; then
        data=$(_collect_macos)
    elif is_linux; then
        data=$(_collect_linux)
    else
        data="0 0 0"
    fi

    read -r percent used total <<< "$data"

    plugin_data_set "percent" "${percent:-0}"
    plugin_data_set "used" "${used:-0}"
    plugin_data_set "total" "${total:-0}"
    plugin_data_set "available" "1"
}

# =============================================================================
# Plugin Contract: Type and Presence
# =============================================================================

plugin_get_content_type() {
    printf 'dynamic'
}

plugin_get_presence() {
    printf 'conditional'
}

# =============================================================================
# Plugin Contract: State
# =============================================================================

plugin_get_state() {
    local available
    available=$(plugin_data_get "available")
    [[ "$available" == "1" ]] && printf 'active' || printf 'inactive'
}

# =============================================================================
# Plugin Contract: Health
# =============================================================================

plugin_get_health() {
    local percent warn_th crit_th
    percent=$(plugin_data_get "percent")
    warn_th=$(get_option "warning_threshold")
    crit_th=$(get_option "critical_threshold")

    # Higher is worse (default behavior)
    evaluate_threshold_health "${percent:-0}" "${warn_th:-80}" "${crit_th:-90}"
}

# =============================================================================
# Plugin Contract: Context
# =============================================================================

plugin_get_context() {
    local health
    health=$(plugin_get_health)

    case "$health" in
        error)   printf 'critical_load' ;;
        warning) printf 'high_load' ;;
        *)       printf 'normal_load' ;;
    esac
}

# =============================================================================
# Plugin Contract: Icon
# =============================================================================

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# Plugin Contract: Render
# =============================================================================

plugin_render() {
    local format percent used total

    format=$(get_option "format")
    percent=$(plugin_data_get "percent")
    used=$(plugin_data_get "used")
    total=$(plugin_data_get "total")

    percent="${percent:-0}"

    # Note: show_only_on_threshold is handled by renderer via health

    case "$format" in
        usage)
            printf '%s/%s' "$(_bytes_to_human "$used")" "$(_bytes_to_human "$total")"
            ;;
        used)
            printf '%s' "$(_bytes_to_human "$used")"
            ;;
        percent|*)
            printf '%3d%%' "$percent"
            ;;
    esac
}

# =============================================================================
# Initialize Plugin
# =============================================================================

