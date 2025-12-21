#!/usr/bin/env bash
# =============================================================================
# Plugin Common Functions
# =============================================================================
# Shared functions for plugins to reduce code duplication.
# Provides common patterns for state-based colors, visibility, and formatting.
#
# USAGE: Source from plugin after plugin_bootstrap.sh:
#   . "$ROOT_DIR/../plugin_common.sh"
#
# FUNCTIONS PROVIDED:
#   - get_state_colors()     - Get colors based on plugin state
#   - compute_threshold_state() - Compute warning/critical/normal state
#   - should_hide_plugin()   - Check if plugin should be hidden
#   - format_percentage()    - Format value as percentage
#   - format_bytes()         - Format bytes with unit (KB/MB/GB)
#   - format_duration()      - Format seconds as human-readable duration
#
# DEPENDENCIES: plugin_helpers.sh (automatically available via plugin_bootstrap)
# =============================================================================

# Source guard
_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=src/source_guard.sh
. "$_COMMON_DIR/source_guard.sh"
source_guard "plugin_common" && return 0

# =============================================================================
# State-Based Color Functions
# =============================================================================

# Get colors for a specific state (DRY - used by many plugins)
# Usage: get_state_colors <plugin_name> <state>
# States: normal, warning, critical, success, error, info, active, inactive
# Returns: accent:accent_icon
#
# Example:
#   IFS=':' read -r accent accent_icon <<< "$(get_state_colors "battery" "warning")"
get_state_colors() {
    local plugin_name="$1"
    local state="$2"

    local plugin_upper="${plugin_name^^}"
    plugin_upper="${plugin_upper//-/_}"

    local accent="" accent_icon=""

    case "$state" in
        warning)
            local warn_var="POWERKIT_PLUGIN_${plugin_upper}_WARNING_ACCENT_COLOR"
            local warn_icon_var="POWERKIT_PLUGIN_${plugin_upper}_WARNING_ACCENT_COLOR_ICON"
            accent="${!warn_var:-warning}"
            accent_icon="${!warn_icon_var:-warning-strong}"
            accent=$(get_tmux_option "@powerkit_plugin_${plugin_name}_warning_accent_color" "$accent")
            accent_icon=$(get_tmux_option "@powerkit_plugin_${plugin_name}_warning_accent_color_icon" "$accent_icon")
            ;;
        critical|error)
            local crit_var="POWERKIT_PLUGIN_${plugin_upper}_CRITICAL_ACCENT_COLOR"
            local crit_icon_var="POWERKIT_PLUGIN_${plugin_upper}_CRITICAL_ACCENT_COLOR_ICON"
            accent="${!crit_var:-error}"
            accent_icon="${!crit_icon_var:-error-strong}"
            accent=$(get_tmux_option "@powerkit_plugin_${plugin_name}_critical_accent_color" "$accent")
            accent_icon=$(get_tmux_option "@powerkit_plugin_${plugin_name}_critical_accent_color_icon" "$accent_icon")
            ;;
        success)
            accent="success"
            accent_icon="success-strong"
            ;;
        info)
            accent="info"
            accent_icon="info-strong"
            ;;
        active)
            local active_var="POWERKIT_PLUGIN_${plugin_upper}_ACTIVE_ACCENT_COLOR"
            local active_icon_var="POWERKIT_PLUGIN_${plugin_upper}_ACTIVE_ACCENT_COLOR_ICON"
            accent="${!active_var:-active}"
            accent_icon="${!active_icon_var:-secondary}"
            accent=$(get_tmux_option "@powerkit_plugin_${plugin_name}_active_accent_color" "$accent")
            accent_icon=$(get_tmux_option "@powerkit_plugin_${plugin_name}_active_accent_color_icon" "$accent_icon")
            ;;
        inactive|disabled)
            accent="disabled"
            accent_icon="disabled"
            ;;
        normal|*)
            local norm_var="POWERKIT_PLUGIN_${plugin_upper}_ACCENT_COLOR"
            local norm_icon_var="POWERKIT_PLUGIN_${plugin_upper}_ACCENT_COLOR_ICON"
            accent="${!norm_var:-secondary}"
            accent_icon="${!norm_icon_var:-active}"
            accent=$(get_tmux_option "@powerkit_plugin_${plugin_name}_accent_color" "$accent")
            accent_icon=$(get_tmux_option "@powerkit_plugin_${plugin_name}_accent_color_icon" "$accent_icon")
            ;;
    esac

    printf '%s:%s' "$accent" "$accent_icon"
}

# Compute threshold state based on value (DRY)
# Usage: compute_threshold_state <value> <plugin_name> [invert]
# Returns: normal, warning, or critical
#
# Example:
#   state=$(compute_threshold_state "85" "cpu")
#   [[ "$state" == "critical" ]] && echo "High CPU!"
compute_threshold_state() {
    local value="$1"
    local plugin_name="$2"
    local invert="${3:-0}"

    [[ -z "$value" || ! "$value" =~ ^[0-9]+$ ]] && { printf 'normal'; return; }

    local plugin_upper="${plugin_name^^}"
    plugin_upper="${plugin_upper//-/_}"

    # Get thresholds
    local warn_var="POWERKIT_PLUGIN_${plugin_upper}_WARNING_THRESHOLD"
    local crit_var="POWERKIT_PLUGIN_${plugin_upper}_CRITICAL_THRESHOLD"
    local warn_t="${!warn_var:-70}"
    local crit_t="${!crit_var:-90}"

    warn_t=$(get_tmux_option "@powerkit_plugin_${plugin_name}_warning_threshold" "$warn_t")
    crit_t=$(get_tmux_option "@powerkit_plugin_${plugin_name}_critical_threshold" "$crit_t")

    if [[ "$invert" == "1" ]]; then
        # Lower is worse (e.g., battery)
        if [[ "$value" -le "$crit_t" ]]; then
            printf 'critical'
        elif [[ "$value" -le "$warn_t" ]]; then
            printf 'warning'
        else
            printf 'normal'
        fi
    else
        # Higher is worse (e.g., CPU, memory)
        if [[ "$value" -ge "$crit_t" ]]; then
            printf 'critical'
        elif [[ "$value" -ge "$warn_t" ]]; then
            printf 'warning'
        else
            printf 'normal'
        fi
    fi
}

# =============================================================================
# Visibility Functions
# =============================================================================

# Check if plugin should be hidden based on content
# Usage: should_hide_plugin <content> [hide_values...]
# Returns: 0 if should hide, 1 if should show
#
# Example:
#   if should_hide_plugin "$content" "" "N/A" "0"; then
#       return  # Hide plugin
#   fi
should_hide_plugin() {
    local content="$1"
    shift
    local hide_values=("$@")

    # Default hide values
    [[ ${#hide_values[@]} -eq 0 ]] && hide_values=("" "N/A")

    for hide_val in "${hide_values[@]}"; do
        [[ "$content" == "$hide_val" ]] && return 0
    done

    return 1
}

# =============================================================================
# Formatting Functions
# =============================================================================

# Format value as percentage
# Usage: format_percentage <value> [width]
# Returns: formatted percentage string (e.g., " 42%", "100%")
format_percentage() {
    local value="$1"
    local width="${2:-3}"

    printf "%${width}d%%" "$value"
}

# Format bytes with appropriate unit
# Usage: format_bytes <bytes> [precision]
# Returns: formatted string (e.g., "1.5G", "256M", "64K")
format_bytes() {
    local bytes="$1"
    local precision="${2:-1}"

    if [[ $bytes -ge $POWERKIT_BYTE_TB ]]; then
        printf "%.${precision}fT" "$(echo "scale=$precision; $bytes / $POWERKIT_BYTE_TB" | bc)"
    elif [[ $bytes -ge $POWERKIT_BYTE_GB ]]; then
        printf "%.${precision}fG" "$(echo "scale=$precision; $bytes / $POWERKIT_BYTE_GB" | bc)"
    elif [[ $bytes -ge $POWERKIT_BYTE_MB ]]; then
        printf "%.${precision}fM" "$(echo "scale=$precision; $bytes / $POWERKIT_BYTE_MB" | bc)"
    elif [[ $bytes -ge $POWERKIT_BYTE_KB ]]; then
        printf "%.${precision}fK" "$(echo "scale=$precision; $bytes / $POWERKIT_BYTE_KB" | bc)"
    else
        printf "%dB" "$bytes"
    fi
}

# Format seconds as human-readable duration
# Usage: format_duration <seconds> [style]
# Styles: short (1d 2h), long (1 day, 2 hours), minimal (1d)
# Returns: formatted duration string
format_duration() {
    local seconds="$1"
    local style="${2:-short}"

    local days=$((seconds / 86400))
    local hours=$(((seconds % 86400) / 3600))
    local mins=$(((seconds % 3600) / 60))

    case "$style" in
        minimal)
            if [[ $days -gt 0 ]]; then
                printf '%dd' "$days"
            elif [[ $hours -gt 0 ]]; then
                printf '%dh' "$hours"
            else
                printf '%dm' "$mins"
            fi
            ;;
        long)
            local parts=()
            [[ $days -gt 0 ]] && parts+=("$days day$([ $days -ne 1 ] && echo s)")
            [[ $hours -gt 0 ]] && parts+=("$hours hour$([ $hours -ne 1 ] && echo s)")
            [[ $mins -gt 0 && $days -eq 0 ]] && parts+=("$mins min$([ $mins -ne 1 ] && echo s)")
            join_with_separator ", " "${parts[@]}"
            ;;
        short|*)
            local parts=()
            [[ $days -gt 0 ]] && parts+=("${days}d")
            [[ $hours -gt 0 ]] && parts+=("${hours}h")
            [[ $mins -gt 0 && $days -eq 0 ]] && parts+=("${mins}m")
            join_with_separator " " "${parts[@]}"
            ;;
    esac
}

# =============================================================================
# Number Formatting (DRY - used by github, gitlab, bitbucket)
# =============================================================================

# Format large numbers with K/M suffix
# Usage: format_number <number>
# Returns: formatted string (e.g., "1.2k", "3.5M", "42")
format_number() {
    local num="$1"
    [[ -z "$num" || ! "$num" =~ ^[0-9]+$ ]] && { printf '%s' "$num"; return; }

    if [[ $num -ge 1000000 ]]; then
        printf '%.1fM' "$(echo "scale=1; $num / 1000000" | bc)"
    elif [[ $num -ge 1000 ]]; then
        printf '%.1fk' "$(echo "scale=1; $num / 1000" | bc)"
    else
        printf '%d' "$num"
    fi
}
