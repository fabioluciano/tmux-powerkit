#!/usr/bin/env bash
# =============================================================================
# Plugin: disk
# Description: Display disk usage for one or more mount points
# Type: conditional (can hide when below warning threshold)
# Dependencies: None
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "mounts" "string" "/" "Comma-separated list of mount points (e.g., /,/home,/data)"
    declare_option "format" "string" "percent" "Display format (percent|usage|free)"
    declare_option "separator" "string" " | " "Separator between mount points"
    declare_option "show_label" "bool" "true" "Show mount point label before value"

    # Icons
    declare_option "icon" "icon" $'\U000F02CA' "Plugin icon (nf-mdi-harddisk)"

    # Colors
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Thresholds
    declare_option "threshold_mode" "string" "normal" "Threshold mode (none|normal|inverted)"
    declare_option "warning_threshold" "number" "70" "Warning threshold percentage"
    declare_option "critical_threshold" "number" "90" "Critical threshold percentage"
    declare_option "show_only_warning" "bool" "false" "Only show when usage exceeds warning threshold"

    # Cache
    declare_option "cache_ttl" "number" "120" "Cache duration in seconds"
}

plugin_init "disk"

# =============================================================================
# Main Logic
# =============================================================================

# Resolve mount point to get real disk usage
# On macOS with APFS, "/" is a read-only snapshot and shows misleading values
# The real usage is on /System/Volumes/Data
_resolve_mount() {
    local mount="$1"

    # On macOS, resolve "/" to the actual data volume
    if is_macos && [[ "$mount" == "/" ]]; then
        # Check if /System/Volumes/Data exists (APFS)
        if [[ -d "/System/Volumes/Data" ]]; then
            printf '/System/Volumes/Data'
            return
        fi
    fi

    printf '%s' "$mount"
}

_get_disk_percent() {
    local mount="$1"
    local real_mount
    real_mount=$(_resolve_mount "$mount")

    /bin/df -Pk "$real_mount" 2>/dev/null | awk 'NR==2 { gsub(/%/, "", $5); print $5 }'
}

_get_disk_info() {
    local mount="$1"
    local format="$2"

    # Resolve to real mount point (handles macOS APFS)
    local real_mount
    real_mount=$(_resolve_mount "$mount")

    /bin/df -Pk "$real_mount" 2>/dev/null | awk -v fmt="$format" -v KB="$POWERKIT_BYTE_KB" \
        -v MB="$POWERKIT_BYTE_MB" -v GB="$POWERKIT_BYTE_GB" -v TB="$POWERKIT_BYTE_TB" '
        NR==2 {
            gsub(/%/, "", $5)
            if ($2 > 0 && $5 >= 0) {
                used = $3 * KB; free = $4 * KB; total = $2 * KB
                if (fmt == "usage") printf "%.1f/%.1fG", used/GB, total/GB
                else if (fmt == "free") {
                    if (free >= TB) printf "%.1fT", free/TB
                    else if (free >= GB) printf "%.1fG", free/GB
                    else if (free >= MB) printf "%.0fM", free/MB
                    else printf "%.0fK", free/KB
                }
                else printf "%3d%%", $5
            } else print "N/A"
        }'
}

# Get friendly name for mount point
_get_mount_label() {
    local mount="$1"
    case "$mount" in
        /)                printf 'root' ;;
        /home|/Users/*)   printf 'home' ;;
        /boot|/boot/*)    printf 'boot' ;;
        /tmp)             printf 'tmp' ;;
        /var)             printf 'var' ;;
        /opt)             printf 'opt' ;;
        /srv)             printf 'srv' ;;
        /data)            printf 'data' ;;
        /mnt/*)           printf '%s' "${mount##*/}" ;;
        /media/*)         printf '%s' "${mount##*/}" ;;
        /Volumes/*)       printf '%s' "${mount##*/}" ;;
        *)                printf '%s' "${mount##*/}" ;;
    esac
}

_compute_disk() {
    local mounts format separator show_label
    mounts=$(get_option "mounts")
    format=$(get_option "format")
    separator=$(get_option "separator")
    show_label=$(get_option "show_label")

    [[ -z "$mounts" ]] && return 0

    local output_parts=()
    IFS=',' read -ra mount_list <<< "$mounts"

    for mount in "${mount_list[@]}"; do
        # Trim whitespace
        mount="${mount#"${mount%%[![:space:]]*}"}"
        mount="${mount%"${mount##*[![:space:]]}"}"
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

    [[ ${#output_parts[@]} -eq 0 ]] && return 0
    join_with_separator "$separator" "${output_parts[@]}"
}

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

# Get max usage percentage across all mounts (for threshold detection)
_get_max_usage() {
    local mounts max_pct=0
    mounts=$(get_option "mounts")
    [[ -z "$mounts" ]] && { echo "0"; return; }

    IFS=',' read -ra mount_list <<< "$mounts"
    for mount in "${mount_list[@]}"; do
        mount="${mount#"${mount%%[![:space:]]*}"}"
        mount="${mount%"${mount##*[![:space:]]}"}"
        [[ -z "$mount" ]] && continue

        local pct
        pct=$(_get_disk_percent "$mount")
        [[ -n "$pct" && "$pct" =~ ^[0-9]+$ && "$pct" -gt "$max_pct" ]] && max_pct="$pct"
    done
    echo "$max_pct"
}

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="${1:-}"
    # Get current max usage for threshold detection
    # (can't rely on _DISK_LAST_VALUE because cache may skip _compute_disk)
    local max_pct
    max_pct=$(_get_max_usage)
    threshold_plugin_display_info "$content" "$max_pct"
}

load_plugin() {
    cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_disk
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
