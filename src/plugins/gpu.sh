#!/usr/bin/env bash
# =============================================================================
# Plugin: gpu
# Description: Display GPU usage (macOS with Intel Power Gadget or nvidia-smi)
# Dependencies: Intel Power Gadget (macOS) or nvidia-smi (Linux/macOS)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "gpu"
    metadata_set "name" "GPU"
    metadata_set "description" "Display GPU usage"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_any_cmd "nvidia-smi" "ioreg" || return 1
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "show_percentage" "bool" "true" "Show percentage symbol"
    declare_option "metric" "string" "usage" "Metric to display: usage, memory, temp"

    # Icons
    declare_option "icon" "icon" $'\U000F0595' "Plugin icon"

    # Thresholds (for usage percentage)
    declare_option "warning_threshold" "number" "70" "Warning threshold (%)"
    declare_option "critical_threshold" "number" "90" "Critical threshold (%)"

    # Cache
    declare_option "cache_ttl" "number" "3" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }
plugin_get_state() {
    local available=$(plugin_data_get "available")
    [[ "$available" == "1" ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() {
    local usage warn_th crit_th
    usage=$(plugin_data_get "usage")
    warn_th=$(get_option "warning_threshold")
    crit_th=$(get_option "critical_threshold")

    usage="${usage:-0}"
    warn_th="${warn_th:-70}"
    crit_th="${crit_th:-90}"

    if (( usage >= crit_th )); then
        printf 'error'
    elif (( usage >= warn_th )); then
        printf 'warning'
    else
        printf 'ok'
    fi
}

plugin_get_context() {
    local usage=$(plugin_data_get "usage")
    usage="${usage:-0}"
    
    if (( usage == 0 )); then
        printf 'idle'
    elif (( usage < 30 )); then
        printf 'light'
    elif (( usage < 70 )); then
        printf 'moderate'
    else
        printf 'heavy'
    fi
}

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# Main Logic
# =============================================================================

_get_gpu_nvidia() {
    local metric=$(get_option "metric")
    
    if has_cmd "nvidia-smi"; then
        case "$metric" in
            usage)
                nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1
                ;;
            memory)
                nvidia-smi --query-gpu=utilization.memory --format=csv,noheader,nounits 2>/dev/null | head -1
                ;;
            temp)
                nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1
                ;;
            *)
                nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1
                ;;
        esac
        return 0
    fi
    return 1
}

_get_gpu_macos() {
    # macOS GPU usage is harder to get. Try ioreg for basic info
    if has_cmd "ioreg"; then
        local gpu_perf
        gpu_perf=$(ioreg -r -d 1 -w 0 -c "IOAccelerator" 2>/dev/null | grep "PerformanceStatistics" | head -1)
        
        if [[ -n "$gpu_perf" ]]; then
            # This is a rough estimate - actual implementation would need more parsing
            printf '0'  # Placeholder - real implementation needs proper parsing
            return 0
        fi
    fi
    return 1
}

plugin_collect() {
    local value

    # Try NVIDIA first
    value=$(_get_gpu_nvidia)
    
    # Fallback to macOS if NVIDIA not available
    if [[ -z "$value" ]] && is_macos; then
        value=$(_get_gpu_macos)
    fi

    if [[ -n "$value" ]]; then
        plugin_data_set "available" "1"
        plugin_data_set "usage" "${value:-0}"
    else
        plugin_data_set "available" "0"
    fi
}

plugin_render() {
    local usage metric show_pct
    usage=$(plugin_data_get "usage")
    metric=$(get_option "metric")
    show_pct=$(get_option "show_percentage")

    [[ -z "$usage" ]] && return 0

    case "$metric" in
        temp)
            printf '%s°C' "$usage"
            ;;
        *)
            [[ "$show_pct" == "true" ]] && printf '%s%%' "$usage" || printf '%s' "$usage"
            ;;
    esac
}

