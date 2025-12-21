#!/usr/bin/env bash
# =============================================================================
# Plugin: cpu
# Description: Display CPU usage percentage
# Type: conditional (with threshold support)
# Dependencies: None (uses /proc/stat on Linux, iostat/ps on macOS)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display
    declare_option "icon" "icon" $'\U0000f4bc' "Plugin icon (nf-mdi-chip)"

    # Colors
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Thresholds
    declare_option "threshold_mode" "string" "normal" "Threshold mode (none|normal|inverted)"
    declare_option "warning_threshold" "number" "70" "Warning threshold percentage"
    declare_option "critical_threshold" "number" "90" "Critical threshold percentage"
    declare_option "show_only_warning" "bool" "false" "Only show when threshold exceeded"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

plugin_init "cpu"

# =============================================================================
# Platform-Specific CPU Detection
# =============================================================================

# Linux: /proc/stat with sampling
_get_cpu_linux() {
    local line vals idle1 total1 idle2 total2 v

    line=$(grep '^cpu ' /proc/stat)
    read -ra vals <<< "${line#cpu }"
    idle1=${vals[3]}; total1=0
    for v in "${vals[@]}"; do total1=$((total1 + v)); done

    sleep "$POWERKIT_TIMING_CPU_SAMPLE"

    line=$(grep '^cpu ' /proc/stat)
    read -ra vals <<< "${line#cpu }"
    idle2=${vals[3]}; total2=0
    for v in "${vals[@]}"; do total2=$((total2 + v)); done

    local delta_idle=$((idle2 - idle1))
    local delta_total=$((total2 - total1))
    [[ $delta_total -gt 0 ]] && printf '%d' "$(( (1000 * (delta_total - delta_idle) / delta_total + 5) / 10 ))" || printf '0'
}

# macOS: iostat or ps fallback
_get_cpu_macos() {
    local cpu_usage
    cpu_usage=$(iostat -c "$POWERKIT_IOSTAT_COUNT" 2>/dev/null | tail -1 | \
        awk -v b="$POWERKIT_IOSTAT_BASELINE" -v f="$POWERKIT_IOSTAT_CPU_FIELD" '{printf "%.0f", b-$f}')

    if [[ -z "$cpu_usage" || "$cpu_usage" == "100" ]]; then
        local cores
        cores=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
        cpu_usage=$(ps -axo %cpu | awk -v c="$cores" -v l="$POWERKIT_PERF_CPU_PROCESS_LIMIT" \
            'NR>1 && NR<=l {s+=$1} END {a=s/c; if(a>100)a=100; printf "%.0f", a}')
    fi
    printf '%s' "${cpu_usage:-0}"
}

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

# Get current CPU value for threshold detection
# (can't rely on global variable because cache may skip _compute_cpu)
_get_current_cpu() {
    if is_linux; then
        _get_cpu_linux
    elif is_macos; then
        _get_cpu_macos
    else
        echo "0"
    fi
}

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="${1:-}"
    local cpu_value
    cpu_value=$(_get_current_cpu)
    threshold_plugin_display_info "$content" "$cpu_value"
}

# =============================================================================
# Main Logic
# =============================================================================

_compute_cpu() {
    local cpu_value
    if is_linux; then
        cpu_value=$(_get_cpu_linux)
    elif is_macos; then
        cpu_value=$(_get_cpu_macos)
    else
        cpu_value="N/A"
    fi

    [[ "$cpu_value" != "N/A" ]] && cpu_value=$(printf '%3d%%' "$cpu_value")
    printf '%s' "$cpu_value"
}

load_plugin() {
    cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_cpu
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
