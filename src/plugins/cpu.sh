#!/usr/bin/env bash
# =============================================================================
# Plugin: cpu
# Description: Display CPU usage percentage with threshold support
# Type: conditional (can hide when load is normal)
# Dependencies: None (uses /proc/stat on Linux, top/iostat/ps on macOS)
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active: CPU metrics are available and readable
#   - inactive: Unable to read CPU metrics
#
# Health:
#   - ok: CPU usage is below warning threshold
#   - warning: CPU usage is above warning but below critical
#   - error: CPU usage is above critical threshold
#
# Context:
#   - normal_load: CPU usage is normal (below warning)
#   - high_load: CPU usage is elevated (warning level)
#   - critical_load: CPU usage is critical
#
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "cpu"
    metadata_set "name" "CPU"
    metadata_set "description" "Display CPU usage percentage with threshold support"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    if is_macos; then
        require_cmd "top" 1    # Preferred
        require_cmd "iostat" 1 # Fallback
        require_cmd "ps" 1     # Fallback
    else
        # Linux: /proc/stat is the standard source
        [[ -f /proc/stat ]] || return 1
    fi
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Icons
    declare_option "icon" "icon" $'\U0000f4bc' "Plugin icon (nf-mdi-chip)"
    declare_option "icon_warning" "icon" "" "Icon when warning (empty = use default)"
    declare_option "icon_critical" "icon" "" "Icon when critical (empty = use default)"

    # Thresholds (higher = worse)
    declare_option "warning_threshold" "number" "70" "Warning threshold percentage"
    declare_option "critical_threshold" "number" "90" "Critical threshold percentage"

    # Display - show_only_on_threshold is auto-injected globally

    # Sampling (for more accurate readings on Linux)
    declare_option "sample_interval" "number" "0.1" "Sampling interval in seconds (Linux)"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

# =============================================================================
# Linux CPU Detection
# =============================================================================

# Read CPU from /proc/stat with delta sampling
_get_cpu_linux() {
    local sample_interval
    sample_interval=$(get_option "sample_interval")
    sample_interval="${sample_interval:-0.1}"

    local line vals idle1 total1 idle2 total2 v

    # First sample
    line=$(grep '^cpu ' /proc/stat 2>/dev/null)
    [[ -z "$line" ]] && { echo "0"; return; }
    read -ra vals <<< "${line#cpu }"
    idle1=$((vals[3] + vals[4]))
    total1=0
    for v in "${vals[@]}"; do
        total1=$((total1 + v))
    done

    # Wait for sample interval
    sleep "$sample_interval"

    # Second sample
    line=$(grep '^cpu ' /proc/stat 2>/dev/null)
    read -ra vals <<< "${line#cpu }"
    idle2=$((vals[3] + vals[4]))
    total2=0
    for v in "${vals[@]}"; do
        total2=$((total2 + v))
    done

    # Calculate percentage
    local delta_idle=$((idle2 - idle1))
    local delta_total=$((total2 - total1))

    if [[ $delta_total -gt 0 ]]; then
        local percent=$(( 100 * (delta_total - delta_idle) / delta_total ))
        (( percent > 100 )) && percent=100
        (( percent < 0 )) && percent=0
        printf '%d' "$percent"
    else
        printf '0'
    fi
}

# =============================================================================
# macOS CPU Detection
# =============================================================================

# Get CPU via top command (most accurate)
_get_cpu_macos_top() {
    local top_line idle busy

    # top -l 1 gives one sample
    top_line=$(top -l 1 2>/dev/null | grep "CPU usage" | head -1)

    if [[ "$top_line" =~ ([0-9.]+)%\ user,?[[:space:]]*([0-9.]+)%\ sys,?[[:space:]]*([0-9.]+)%\ idle ]]; then
        idle="${BASH_REMATCH[3]}"
        busy=$(echo "100 - $idle" | bc 2>/dev/null)
        printf '%.0f' "${busy:-0}"
        return 0
    fi

    return 1
}

# Get CPU via iostat (fallback)
_get_cpu_macos_iostat() {
    has_cmd iostat || return 1

    local cpu_usage
    # iostat -c 2: take 2 samples, use last one for accuracy
    cpu_usage=$(iostat -c 2 2>/dev/null | tail -1 | awk '{printf "%.0f", 100-$6}')

    [[ -n "$cpu_usage" && "$cpu_usage" != "100" ]] && { printf '%s' "$cpu_usage"; return 0; }
    return 1
}

# Get CPU via ps aggregate (last resort fallback)
_get_cpu_macos_ps() {
    local cores cpu_usage

    cores=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
    cpu_usage=$(ps -axo %cpu 2>/dev/null | awk -v c="$cores" '
        NR>1 && NR<=50 {s+=$1}
        END {a=s/c; if(a>100)a=100; printf "%.0f", a}
    ')

    printf '%s' "${cpu_usage:-0}"
}

# macOS entry point
_get_cpu_macos() {
    _get_cpu_macos_top 2>/dev/null || _get_cpu_macos_iostat 2>/dev/null || _get_cpu_macos_ps
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    local percent

    if is_macos; then
        percent=$(_get_cpu_macos)
    elif is_linux; then
        percent=$(_get_cpu_linux)
    else
        percent="0"
    fi

    # Ensure valid range
    percent="${percent:-0}"
    (( percent > 100 )) && percent=100
    (( percent < 0 )) && percent=0

    plugin_data_set "percent" "$percent"
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
# State reflects metric availability:
#   - active: CPU metrics available
#   - inactive: Unable to read metrics

plugin_get_state() {
    local available
    available=$(plugin_data_get "available")
    [[ "$available" == "1" ]] && printf 'active' || printf 'inactive'
}

# =============================================================================
# Plugin Contract: Health
# =============================================================================
# Health reflects CPU load level:
#   - ok: Below warning threshold
#   - warning: Above warning, below critical
#   - error: Above critical threshold

plugin_get_health() {
    local percent warn_th crit_th
    percent=$(plugin_data_get "percent")
    warn_th=$(get_option "warning_threshold")
    crit_th=$(get_option "critical_threshold")

    # Higher is worse (default behavior)
    evaluate_threshold_health "${percent:-0}" "${warn_th:-70}" "${crit_th:-90}"
}

# =============================================================================
# Plugin Contract: Context
# =============================================================================
# Context provides load state:
#   - normal_load, high_load, critical_load

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

plugin_get_icon() {
    local health icon_warn icon_crit

    health=$(plugin_get_health)
    icon_warn=$(get_option "icon_warning")
    icon_crit=$(get_option "icon_critical")

    case "$health" in
        error)
            [[ -n "$icon_crit" ]] && printf '%s' "$icon_crit" || get_option "icon"
            return
            ;;
        warning)
            [[ -n "$icon_warn" ]] && printf '%s' "$icon_warn" || get_option "icon"
            return
            ;;
        *)
            get_option "icon"
            return
            ;;
    esac
}

# =============================================================================
# Plugin Contract: Render
# =============================================================================

plugin_render() {
    local percent
    percent=$(plugin_data_get "percent")

    percent="${percent:-0}"

    # Note: show_only_on_threshold is handled by renderer via health

    # Format with padding for alignment
    printf '%3d%%' "$percent"
}

# =============================================================================
# Initialize Plugin
# =============================================================================

