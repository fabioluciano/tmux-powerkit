#!/usr/bin/env bash
# =============================================================================
# PowerKit Renderer: Color Resolver
# Description: Resolves state/health to actual colors from theme
# =============================================================================
#
# This module is responsible for mapping plugin state/health to actual colors.
# It supports visual indication of stale data through color variants.
#
# KEY FUNCTIONS:
#   resolve_color()             - Resolve color name to hex value
#   resolve_plugin_colors_full()- Resolve plugin colors (supports stale indicator)
#   resolve_session_colors()    - Resolve session colors by mode
#   resolve_window_colors()     - Resolve window colors by state
#   resolve_background()        - Resolve status bar background
#
# STALE INDICATOR:
#   When stale=1, applies @powerkit_stale_color_variant (default: -darker) to
#   background colors, providing visual feedback that cached data is displayed.
#
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "renderer_color_resolver" && return 0

. "${POWERKIT_ROOT}/src/core/logger.sh"
. "${POWERKIT_ROOT}/src/core/options.sh"
. "${POWERKIT_ROOT}/src/core/color_palette.sh"
. "${POWERKIT_ROOT}/src/core/theme_loader.sh"

# =============================================================================
# Color Resolution
# =============================================================================

# Resolve a color name to hex value
# Usage: resolve_color "secondary"
resolve_color() {
    local name="$1"

    # Handle special values
    case "$name" in
        "NONE"|"none"|"default"|"")
            printf 'default'
            return
            ;;
    esac

    # Ensure theme is loaded
    is_theme_loaded || load_powerkit_theme

    # Try to get from theme
    local color
    color=$(get_color "$name")

    if [[ -n "$color" ]]; then
        printf '%s' "$color"
    else
        # Fallback to the name itself (might be a raw hex)
        if [[ "$name" =~ ^#[0-9a-fA-F]{6}$ ]]; then
            printf '%s' "$name"
        else
            log_warn "color_resolver" "Unknown color: $name, using default"
            printf 'default'
        fi
    fi
}

# =============================================================================
# Plugin Color Resolution
# =============================================================================

# Resolve colors for a plugin based on state, health, and stale status
# Usage: resolve_plugin_colors_full "state" "health" "context" "stale"
# Returns: "content_bg content_fg icon_bg icon_fg" (space-separated)
#
# NOTE: Context is passed but NOT used for color decisions.
# Per plugin contract, the plugin is responsible for setting its own health
# based on any context (e.g., charging). The renderer only uses state and health.
#
# Stale indicator: When stale=1, applies @powerkit_stale_color_variant (default: -darker)
# to all colors, providing visual feedback that data is cached/outdated.
resolve_plugin_colors_full() {
    local state="$1"
    local health="$2"
    # shellcheck disable=SC2034 # Kept for API compatibility
    local context="$3"
    local stale="${4:-0}"

    local content_bg content_fg icon_bg icon_fg

    # When stale, we need to apply -darker variant to background colors
    # We do this by getting the color NAME, applying variant, then resolving to hex
    if [[ "$stale" == "1" ]]; then
        local variant
        variant=$(get_tmux_option "@powerkit_stale_color_variant" "${POWERKIT_DEFAULT_STALE_COLOR_VARIANT:--darker}")
        local base_color="${_HEALTH_COLORS[$health]:-ok-base}"

        # Apply stale variant to background colors
        # content_bg: base-color → base-color-darker
        # icon_bg: base-color-lighter → base-color-darker (not lighter-darker)
        local content_bg_name="${base_color}${variant}"
        local icon_bg_name="${base_color}${variant}"

        # Resolve to hex
        content_bg=$(get_color "$content_bg_name")
        icon_bg=$(get_color "$icon_bg_name")

        # Foreground colors stay the same for readability
        case "$health" in
            ok)
                content_fg=$(get_color "white")
                icon_fg=$(get_color "white")
                ;;
            *)
                content_fg=$(get_color "${base_color}-darkest")
                icon_fg=$(get_color "${base_color}-darkest")
                ;;
        esac

        # Handle inactive/failed states
        case "$state" in
            inactive)
                content_bg=$(get_color "disabled-base${variant}")
                content_fg=$(get_color "white")
                icon_bg=$(get_color "disabled-base${variant}")
                icon_fg=$(get_color "white")
                ;;
            failed)
                content_bg=$(get_color "error-base${variant}")
                content_fg=$(get_color "error-base-darkest")
                icon_bg=$(get_color "error-base${variant}")
                icon_fg=$(get_color "error-base-darkest")
                ;;
        esac
    else
        # Fresh data: use standard color resolution
        read -r content_bg content_fg icon_bg icon_fg <<< "$(get_plugin_colors "$state" "$health")"
    fi

    printf '%s %s %s %s' "$content_bg" "$content_fg" "$icon_bg" "$icon_fg"
}


# =============================================================================
# Session Color Resolution
# =============================================================================

# Resolve session colors based on mode
# Usage: resolve_session_colors "mode"
# Returns: "bg fg" (space-separated)
resolve_session_colors() {
    local mode="$1"

    local bg fg
    bg=$(get_session_mode_color "$mode")
    fg=$(resolve_color "session-fg")

    printf '%s %s' "$bg" "$fg"
}

# =============================================================================
# Window Color Resolution
# =============================================================================

# Resolve window colors based on state
# Uses base color + variants:
#   - Index: bg = -light, fg = -dark
#   - Content: bg = base, fg = -lightest
# Usage: resolve_window_colors "active|inactive" "has_activity" "has_bell"
# Returns: "index_bg index_fg content_bg content_fg style" (space-separated)
resolve_window_colors() {
    local is_active="$1"
    # shellcheck disable=SC2034 # Reserved for future use
    local has_activity="${2:-0}"
    # shellcheck disable=SC2034 # Reserved for future use
    local has_bell="${3:-0}"

    local index_bg index_fg content_bg content_fg style
    local base_color

    if [[ "$is_active" == "1" || "$is_active" == "active" ]]; then
        base_color="window-active-base"
        style=$(get_window_style "active")
    else
        base_color="window-inactive-base"
        style=$(get_window_style "inactive")
    fi

    # Index segment: -light bg, -dark fg
    index_bg=$(resolve_color "${base_color}-light")
    index_fg=$(resolve_color "${base_color}-dark")

    # Content segment: base bg, -lightest fg
    content_bg=$(resolve_color "$base_color")
    content_fg=$(resolve_color "${base_color}-lightest")

    printf '%s %s %s %s %s' "$index_bg" "$index_fg" "$content_bg" "$content_fg" "$style"
}

# Get window text style
# Usage: get_window_style "active|inactive"
# Returns: style string (bold, dim, italics, none, or empty)
get_window_style() {
    local state="$1"
    local style_key="window-${state}-style"
    local style

    style=$(resolve_color "$style_key" 2>/dev/null)

    # Return empty if "none" or not found
    if [[ -z "$style" || "$style" == "none" || "$style" == "default" ]]; then
        printf ''
    else
        printf '%s' "$style"
    fi
}

# =============================================================================
# Transparent Mode Handling
# =============================================================================

# Check if transparent mode is enabled
is_transparent() {
    local transparent
    transparent=$(get_tmux_option "@powerkit_transparent" "${POWERKIT_DEFAULT_TRANSPARENT}")
    [[ "$transparent" == "true" ]]
}

# Resolve background color considering transparent mode
# Usage: resolve_background
resolve_background() {
    if is_transparent; then
        printf 'default'
    else
        resolve_color "statusbar-bg"
    fi
}

# Alias for backwards compatibility
resolve_status_bg() { resolve_background; }

# =============================================================================
# tmux Style Building
# =============================================================================

# Build tmux style string
# Usage: build_style "fg_color" "bg_color" ["bold"|"dim"|...]
build_style() {
    local fg="$1"
    local bg="$2"
    local attrs="${3:-}"

    local style="fg=$fg,bg=$bg"

    [[ -n "$attrs" ]] && style+=",${attrs}"

    printf '#[%s]' "$style"
}

# Build style with resolved colors
# Usage: build_resolved_style "text" "background"
build_resolved_style() {
    local fg_name="$1"
    local bg_name="$2"
    local attrs="${3:-}"

    local fg bg
    fg=$(resolve_color "$fg_name")
    bg=$(resolve_color "$bg_name")

    build_style "$fg" "$bg" "$attrs"
}

# Reset style to default
# Usage: reset_style
reset_style() {
    printf '#[default]'
}

# =============================================================================
# Color Utilities
# =============================================================================

# Get contrasting text color for a background
# Usage: get_contrast_color "#1a1b26"
# Returns appropriate fg color based on background luminance
get_contrast_color() {
    local bg="$1"

    # Remove # if present
    bg="${bg#\#}"

    # Default to light text (statusbar-fg is light for dark themes)
    local light_text dark_text
    light_text=$(resolve_color "statusbar-fg")
    dark_text=$(resolve_color "session-fg")

    # If not a valid hex, return default light text
    [[ ! "$bg" =~ ^[0-9a-fA-F]{6}$ ]] && { printf '%s' "$light_text"; return; }

    # Calculate luminance (simplified)
    local r=$((16#${bg:0:2}))
    local g=$((16#${bg:2:2}))
    local b=$((16#${bg:4:2}))

    # Perceived luminance formula
    local luminance=$(( (r * 299 + g * 587 + b * 114) / 1000 ))

    if (( luminance > 128 )); then
        # Light background - use dark text
        printf '%s' "$dark_text"
    else
        # Dark background - use light text
        printf '%s' "$light_text"
    fi
}
