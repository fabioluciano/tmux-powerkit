#!/usr/bin/env bash
# =============================================================================
# Plugin: sysstatus
# Description: Display aggregated system health badge (OK/WARN/CRIT)
# Dependencies: None (POSIX commands only)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "sysstatus"
    metadata_set "name" "System Status"
    metadata_set "description" "Display aggregated system health badge"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    # All commands are POSIX: ps, free/awk, df, cat
    # Platform-specific: top (available everywhere), vm_stat/sysctl (macOS)
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    declare_option "icon" "icon" $'\U000F0560' "Plugin icon (dashboard)"
    declare_option "cpu_warning" "number" "70" "CPU warning threshold (%)"
    declare_option "cpu_critical" "number" "90" "CPU critical threshold (%)"
    declare_option "mem_warning" "number" "80" "Memory warning threshold (%)"
    declare_option "mem_critical" "number" "95" "Memory critical threshold (%)"
    declare_option "disk_warning" "number" "80" "Disk warning threshold (%)"
    declare_option "disk_critical" "number" "95" "Disk critical threshold (%)"
    declare_option "temp_warning" "number" "75" "Temperature warning threshold (°C)"
    declare_option "temp_critical" "number" "90" "Temperature critical threshold (°C)"
    declare_option "format" "string" "badge" "Display format: badge, count, detail"
    declare_option "cache_ttl" "number" "10" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'always'; }

plugin_get_state() { printf 'active'; }

plugin_get_health() {
    local cpu_health mem_health disk_health temp_health
    
    cpu_health=$(plugin_data_get "cpu_health")
    mem_health=$(plugin_data_get "mem_health")
    disk_health=$(plugin_data_get "disk_health")
    temp_health=$(plugin_data_get "temp_health")
    
    # Aggregate using health_max (returns worst case)
    local worst_health="ok"
    
    [[ -n "$cpu_health" ]] && worst_health=$(health_max "$worst_health" "$cpu_health")
    [[ -n "$mem_health" ]] && worst_health=$(health_max "$worst_health" "$mem_health")
    [[ -n "$disk_health" ]] && worst_health=$(health_max "$worst_health" "$disk_health")
    [[ -n "$temp_health" ]] && worst_health=$(health_max "$worst_health" "$temp_health")
    
    printf '%s' "$worst_health"
}

plugin_get_context() {
    plugin_context_from_health "$(plugin_get_health)" "system"
}

plugin_get_icon() {
    get_option "icon"
}

# =============================================================================
# System Metrics Collection (Private Functions)
# =============================================================================

_collect_cpu_health() {
    local warn_th crit_th
    warn_th=$(get_option "cpu_warning")
    crit_th=$(get_option "cpu_critical")
    
    local cpu_pct=""
    
    if is_macos; then
        # macOS: top -l1 sample
        cpu_pct=$(top -l1 2>/dev/null | awk '/^CPU usage/ {gsub(/%/,""); print $3}')
    elif is_linux; then
        # Linux: top -bn1 batch mode
        cpu_pct=$(top -bn1 2>/dev/null | awk '/^%Cpu/ {gsub(/[^0-9.]/,"",$2); print $2}')
    fi
    
    cpu_pct=$(extract_numeric "${cpu_pct:-0}")
    
    evaluate_threshold_health "$cpu_pct" "$warn_th" "$crit_th"
}

_collect_mem_health() {
    local warn_th crit_th
    warn_th=$(get_option "mem_warning")
    crit_th=$(get_option "mem_critical")
    
    local mem_pct=""
    
    if is_macos; then
        # macOS: memory_pressure
        local free_pct
        free_pct=$(memory_pressure 2>/dev/null | awk '/System-wide memory free percentage:/ {print $5}' | tr -d '%')
        [[ -n "$free_pct" ]] && mem_pct=$((100 - free_pct))
    elif is_linux; then
        # Linux: /proc/meminfo
        local mem_info
        mem_info=$(awk '/^MemAvailable/ {avail=$2} /^MemTotal/ {total=$2} END {if (total>0) printf "%.0f", (total-avail)/total*100}' /proc/meminfo 2>/dev/null)
        [[ -n "$mem_info" ]] && mem_pct="$mem_info"
    fi
    
    mem_pct=$(extract_numeric "${mem_pct:-0}")
    
    evaluate_threshold_health "$mem_pct" "$warn_th" "$crit_th"
}

_collect_disk_health() {
    local warn_th crit_th
    warn_th=$(get_option "disk_warning")
    crit_th=$(get_option "disk_critical")
    
    # Cross-platform: df -h /
    local disk_pct
    disk_pct=$(df / 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
    
    disk_pct=$(extract_numeric "${disk_pct:-0}")
    
    evaluate_threshold_health "$disk_pct" "$warn_th" "$crit_th"
}

_collect_temp_health() {
    local warn_th crit_th
    warn_th=$(get_option "temp_warning")
    crit_th=$(get_option "temp_critical")
    
    local temp_c=""
    
    if is_macos; then
        # macOS: osx-cpu-temp or smctemp if available
        if has_cmd "osx-cpu-temp"; then
            temp_c=$(osx-cpu-temp 2>/dev/null | awk '{gsub(/°C/,""); print $1}')
        elif has_cmd "smctemp"; then
            temp_c=$(smctemp 2>/dev/null | awk '{print $2}')
        fi
    elif is_linux; then
        # Linux: /sys/class/thermal/thermal_zone0/temp (millidegrees)
        if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
            temp_c=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
            temp_c=$((temp_c / 1000))
        fi
    fi
    
    # If no temp available, skip (don't affect health)
    [[ -z "$temp_c" ]] && return 1
    
    evaluate_threshold_health "$temp_c" "$warn_th" "$crit_th"
}

# =============================================================================
# Main Logic
# =============================================================================

plugin_collect() {
    # Collect individual metrics and compute health
    plugin_data_set "cpu_health" "$(_collect_cpu_health)"
    plugin_data_set "mem_health" "$(_collect_mem_health)"
    plugin_data_set "disk_health" "$(_collect_disk_health)"

    local temp_health
    temp_health=$(_collect_temp_health)
    [[ -n "$temp_health" ]] && plugin_data_set "temp_health" "$temp_health"

    # Always return 0 — temp sensor absence is not a failure
    return 0
}

plugin_render() {
    local format health
    format=$(get_option "format")
    health=$(plugin_get_health)
    
    case "$format" in
        count)
            local warn_count=0 crit_count=0
            
            [[ $(plugin_data_get "cpu_health") == "warning" ]] && ((warn_count++))
            [[ $(plugin_data_get "cpu_health") == "error" ]] && ((crit_count++))
            [[ $(plugin_data_get "mem_health") == "warning" ]] && ((warn_count++))
            [[ $(plugin_data_get "mem_health") == "error" ]] && ((crit_count++))
            [[ $(plugin_data_get "disk_health") == "warning" ]] && ((warn_count++))
            [[ $(plugin_data_get "disk_health") == "error" ]] && ((crit_count++))
            [[ $(plugin_data_get "temp_health") == "warning" ]] && ((warn_count++))
            [[ $(plugin_data_get "temp_health") == "error" ]] && ((crit_count++))
            
            if (( crit_count > 0 )); then
                printf '%d CRIT' "$crit_count"
            elif (( warn_count > 0 )); then
                printf '%d WARN' "$warn_count"
            else
                printf 'OK'
            fi
            ;;
        detail)
            # Show critical metrics only
            local details=()
            
            [[ $(plugin_data_get "cpu_health") == "error" ]] && details+=("CPU CRIT")
            [[ $(plugin_data_get "cpu_health") == "warning" ]] && details+=("CPU WARN")
            [[ $(plugin_data_get "mem_health") == "error" ]] && details+=("MEM CRIT")
            [[ $(plugin_data_get "mem_health") == "warning" ]] && details+=("MEM WARN")
            [[ $(plugin_data_get "disk_health") == "error" ]] && details+=("DISK CRIT")
            [[ $(plugin_data_get "disk_health") == "warning" ]] && details+=("DISK WARN")
            [[ $(plugin_data_get "temp_health") == "error" ]] && details+=("TEMP CRIT")
            [[ $(plugin_data_get "temp_health") == "warning" ]] && details+=("TEMP WARN")
            
            if [[ ${#details[@]} -eq 0 ]]; then
                printf 'OK'
            else
                join_with_separator "|" "${details[@]}"
            fi
            ;;
        badge|*)
            case "$health" in
                error)   printf 'CRIT' ;;
                warning) printf 'WARN' ;;
                *)       printf 'OK' ;;
            esac
            ;;
    esac
}
