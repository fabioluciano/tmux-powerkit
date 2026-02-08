#!/usr/bin/env bash
# =============================================================================
# PowerKit Core: Color Palette
# Description: Maps plugin state/health to semantic colors
# =============================================================================
# COLOR SYSTEM:
# Base colors are defined in themes (e.g., ok-base, warning-base, window-active-base)
# The color_generator automatically creates variants:
#   - {color}-light:   +10% brightness
#   - {color}-lighter: +20% brightness (used for icon backgrounds)
#   - {color}-dark:    -20% brightness
#   - {color}-darker:  -44.2% brightness (used for text/contrast)
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "color_palette" && return 0

. "${POWERKIT_ROOT}/src/core/logger.sh"
. "${POWERKIT_ROOT}/src/core/color_generator.sh"

# =============================================================================
# State to Color Mapping
# =============================================================================

# Maps plugin state to base color names
# States: inactive, active, degraded, failed
declare -gA _STATE_COLORS=(
    [inactive]="disabled-base"
    [active]="ok-base"
    [degraded]="warning-base"
    [failed]="error-base"
)

# =============================================================================
# Health to Color Mapping
# =============================================================================

# Maps plugin health to base color names
# Health: ok, good, info, warning, error
declare -gA _HEALTH_COLORS=(
    [ok]="ok-base"
    [good]="good-base"
    [info]="info-base"
    [warning]="warning-base"
    [error]="error-base"
)

# =============================================================================
# Session Mode Colors
# =============================================================================

# Maps session mode to colors (semantic names from theme)
# Modes: normal, prefix, copy, command, search
declare -gA _SESSION_MODE_COLORS=(
    [normal]="session-bg"
    [prefix]="session-prefix-bg"
    [copy]="session-copy-bg"
    [command]="window-active-base"
    [search]="session-search-bg"
)

# =============================================================================
# Window State Colors (using base + variants)
# =============================================================================

# Maps window states to base colors
# The system uses:
#   - window-{state}-base: content background
#   - window-{state}-base-lighter: index background
#   - window-{state}-base-darker: text color (contrast)
declare -gA _WINDOW_STATE_COLORS=(
    [active]="window-active-base"
    [inactive]="window-inactive-base"
    [zoomed]="window-zoomed-bg"
)

# =============================================================================
# Message Severity Colors
# =============================================================================

# Maps message severity to colors (using health base colors)
declare -gA _MESSAGE_COLORS=(
    [info]="info-base"
    [success]="good-base"
    [warning]="warning-base"
    [error]="error-base"
)

# =============================================================================
# Contrast Utilities
# =============================================================================

# Determine whether to use light or dark text based on background luminance
# Usage: get_contrast_variant "color-name-or-hex"
# Returns: "darkest" for light backgrounds, "lightest" for dark backgrounds
get_contrast_variant() {
    local color_input="$1"
    local hex

    # If it looks like a hex color, use directly; otherwise resolve the name
    if [[ "$color_input" == \#* ]]; then
        hex="$color_input"
    else
        hex=$(get_color "$color_input")
    fi
    hex="${hex#\#}"

    # Validate hex format (must be 6 hex digits)
    if [[ ! "$hex" =~ ^[0-9a-fA-F]{6}$ ]]; then
        # Cannot determine luminance; assume dark background
        printf 'lightest'
        return
    fi

    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))

    # Perceived luminance (ITU-R BT.601)
    local luminance=$(( (299 * r + 587 * g + 114 * b) / 1000 ))

    if [[ "$luminance" -gt 128 ]]; then
        printf 'darkest'
    else
        printf 'lightest'
    fi
}

# =============================================================================
# Public API
# =============================================================================

# Get color for plugin state
# Usage: get_state_color "active"
get_state_color() {
    local state="$1"
    local color_name="${_STATE_COLORS[$state]:-ok-base}"
    get_color "$color_name"
}

# Get color for plugin health (content background)
# Usage: get_health_color "warning"
get_health_color() {
    local health="$1"
    local color_name="${_HEALTH_COLORS[$health]:-ok-base}"
    get_color "$color_name"
}

# Get icon color for plugin health (uses -lighter variant)
# Usage: get_health_icon_color "warning"
get_health_icon_color() {
    local health="$1"
    local base_color="${_HEALTH_COLORS[$health]:-ok-base}"
    # Use -lighter variant for icon background
    get_color "${base_color}-lighter"
}

# Get text color for plugin health (uses -darker variant for contrast)
# Usage: get_health_text_color "warning"
get_health_text_color() {
    local health="$1"
    local base_color="${_HEALTH_COLORS[$health]:-ok-base}"
    # Use -darker variant for text (better contrast)
    get_color "${base_color}-darker"
}

# Get colors for a plugin based on state and health
# Usage: get_plugin_colors "state" "health"
# Returns: "content_bg content_fg icon_bg icon_fg" (space-separated)
#
# Text color logic:
# - OK: white text (dark background)
# - INFO/WARNING/ERROR/DISABLED: -darkest variant text (better contrast on colored backgrounds)
get_plugin_colors() {
    local state="$1"
    local health="$2"

    local content_bg content_fg icon_bg icon_fg
    local base_color="${_HEALTH_COLORS[$health]:-ok-base}"

    # Content background based on health
    content_bg=$(get_color "$base_color")

    # Icon background (lighter variant)
    icon_bg=$(get_color "${base_color}-lighter")

    # Text color: choose light or dark based on background luminance
    local fg_variant
    fg_variant=$(get_contrast_variant "$content_bg")
    content_fg=$(get_color "${base_color}-${fg_variant}")

    local icon_fg_variant
    icon_fg_variant=$(get_contrast_variant "$icon_bg")
    icon_fg=$(get_color "${base_color}-${icon_fg_variant}")

    # If state is inactive/failed, override all colors
    case "$state" in
        inactive)
            # Disabled: dark background, white text
            content_bg=$(get_color "disabled-base")
            content_fg=$(get_color "white")
            icon_bg=$(get_color "disabled-base-lighter")
            icon_fg=$(get_color "white")
            ;;
        failed)
            content_bg=$(get_color "error-base")
            content_fg=$(get_color "error-base-darkest")
            icon_bg=$(get_color "error-base-lighter")
            icon_fg=$(get_color "error-base-darkest")
            ;;
    esac

    printf '%s %s %s %s' "$content_bg" "$content_fg" "$icon_bg" "$icon_fg"
}

# Get color for session mode
# Usage: get_session_mode_color "prefix"
get_session_mode_color() {
    local mode="$1"
    local color_name="${_SESSION_MODE_COLORS[$mode]:-session-bg}"
    get_color "$color_name"
}

# Get window colors (returns base, lighter for index, darker for text)
# Usage: get_window_colors "active"
# Returns: "content_bg index_bg text_color" (space-separated)
get_window_colors() {
    local state="$1"
    local base_color="${_WINDOW_STATE_COLORS[$state]:-window-inactive-base}"

    local content_bg index_bg text_color
    content_bg=$(get_color "$base_color")
    index_bg=$(get_color "${base_color}-lighter")
    text_color=$(get_color "${base_color}-darker")

    printf '%s %s %s' "$content_bg" "$index_bg" "$text_color"
}

# Get color for window state (backward compatible)
# Usage: get_window_color "active"
get_window_color() {
    local state="$1"
    local color_name="${_WINDOW_STATE_COLORS[$state]:-window-inactive-base}"
    get_color "$color_name"
}

# Get color for message severity
# Usage: get_message_color "error"
get_message_color() {
    local severity="$1"
    local color_name="${_MESSAGE_COLORS[$severity]:-info}"
    get_color "$color_name"
}

# =============================================================================
# Utility
# =============================================================================

# List all color mappings (for debugging)
list_color_mappings() {
    local key

    printf 'State colors:\n'
    for key in "${!_STATE_COLORS[@]}"; do
        printf '  %s -> %s\n' "$key" "${_STATE_COLORS[$key]}"
    done

    printf '\nHealth colors:\n'
    for key in "${!_HEALTH_COLORS[@]}"; do
        printf '  %s -> %s\n' "$key" "${_HEALTH_COLORS[$key]}"
    done

    printf '\nSession mode colors:\n'
    for key in "${!_SESSION_MODE_COLORS[@]}"; do
        printf '  %s -> %s\n' "$key" "${_SESSION_MODE_COLORS[$key]}"
    done

    printf '\nWindow state colors:\n'
    for key in "${!_WINDOW_STATE_COLORS[@]}"; do
        printf '  %s -> %s\n' "$key" "${_WINDOW_STATE_COLORS[$key]}"
    done
}
