#!/usr/bin/env bash
# =============================================================================
# Plugin: iops - Display disk I/O statistics
# Description: Show read/write throughput or IOPS for disk devices
# Dependencies: iostat (Linux) or native (macOS)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    if is_linux; then
        require_cmd "iostat" || return 1
    fi
    # macOS: no external dependencies
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "device" "string" "" "Disk device to monitor (auto-detect if empty)"
    declare_option "format" "string" "throughput" "Display format (throughput|iops)"
    declare_option "show_rw" "string" "both" "Show read/write (both|read|write)"
    declare_option "separator" "string" " | " "Separator between read/write values"
    declare_option "show_when_idle" "bool" "true" "Show plugin when disk is idle"

    # Icons
    declare_option "icon" "icon" $'\U000F00A0' "Plugin icon"

    # Colors
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Thresholds
    declare_option "warning_threshold" "number" "100" "Warning threshold (MB/s or IOPS)"
    declare_option "critical_threshold" "number" "200" "Critical threshold (MB/s or IOPS)"

    # Cache
    declare_option "cache_ttl" "number" "2" "Cache duration in seconds"
}

plugin_init "iops"

# Previous values for delta calculation
IOPS_PREV_FILE="${CACHE_DIR}/iops_prev"

# =============================================================================
# Main Logic
# =============================================================================

# Auto-detect primary disk device
_detect_device() {
    if is_macos; then
        # macOS: use disk0 (usually the main disk)
        printf 'disk0'
    elif is_linux; then
        # Linux: find the root filesystem device
        local root_dev
        root_dev=$(df / 2>/dev/null | awk 'NR==2 {print $1}')
        # Extract base device name (e.g., sda from sda1, nvme0n1 from nvme0n1p1)
        if [[ "$root_dev" == *"nvme"* ]]; then
            printf '%s' "${root_dev%p*}" | sed 's|/dev/||'
        else
            printf '%s' "${root_dev%[0-9]*}" | sed 's|/dev/||'
        fi
    fi
}

# Get I/O stats for Linux via /proc/diskstats
_get_io_linux() {
    local device="${1:-$(_detect_device)}"
    [[ -z "$device" ]] && return 1

    # /proc/diskstats format:
    # Field  3 - reads completed successfully
    # Field  4 - reads merged
    # Field  5 - sectors read
    # Field  6 - time spent reading (ms)
    # Field  7 - writes completed
    # Field  8 - writes merged
    # Field  9 - sectors written
    # Field 10 - time spent writing (ms)

    local stats
    stats=$(awk -v dev="$device" '$3 == dev {print $4, $6, $8, $10}' /proc/diskstats 2>/dev/null)
    [[ -z "$stats" ]] && return 1

    local reads_completed sectors_read writes_completed sectors_written
    read -r reads_completed sectors_read writes_completed sectors_written <<<"$stats"

    # Each sector is 512 bytes
    local read_bytes=$((sectors_read * 512))
    local write_bytes=$((sectors_written * 512))

    printf '%s|%s|%s|%s' "$reads_completed" "$read_bytes" "$writes_completed" "$write_bytes"
}

# Get I/O stats for macOS via iostat
_get_io_macos() {
    local device="${1:-disk0}"

    # iostat output format: KB/t, tps, MB/s
    local stats
    stats=$(iostat -d -c 2 "$device" 2>/dev/null | tail -1)
    [[ -z "$stats" ]] && return 1

    # Parse iostat output (KB/t tps MB/s)
    local _ tps mb_per_s
    read -r _ tps mb_per_s <<<"$stats"

    # Convert MB/s to bytes
    local bytes_per_s
    bytes_per_s=$(awk -v mb="$mb_per_s" 'BEGIN { printf "%.0f", mb * 1048576 }')

    # iostat doesn't separate read/write on macOS basic output
    # Return combined values (split 50/50 for display)
    local half_bytes=$((bytes_per_s / 2))
    local half_ops
    half_ops=$(awk -v t="$tps" 'BEGIN { printf "%.0f", t / 2 }')

    printf '%s|%s|%s|%s' "$half_ops" "$half_bytes" "$half_ops" "$half_bytes"
}

# Calculate delta from previous measurement
_calculate_delta() {
    local current="$1"
    local prev="$2"
    local interval="$3"

    [[ -z "$prev" || "$prev" == "0" ]] && { printf '0'; return; }

    local delta=$((current - prev))
    [[ "$delta" -lt 0 ]] && delta=0

    # Per-second rate
    local rate
    rate=$(awk -v d="$delta" -v i="$interval" 'BEGIN { printf "%.0f", d / i }')
    printf '%s' "$rate"
}

# Format bytes to human readable
_format_bytes() {
    local bytes="$1"

    if [[ "$bytes" -ge "$POWERKIT_BYTE_GB" ]]; then
        awk -v b="$bytes" -v GB="$POWERKIT_BYTE_GB" 'BEGIN { printf "%.1fG/s", b / GB }'
    elif [[ "$bytes" -ge "$POWERKIT_BYTE_MB" ]]; then
        awk -v b="$bytes" -v MB="$POWERKIT_BYTE_MB" 'BEGIN { printf "%.1fM/s", b / MB }'
    elif [[ "$bytes" -ge "$POWERKIT_BYTE_KB" ]]; then
        awk -v b="$bytes" -v KB="$POWERKIT_BYTE_KB" 'BEGIN { printf "%.0fK/s", b / KB }'
    else
        printf '%dB/s' "$bytes"
    fi
}

# Format IOPS
_format_iops() {
    local iops="$1"

    if [[ "$iops" -ge 1000 ]]; then
        awk -v i="$iops" 'BEGIN { printf "%.1fk", i / 1000 }'
    else
        printf '%d' "$iops"
    fi
}

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="${1:-}"
    local show="1" accent="" accent_icon="" icon=""

    local separator show_when_idle
    separator=$(get_option "separator")
    show_when_idle=$(get_option "show_when_idle")

    # Check if we should hide when idle (content is passed lowercase by render_plugins.sh)
    if [[ -z "$content" || "$content" == "r:0b/s${separator}w:0b/s" || "$content" == "r:0${separator}w:0" ]]; then
        if [[ "$show_when_idle" != "true" ]]; then
            build_display_info "0" "" "" ""
            return
        fi
    fi

    icon=$(get_option "icon")
    accent=$(get_option "accent_color")
    accent_icon=$(get_option "accent_color_icon")

    # Extract max value for threshold comparison
    # Format: "R:150.0M/s W:120.5M/s" or "R:150.0G/s" or "R:500K/s"
    # Note: content is passed lowercase by render_plugins.sh, so match [gkmb]
    local max_value=0
    local value unit multiplier

    # Extract all numeric values with units (m/s, g/s, k/s, b/s) - lowercase!
    while [[ "$content" =~ ([0-9]+\.?[0-9]*)([gkmb])/s ]]; do
        value="${BASH_REMATCH[1]}"
        unit="${BASH_REMATCH[2]}"

        # Convert to MB/s for threshold comparison (lowercase units)
        case "$unit" in
            g) multiplier=1024 ;;
            m) multiplier=1 ;;
            k) multiplier=0.001 ;;
            b) multiplier=0.000001 ;;
        esac

        local converted
        converted=$(awk -v v="$value" -v m="$multiplier" 'BEGIN { printf "%.0f", v * m }')
        [[ "$converted" -gt "$max_value" ]] && max_value="$converted"

        # Remove matched part to find next value
        content="${content#*"${BASH_REMATCH[0]}"}"
    done

    # Apply threshold colors if we have a valid value
    if [[ "$max_value" -gt 0 ]]; then
        local threshold_result
        threshold_result=$(apply_threshold_colors "$max_value" "iops") || true
        if [[ -n "$threshold_result" ]]; then
            IFS=':' read -r accent accent_icon <<< "$threshold_result"
        fi
    fi

    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

_compute_iops() {
    local device format show_rw separator show_when_idle
    device=$(get_option "device")
    format=$(get_option "format")
    show_rw=$(get_option "show_rw")
    separator=$(get_option "separator")
    show_when_idle=$(get_option "show_when_idle")

    local device_val="${device:-$(_detect_device)}"
    [[ -z "$device_val" ]] && return 1

    local current_stats
    if is_linux; then
        current_stats=$(_get_io_linux "$device_val")
    elif is_macos; then
        current_stats=$(_get_io_macos "$device_val")
    else
        return 1
    fi

    [[ -z "$current_stats" ]] && return 1

    local read_ops read_bytes write_ops write_bytes
    IFS='|' read -r read_ops read_bytes write_ops write_bytes <<<"$current_stats"

    # Load previous stats and calculate deltas
    local prev_data=""
    if [[ -f "$IOPS_PREV_FILE" ]]; then
        prev_data=$(cat "$IOPS_PREV_FILE")
    fi

    # Parse previous data: timestamp|read_ops|read_bytes|write_ops|write_bytes
    local prev_ts prev_read_ops prev_read_bytes prev_write_ops prev_write_bytes
    if [[ -n "$prev_data" ]]; then
        IFS='|' read -r prev_ts prev_read_ops prev_read_bytes prev_write_ops prev_write_bytes <<<"$prev_data"
    fi

    local current_ts
    current_ts=$(date +%s)

    # Save current stats for next calculation
    printf '%s|%s|%s|%s|%s' "$current_ts" "$read_ops" "$read_bytes" "$write_ops" "$write_bytes" > "$IOPS_PREV_FILE"

    # Calculate interval
    local interval=1
    [[ -n "$prev_ts" && "$prev_ts" -gt 0 ]] && interval=$((current_ts - prev_ts))
    [[ "$interval" -lt 1 ]] && interval=1

    # Calculate rates
    local read_rate write_rate read_iops write_iops
    read_rate=$(_calculate_delta "$read_bytes" "${prev_read_bytes:-0}" "$interval")
    write_rate=$(_calculate_delta "$write_bytes" "${prev_write_bytes:-0}" "$interval")
    read_iops=$(_calculate_delta "$read_ops" "${prev_read_ops:-0}" "$interval")
    write_iops=$(_calculate_delta "$write_ops" "${prev_write_ops:-0}" "$interval")

    # Format output based on configuration
    local output=""
    case "$format" in
        iops)
            case "$show_rw" in
                read)  output="R:$(_format_iops "$read_iops")" ;;
                write) output="W:$(_format_iops "$write_iops")" ;;
                both|*)
                    output="R:$(_format_iops "$read_iops")${separator}W:$(_format_iops "$write_iops")"
                    ;;
            esac
            ;;
        throughput|*)
            case "$show_rw" in
                read)  output="R:$(_format_bytes "$read_rate")" ;;
                write) output="W:$(_format_bytes "$write_rate")" ;;
                both|*)
                    output="R:$(_format_bytes "$read_rate")${separator}W:$(_format_bytes "$write_rate")"
                    ;;
            esac
            ;;
    esac

    # If show_when_idle is false, return error on zero activity (hides plugin)
    # If show_when_idle is true, always return output
    if [[ -z "$output" ]]; then
        return 1
    fi

    # Check for zero activity patterns
    local is_idle=false
    case "$format" in
        iops)
            [[ "$output" == "R:0${separator}W:0" || "$output" == "R:0" || "$output" == "W:0" ]] && is_idle=true
            ;;
        throughput|*)
            [[ "$output" == "R:0B/s${separator}W:0B/s" || "$output" == "R:0B/s" || "$output" == "W:0B/s" ]] && is_idle=true
            ;;
    esac

    if [[ "$is_idle" == "true" && "$show_when_idle" != "true" ]]; then
        return 1
    fi

    printf '%s' "$output"
}

load_plugin() {
    cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_iops
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
