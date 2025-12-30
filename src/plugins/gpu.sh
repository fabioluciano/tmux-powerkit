#!/usr/bin/env bash
# =============================================================================
# Plugin: gpu
# Description: Display GPU usage, memory, and temperature
# Dependencies:
#   macOS: powerkit-gpu binary (bundled)
#   Linux: nvidia-smi (NVIDIA) or sysfs (AMD/Intel)
# Supported GPUs:
#   - NVIDIA: Full support (usage, memory, temp)
#   - AMD: Full support (usage, memory, temp via sysfs)
#   - Intel: Frequency-based usage proxy (no dedicated memory)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "gpu"
    metadata_set "name" "GPU"
    metadata_set "description" "Display GPU usage, memory, and temperature"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    # macOS: powerkit-gpu binary (downloaded on-demand from releases)
    if is_macos; then
        require_macos_binary "powerkit-gpu" "gpu" || return 1
        return 0
    fi

    # Linux: NVIDIA
    has_cmd "nvidia-smi" && return 0

    # Linux: AMD (gpu_busy_percent)
    [[ -f "/sys/class/drm/card0/device/gpu_busy_percent" ]] && return 0
    [[ -f "/sys/class/drm/card1/device/gpu_busy_percent" ]] && return 0

    # Linux: Intel (frequency-based via i915/xe driver)
    [[ -f "/sys/class/drm/card0/gt/gt0/rps_cur_freq_mhz" ]] && return 0
    [[ -f "/sys/class/drm/card1/gt/gt0/rps_cur_freq_mhz" ]] && return 0

    return 1
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    # metric: usage, memory, temp, freq, all, or comma-separated (e.g., "usage,temp")
    # Note: Intel GPUs only support usage (frequency-based) and freq metrics
    declare_option "metric" "string" "all" "Metrics to display: usage, memory, temp, freq, all, or comma-separated"
    declare_option "separator" "string" " | " "Separator for multiple metrics"
    declare_option "show_metric_icons" "bool" "true" "Show icons next to each metric"

    # Memory format options (NVIDIA/AMD only - Intel uses shared system memory)
    # memory_use: only used (e.g., "409M")
    # memory_usage: used/allocated (e.g., "409M / 4.1G")
    # memory_percentage: percentage of allocation (e.g., "10%")
    declare_option "memory_format" "string" "memory_usage" "Memory format: memory_use, memory_usage, memory_percentage"

    # Icons
    declare_option "icon" "icon" $'\U000F061A' "Plugin icon"
    declare_option "icon_usage" "icon" $'\U0000f4bc' "Usage metric icon (nf-md-chip)"
    declare_option "icon_memory" "icon" $'\U0000efc5' "Memory metric icon (nf-md-memory)"
    declare_option "icon_temp" "icon" $'\U000F050F' "Temperature metric icon (nf-md-thermometer)"
    declare_option "icon_freq" "icon" $'\U000F0A40' "Frequency metric icon (nf-md-sine-wave)"

    # Thresholds for GPU usage (%)
    declare_option "usage_warning_threshold" "number" "70" "Usage warning threshold (%)"
    declare_option "usage_critical_threshold" "number" "90" "Usage critical threshold (%)"

    # Thresholds for memory usage (% of allocation)
    declare_option "memory_warning_threshold" "number" "70" "Memory warning threshold (%)"
    declare_option "memory_critical_threshold" "number" "90" "Memory critical threshold (%)"

    # Thresholds for temperature (°C)
    declare_option "temp_warning_threshold" "number" "70" "Temperature warning threshold (°C)"
    declare_option "temp_critical_threshold" "number" "85" "Temperature critical threshold (°C)"

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
    local health="ok"

    # Check GPU usage
    local usage usage_warn usage_crit
    usage=$(plugin_data_get "usage")
    usage_warn=$(get_option "usage_warning_threshold")
    usage_crit=$(get_option "usage_critical_threshold")
    usage="${usage:-0}"
    usage_warn="${usage_warn:-70}"
    usage_crit="${usage_crit:-90}"

    if (( usage >= usage_crit )); then
        health="error"
    elif (( usage >= usage_warn )); then
        [[ "$health" != "error" ]] && health="warning"
    fi

    # Check memory usage (% of allocation)
    local mem_used mem_total mem_percent mem_warn mem_crit
    mem_used=$(plugin_data_get "mem_used_mb")
    mem_total=$(plugin_data_get "mem_total_mb")
    mem_warn=$(get_option "memory_warning_threshold")
    mem_crit=$(get_option "memory_critical_threshold")
    mem_warn="${mem_warn:-70}"
    mem_crit="${mem_crit:-90}"

    if [[ "${mem_total:-0}" -gt 0 ]]; then
        mem_percent=$(( (mem_used * 100) / mem_total ))
        if (( mem_percent >= mem_crit )); then
            health="error"
        elif (( mem_percent >= mem_warn )); then
            [[ "$health" != "error" ]] && health="warning"
        fi
    fi

    # Check temperature
    local temp temp_warn temp_crit
    temp=$(plugin_data_get "temp")
    temp_warn=$(get_option "temp_warning_threshold")
    temp_crit=$(get_option "temp_critical_threshold")
    temp="${temp:-0}"
    temp_warn="${temp_warn:-70}"
    temp_crit="${temp_crit:-85}"

    if (( temp >= temp_crit )); then
        health="error"
    elif (( temp >= temp_warn )); then
        [[ "$health" != "error" ]] && health="warning"
    fi

    printf '%s' "$health"
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
# Intel GPU Detection Helper
# =============================================================================

_find_intel_gpu_dir() {
    # Find Intel GPU sysfs directory (i915 or xe driver)
    local card_dir
    for card_dir in /sys/class/drm/card0 /sys/class/drm/card1; do
        if [[ -f "${card_dir}/gt/gt0/rps_cur_freq_mhz" ]]; then
            printf '%s' "$card_dir"
            return 0
        fi
    done
    return 1
}

_collect_intel_gpu() {
    local card_dir="$1"
    local usage freq_cur freq_max

    # Read current and max frequency
    freq_cur=$(cat "${card_dir}/gt/gt0/rps_cur_freq_mhz" 2>/dev/null)
    freq_max=$(cat "${card_dir}/gt/gt0/rps_max_freq_mhz" 2>/dev/null)

    [[ -z "$freq_cur" || -z "$freq_max" ]] && return 1

    # Calculate usage as percentage of max frequency
    if (( freq_max > 0 )); then
        usage=$(( (freq_cur * 100) / freq_max ))
    else
        usage=0
    fi

    plugin_data_set "usage" "$usage"
    plugin_data_set "freq_cur" "$freq_cur"
    plugin_data_set "freq_max" "$freq_max"
    plugin_data_set "gpu_type" "intel"
    plugin_data_set "available" "1"

    return 0
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    local usage temp mem_used_mb mem_total_mb
    local available=0
    local gpu_type=""

    if is_macos; then
        local powerkit_gpu="${POWERKIT_ROOT}/bin/powerkit-gpu"

        if [[ -x "$powerkit_gpu" ]]; then
            # Get usage
            usage=$("$powerkit_gpu" -u 2>/dev/null)

            # Get memory (format: usedMB\x1FtotalMB)
            local mem_output
            mem_output=$("$powerkit_gpu" -m 2>/dev/null)
            if [[ -n "$mem_output" ]]; then
                # Parse using \x1F as separator
                mem_used_mb="${mem_output%%$'\x1F'*}"
                mem_total_mb="${mem_output##*$'\x1F'}"
            fi

            # Get temperature
            temp=$("$powerkit_gpu" -t 2>/dev/null)

            [[ -n "$usage" && "$usage" =~ ^[0-9]+$ ]] && { available=1; gpu_type="macos"; }
        fi
    else
        # Linux: NVIDIA GPU via nvidia-smi
        if has_cmd "nvidia-smi"; then
            # Check if nvidia-smi works (driver might be broken/mismatched)
            if nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 | grep -q .; then
                usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
                temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)

                # Get memory used/total in MB
                local mem_used mem_total
                mem_used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | head -1)
                mem_total=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)
                mem_used_mb="${mem_used:-0}"
                mem_total_mb="${mem_total:-0}"

                [[ -n "$usage" && "$usage" =~ ^[0-9]+$ ]] && { available=1; gpu_type="nvidia"; }
            fi
        fi

        # Linux: AMD GPU via amdgpu driver (sysfs)
        if [[ "$available" -eq 0 ]]; then
            local amd_gpu_dir="/sys/class/drm/card0/device"
            [[ ! -f "${amd_gpu_dir}/gpu_busy_percent" ]] && amd_gpu_dir="/sys/class/drm/card1/device"

            if [[ -f "${amd_gpu_dir}/gpu_busy_percent" ]]; then
                usage=$(cat "${amd_gpu_dir}/gpu_busy_percent" 2>/dev/null)

                # AMD temperature (hwmon)
                local hwmon_dir
                hwmon_dir=$(ls -d "${amd_gpu_dir}"/hwmon/hwmon* 2>/dev/null | head -1)
                if [[ -n "$hwmon_dir" && -f "${hwmon_dir}/temp1_input" ]]; then
                    local temp_milli
                    temp_milli=$(cat "${hwmon_dir}/temp1_input" 2>/dev/null)
                    temp=$(( temp_milli / 1000 ))
                fi

                # AMD VRAM via drm (if available)
                if [[ -f "${amd_gpu_dir}/mem_info_vram_used" ]]; then
                    local vram_used vram_total
                    vram_used=$(cat "${amd_gpu_dir}/mem_info_vram_used" 2>/dev/null)
                    vram_total=$(cat "${amd_gpu_dir}/mem_info_vram_total" 2>/dev/null)
                    # Convert bytes to MB
                    mem_used_mb=$(( vram_used / 1048576 ))
                    mem_total_mb=$(( vram_total / 1048576 ))
                fi

                [[ -n "$usage" && "$usage" =~ ^[0-9]+$ ]] && { available=1; gpu_type="amd"; }
            fi
        fi

        # Linux: Intel GPU via i915/xe driver (frequency-based)
        if [[ "$available" -eq 0 ]]; then
            local intel_dir
            intel_dir=$(_find_intel_gpu_dir)
            if [[ -n "$intel_dir" ]]; then
                _collect_intel_gpu "$intel_dir"
                return  # Intel collection sets all data internally
            fi
        fi
    fi

    plugin_data_set "available" "$available"
    plugin_data_set "usage" "${usage:-0}"
    plugin_data_set "mem_used_mb" "${mem_used_mb:-0}"
    plugin_data_set "mem_total_mb" "${mem_total_mb:-0}"
    plugin_data_set "temp" "${temp:-0}"
    plugin_data_set "gpu_type" "$gpu_type"
}

# Format MB to human-readable (M or G)
_format_memory_value() {
    local mb="$1"
    if (( mb >= 1024 )); then
        local gb_int=$(( mb / 1024 ))
        local gb_dec=$(( (mb % 1024) * 10 / 1024 ))
        printf '%d.%dG' "$gb_int" "$gb_dec"
    else
        printf '%dM' "$mb"
    fi
}

_format_memory() {
    local mem_used_mb="$1"
    local mem_total_mb="$2"
    local format="$3"

    case "$format" in
        memory_usage)
            # Format: used / allocated (e.g., "409M / 4.1G")
            local used_str total_str
            used_str="$(_format_memory_value "${mem_used_mb:-0}")"
            total_str="$(_format_memory_value "${mem_total_mb:-0}")"
            printf '%s/%s' "$used_str" "$total_str"
            ;;
        memory_percentage)
            # Format: percentage of allocation (e.g., "10%")
            if [[ "${mem_total_mb:-0}" -gt 0 ]]; then
                local percent=$(( (mem_used_mb * 100) / mem_total_mb ))
                printf '%d%%' "$percent"
            else
                printf '0%%'
            fi
            ;;
        memory_use|*)
            # Format: only used (e.g., "409M")
            if [[ -n "$mem_used_mb" && "$mem_used_mb" != "0" ]]; then
                _format_memory_value "$mem_used_mb"
            else
                printf '0M'
            fi
            ;;
    esac
}

plugin_render() {
    local metric separator show_icons memory_format gpu_type
    local usage mem_used_mb mem_total_mb temp freq_cur freq_max
    local parts=()

    metric=$(get_option "metric")
    separator=$(get_option "separator")
    show_icons=$(get_option "show_metric_icons")
    memory_format=$(get_option "memory_format")

    usage=$(plugin_data_get "usage")
    mem_used_mb=$(plugin_data_get "mem_used_mb")
    mem_total_mb=$(plugin_data_get "mem_total_mb")
    temp=$(plugin_data_get "temp")
    freq_cur=$(plugin_data_get "freq_cur")
    freq_max=$(plugin_data_get "freq_max")
    gpu_type=$(plugin_data_get "gpu_type")

    # Get icons if enabled
    local icon_usage="" icon_memory="" icon_temp="" icon_freq=""
    if [[ "$show_icons" == "true" ]]; then
        icon_usage="$(get_option "icon_usage") "
        icon_memory="$(get_option "icon_memory") "
        icon_temp="$(get_option "icon_temp") "
        icon_freq="$(get_option "icon_freq") "
    fi

    # Format memory based on memory_format option
    local memory_str
    memory_str="$(_format_memory "$mem_used_mb" "$mem_total_mb" "$memory_format")"

    # Handle "all" as shorthand for all metrics
    # For Intel, "all" means usage and freq (no memory/temp)
    if [[ "$metric" == "all" ]]; then
        if [[ "$gpu_type" == "intel" ]]; then
            metric="usage,freq"
        else
            metric="usage,memory,temp"
        fi
    fi

    # Build parts array based on requested metrics
    local IFS=','
    local requested_metrics
    read -ra requested_metrics <<< "$metric"

    for m in "${requested_metrics[@]}"; do
        # Trim whitespace
        m="${m// /}"
        case "$m" in
            usage)
                parts+=("${icon_usage}${usage:-0}%")
                ;;
            memory)
                # Skip memory for Intel (uses shared system memory)
                [[ "$gpu_type" == "intel" ]] && continue
                parts+=("${icon_memory}${memory_str}")
                ;;
            temp)
                # Skip temp for Intel if not available
                [[ "$gpu_type" == "intel" ]] && continue
                parts+=("${icon_temp}${temp:-0}°C")
                ;;
            freq)
                # Frequency metric (mainly useful for Intel)
                if [[ -n "$freq_cur" ]]; then
                    parts+=("${icon_freq}${freq_cur}/${freq_max}MHz")
                fi
                ;;
        esac
    done

    # Output parts with separator
    local first=1
    for part in "${parts[@]}"; do
        (( first )) || printf '%s' "$separator"
        printf '%s' "$part"
        first=0
    done
}

