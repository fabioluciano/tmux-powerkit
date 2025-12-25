#!/usr/bin/env bash
# =============================================================================
# Plugin: disk
# Description: Display disk usage for one or more mount points
# Type: conditional (can hide when below warning threshold)
# Dependencies: df (built-in)
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active: Disk metrics available
#   - inactive: Unable to read disk metrics
#
# Health:
#   - ok: All mounts below warning threshold
#   - warning: At least one mount at warning level
#   - error: At least one mount at critical level
#
# Context:
#   - normal_usage: All disks normal
#   - high_usage: Warning level reached
#   - critical_usage: Critical level reached
#
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "disk"
    metadata_set "name" "Disk"
    metadata_set "description" "Display disk usage for multiple mount points"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_cmd "df" || return 1
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "mounts" "string" "/" "Comma-separated list of mount points (e.g., /,/home)"
    declare_option "format" "string" "percent" "Display format (percent|usage|free)"
    declare_option "separator" "string" " | " "Separator between mount points"
    declare_option "show_label" "bool" "true" "Show mount point label before value"

    # Icons
    declare_option "icon" "icon" $'\U000F02CA' "Plugin icon (nf-mdi-harddisk)"
    declare_option "icon_warning" "icon" "" "Icon when warning (empty = use default)"
    declare_option "icon_critical" "icon" "" "Icon when critical (empty = use default)"

    # Thresholds
    declare_option "threshold_mode" "string" "normal" "Threshold mode (none|normal|inverted)"
    declare_option "warning_threshold" "number" "70" "Warning threshold percentage"
    declare_option "critical_threshold" "number" "90" "Critical threshold percentage"

    # Note: show_only_on_threshold is auto-injected globally

    # Cache
    declare_option "cache_ttl" "number" "120" "Cache duration in seconds"
}

# =============================================================================
# Mount Point Resolution
# =============================================================================

# Resolve mount point to get real disk usage
# On macOS with APFS, "/" is a read-only snapshot with misleading values
# The real usage is on /System/Volumes/Data
_resolve_mount() {
    local mount="$1"

    if is_macos && [[ "$mount" == "/" ]]; then
        # Check if /System/Volumes/Data exists (APFS)
        if [[ -d "/System/Volumes/Data" ]]; then
            printf '/System/Volumes/Data'
            return
        fi
    fi

    printf '%s' "$mount"
}

# Get friendly label for mount point
_get_mount_label() {
    local mount="$1"

    case "$mount" in
        /)                 printf 'root' ;;
        /home|/Users/*)    printf 'home' ;;
        /boot|/boot/*)     printf 'boot' ;;
        /tmp)              printf 'tmp' ;;
        /var)              printf 'var' ;;
        /opt)              printf 'opt' ;;
        /srv)              printf 'srv' ;;
        /data)             printf 'data' ;;
        /mnt/*)            printf '%s' "${mount##*/}" ;;
        /media/*)          printf '%s' "${mount##*/}" ;;
        /Volumes/*)        printf '%s' "${mount##*/}" ;;
        *)                 printf '%s' "${mount##*/}" ;;
    esac
}

# =============================================================================
# Disk Usage Functions
# =============================================================================

# Get disk percentage used
_get_disk_percent() {
    local mount="$1"
    local real_mount
    real_mount=$(_resolve_mount "$mount")

    /bin/df -Pk "$real_mount" 2>/dev/null | awk 'NR==2 { gsub(/%/, "", $5); print $5 }'
}

# Get disk info in specified format
_get_disk_info() {
    local mount="$1"
    local format="$2"
    local real_mount
    real_mount=$(_resolve_mount "$mount")

    local KB=1024
    local MB=$((1024 * 1024))
    local GB=$((1024 * 1024 * 1024))
    local TB=$((1024 * 1024 * 1024 * 1024))

    /bin/df -Pk "$real_mount" 2>/dev/null | awk -v fmt="$format" \
        -v KB="$KB" -v MB="$MB" -v GB="$GB" -v TB="$TB" '
        NR==2 {
            gsub(/%/, "", $5)
            if ($2 > 0 && $5 >= 0) {
                used = $3 * 1024; free = $4 * 1024; total = $2 * 1024

                if (fmt == "usage") {
                    printf "%.1f/%.1fG", used/GB, total/GB
                } else if (fmt == "free") {
                    if (free >= TB) printf "%.1fT", free/TB
                    else if (free >= GB) printf "%.1fG", free/GB
                    else if (free >= MB) printf "%.0fM", free/MB
                    else printf "%.0fK", free/KB
                } else {
                    printf "%d%%", $5
                }
            } else {
                print "N/A"
            }
        }'
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    local mounts
    mounts=$(get_option "mounts")
    [[ -z "$mounts" ]] && mounts="/"

    local max_pct=0
    local mount_count=0
    local mount_data=""

    IFS=',' read -ra mount_list <<< "$mounts"

    for mount in "${mount_list[@]}"; do
        mount=$(trim "$mount")
        [[ -z "$mount" ]] && continue

        local pct
        pct=$(_get_disk_percent "$mount")
        [[ -z "$pct" || ! "$pct" =~ ^[0-9]+$ ]] && continue

        (( pct > max_pct )) && max_pct=$pct
        ((mount_count++))

        # Store individual mount data (mount:percent)
        [[ -n "$mount_data" ]] && mount_data+="|"
        mount_data+="${mount}:${pct}"
    done

    plugin_data_set "max_percent" "$max_pct"
    plugin_data_set "mount_count" "$mount_count"
    plugin_data_set "mount_data" "$mount_data"
    plugin_data_set "available" "$((mount_count > 0 ? 1 : 0))"
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
    local max_pct mode warn_th crit_th
    max_pct=$(plugin_data_get "max_percent")
    mode=$(get_option "threshold_mode")
    warn_th=$(get_option "warning_threshold")
    crit_th=$(get_option "critical_threshold")

    max_pct="${max_pct:-0}"
    warn_th="${warn_th:-70}"
    crit_th="${crit_th:-90}"

    case "$mode" in
        none)
            printf 'ok'
            ;;
        inverted)
            # Lower is worse (unusual for disk, but supported)
            if (( max_pct <= crit_th )); then
                printf 'error'
            elif (( max_pct <= warn_th )); then
                printf 'warning'
            else
                printf 'ok'
            fi
            ;;
        normal|*)
            # Higher is worse (default for disk)
            if (( max_pct >= crit_th )); then
                printf 'error'
            elif (( max_pct >= warn_th )); then
                printf 'warning'
            else
                printf 'ok'
            fi
            ;;
    esac
}

# =============================================================================
# Plugin Contract: Context
# =============================================================================

plugin_get_context() {
    local health
    health=$(plugin_get_health)

    case "$health" in
        error)   printf 'critical_usage' ;;
        warning) printf 'high_usage' ;;
        *)       printf 'normal_usage' ;;
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
    local mounts format separator show_label
    mounts=$(get_option "mounts")
    format=$(get_option "format")
    separator=$(get_option "separator")
    show_label=$(get_option "show_label")

    [[ -z "$mounts" ]] && mounts="/"

    # Note: show_only_on_threshold is handled by renderer via health

    local output_parts=()
    IFS=',' read -ra mount_list <<< "$mounts"

    for mount in "${mount_list[@]}"; do
        mount=$(trim "$mount")
        [[ -z "$mount" ]] && continue

        local info
        info=$(_get_disk_info "$mount" "$format")
        [[ -z "$info" || "$info" == "N/A" ]] && continue

        if [[ "$show_label" == "true" ]]; then
            local label
            label=$(_get_mount_label "$mount")
            output_parts+=("${label} ${info}")
        else
            output_parts+=("$info")
        fi
    done

    [[ ${#output_parts[@]} -eq 0 ]] && return

    join_with_separator "$separator" "${output_parts[@]}"
}

# =============================================================================
# Initialize Plugin
# =============================================================================

