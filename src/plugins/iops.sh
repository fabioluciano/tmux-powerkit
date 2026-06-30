#!/usr/bin/env bash
# =============================================================================
# Plugin: iops
# Description: Display disk IOPS (Input/Output Operations Per Second)
# Dependencies: iostat (Linux) or ioreg (macOS)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "iops"
    metadata_set "name" "IOPS"
    metadata_set "description" "Display disk IOPS (read/write)"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    if is_macos; then
        require_cmd "ioreg" || return 1
    else
        require_cmd "iostat" || return 1
    fi
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "show" "string" "both" "What to show: both, read, write"
    declare_option "icon_read" "icon" $'\U000F06C3' "Read icon (arrow up)"
    declare_option "icon_write" "icon" $'\U000F06C0' "Write icon (arrow down)"
    declare_option "separator" "string" " | " "Separator between read/write"

    # Icons
    declare_option "icon" "icon" $'\U000F02CA' "Plugin icon (harddisk)"

    # Thresholds (in bytes/s - 100MB/s warning, 500MB/s critical)
    # Kept for backward compatibility (no longer used by plugin_get_health)
    declare_option "warning_threshold" "number" "104857600" "Warning threshold (bytes/s)"
    declare_option "critical_threshold" "number" "524288000" "Critical threshold (bytes/s)"

    # Saturation thresholds (in % disk utilization)
    declare_option "util_warning_threshold" "number" "60" "Utilization warning threshold (%)"
    declare_option "util_critical_threshold" "number" "85" "Utilization critical threshold (%)"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'always'; }
plugin_get_state() { printf 'active'; }

plugin_get_health() {
    local util util_warn util_crit
    util=$(plugin_data_get "util")
    util_warn=$(get_option "util_warning_threshold")
    util_crit=$(get_option "util_critical_threshold")

    evaluate_threshold_health "${util:-0}" "${util_warn:-60}" "${util_crit:-85}"
}

plugin_get_context() {
    local read_rate write_rate total_rate
    read_rate=$(plugin_data_get "read_rate")
    write_rate=$(plugin_data_get "write_rate")
    total_rate=$(plugin_data_get "total_rate")
    
    read_rate="${read_rate:-0}"
    write_rate="${write_rate:-0}"
    total_rate="${total_rate:-0}"
    
    if (( total_rate == 0 )); then
        printf 'idle'
    elif (( read_rate > write_rate * 2 )); then
        printf 'read_heavy'
    elif (( write_rate > read_rate * 2 )); then
        printf 'write_heavy'
    else
        printf 'balanced'
    fi
}

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# macOS Implementation using ioreg
# =============================================================================

_get_throughput_macos() {
    local now=$EPOCHSECONDS
    
    # Get current bytes from ioreg (all disks combined)
    local stats
    stats=$(ioreg -c IOBlockStorageDriver -r -w 0 2>/dev/null | grep -o '"Statistics" = {[^}]*}')
    
    [[ -z "$stats" ]] && { printf '0|0'; return 1; }
    
    # Sum bytes from all disks
    local total_read_bytes=0
    local total_write_bytes=0
    
    while IFS= read -r line; do
        local read_bytes write_bytes
        read_bytes=$(echo "$line" | grep -o '"Bytes (Read)"=[0-9]*' | grep -o '[0-9]*')
        write_bytes=$(echo "$line" | grep -o '"Bytes (Write)"=[0-9]*' | grep -o '[0-9]*')
        total_read_bytes=$((total_read_bytes + ${read_bytes:-0}))
        total_write_bytes=$((total_write_bytes + ${write_bytes:-0}))
    done <<< "$stats"
    
    # Read previous state from cache
    local prev_state prev_time=0 prev_read=0 prev_write=0
    if prev_state=$(cache_get "iops_state" 86400); then
        IFS='|' read -r prev_time prev_read prev_write <<< "$prev_state"
    fi
    
    # Save current state to cache
    cache_set "iops_state" "${now}|${total_read_bytes}|${total_write_bytes}"
    
    # Calculate delta (bytes per second)
    local time_delta=$((now - prev_time))
    if (( time_delta > 0 && prev_time > 0 )); then
        local read_delta=$((total_read_bytes - prev_read))
        local write_delta=$((total_write_bytes - prev_write))
        
        # Avoid negative values (can happen on system restart)
        (( read_delta < 0 )) && read_delta=0
        (( write_delta < 0 )) && write_delta=0
        
        local read_rate=$((read_delta / time_delta))
        local write_rate=$((write_delta / time_delta))
        
        printf '%d|%d' "$read_rate" "$write_rate"
    else
        # First run, no delta available
        printf '0|0'
    fi
}

_get_util_macos() {
    local total_rate
    total_rate=$(plugin_data_get "total_rate")
    total_rate="${total_rate:-0}"

    local pseudo_util=$(( total_rate / 10485760 ))
    (( pseudo_util > 100 )) && pseudo_util=100
    printf '%d' "$pseudo_util"
}

# =============================================================================
# Linux Implementation using /proc/diskstats
# =============================================================================

_get_throughput_linux() {
    local now=$EPOCHSECONDS
    
    # Read from /proc/diskstats (sectors read/written)
    # Format: major minor name reads_completed reads_merged sectors_read ms_reading writes_completed writes_merged sectors_written ...
    local stats
    stats=$(cat /proc/diskstats 2>/dev/null)
    
    [[ -z "$stats" ]] && { printf '0|0'; return 1; }
    
    # Sum sectors from all real disks (sd*, nvme*, vd*)
    local total_read_sectors=0
    local total_write_sectors=0
    
    while IFS= read -r line; do
        local name read_sectors write_sectors
        name=$(echo "$line" | awk '{print $3}')
        
        # Only count main disks, not partitions (sda not sda1, nvme0n1 not nvme0n1p1)
        if [[ "$name" =~ ^(sd[a-z]|nvme[0-9]+n[0-9]+|vd[a-z])$ ]]; then
            read_sectors=$(echo "$line" | awk '{print $6}')
            write_sectors=$(echo "$line" | awk '{print $10}')
            total_read_sectors=$((total_read_sectors + ${read_sectors:-0}))
            total_write_sectors=$((total_write_sectors + ${write_sectors:-0}))
        fi
    done <<< "$stats"
    
    # Convert sectors to bytes (sector = 512 bytes)
    local total_read_bytes=$((total_read_sectors * 512))
    local total_write_bytes=$((total_write_sectors * 512))
    
    # Read previous state from cache
    local prev_state prev_time=0 prev_read=0 prev_write=0
    if prev_state=$(cache_get "iops_state" 86400); then
        IFS='|' read -r prev_time prev_read prev_write <<< "$prev_state"
    fi
    
    # Save current state to cache
    cache_set "iops_state" "${now}|${total_read_bytes}|${total_write_bytes}"
    
    # Calculate delta (bytes per second)
    local time_delta=$((now - prev_time))
    if (( time_delta > 0 && prev_time > 0 )); then
        local read_delta=$((total_read_bytes - prev_read))
        local write_delta=$((total_write_bytes - prev_write))
        
        # Avoid negative values
        (( read_delta < 0 )) && read_delta=0
        (( write_delta < 0 )) && write_delta=0
        
        local read_rate=$((read_delta / time_delta))
        local write_rate=$((write_delta / time_delta))
        
        printf '%d|%d' "$read_rate" "$write_rate"
    else
        printf '0|0'
    fi
}

_get_util_linux() {
    local now=${EPOCHSECONDS:-$(date +%s)}

    local total_io_ms=0
    while IFS= read -r line; do
        local fields
        read -ra fields <<< "$line"
        local dev="${fields[2]}"
        [[ "$dev" =~ ^(loop|dm-|sr) ]] && continue
        local io_ms="${fields[12]:-0}"
        total_io_ms=$((total_io_ms + io_ms))
    done < /proc/diskstats 2>/dev/null

    local prev_io_ms prev_time
    prev_io_ms=$(cache_get "iops_util_io_ms" 86400)
    prev_time=$(cache_get "iops_util_time" 86400)

    cache_set "iops_util_io_ms" "$total_io_ms"
    cache_set "iops_util_time" "$now"

    [[ -z "$prev_io_ms" || -z "$prev_time" ]] && { printf '0'; return; }

    local delta_io=$((total_io_ms - prev_io_ms))
    local delta_time=$(( (now - prev_time) * 1000 ))

    (( delta_io < 0 )) && delta_io=0

    if (( delta_time > 0 )); then
        local util=$(( delta_io * 100 / delta_time ))
        (( util > 100 )) && util=100
        printf '%d' "$util"
    else
        printf '0'
    fi
}

# =============================================================================
# Main Logic
# =============================================================================

_get_throughput() {
    if is_macos; then
        _get_throughput_macos
    else
        _get_throughput_linux
    fi
}

plugin_collect() {
    local data
    data=$(_get_throughput)

    local read_rate write_rate
    IFS='|' read -r read_rate write_rate <<< "$data"

    read_rate="${read_rate:-0}"
    write_rate="${write_rate:-0}"

    plugin_data_set "read_rate" "$read_rate"
    plugin_data_set "write_rate" "$write_rate"
    plugin_data_set "total_rate" "$((read_rate + write_rate))"

    local util=0
    if is_linux; then
        util=$(_get_util_linux)
    elif is_macos; then
        util=$(_get_util_macos)
    fi
    plugin_data_set "util" "${util:-0}"
}

plugin_render() {
    local show read_rate write_rate icon_read icon_write separator
    show=$(get_option "show")
    icon_read=$(get_option "icon_read")
    icon_write=$(get_option "icon_write")
    separator=$(get_option "separator")
    read_rate=$(plugin_data_get "read_rate")
    write_rate=$(plugin_data_get "write_rate")

    read_rate="${read_rate:-0}"
    write_rate="${write_rate:-0}"

    local parts=()
    [[ "$show" == "both" || "$show" == "read" ]] && parts+=("$(format_bytes "$read_rate")/s ${icon_read}")
    [[ "$show" == "both" || "$show" == "write" ]] && parts+=("$(format_bytes "$write_rate")/s ${icon_write}")

    [[ ${#parts[@]} -gt 0 ]] && join_with_separator "$separator" "${parts[@]}"
}

