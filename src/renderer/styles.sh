#!/usr/bin/env bash
# =============================================================================
# PowerKit Renderer: Styles
# Description: Build style strings for various tmux elements
# =============================================================================
# This module handles styles for:
# - Status bar (background/foreground)
# - Pane borders (active/inactive)
# - Messages (command/normal)
# - Clock mode
#
# These are NOT related to the status bar entities (session/windows/plugins)
# and are kept separate for clarity.
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "renderer_styles" && return 0

. "${POWERKIT_ROOT}/src/core/defaults.sh"
. "${POWERKIT_ROOT}/src/core/options.sh"
. "${POWERKIT_ROOT}/src/renderer/color_resolver.sh"

# =============================================================================
# Status Bar Style
# =============================================================================

# Build status bar style
# Usage: build_status_style
# Returns: "fg=COLOR,bg=COLOR"
build_status_style() {
    local bg fg

    bg=$(resolve_background)
    fg=$(resolve_color "statusbar-fg")

    printf 'fg=%s,bg=%s' "$fg" "$bg"
}

# =============================================================================
# Pane Border Styles
# =============================================================================

# Build pane border format (just the color)
# Usage: build_pane_border_format "active|inactive"
# Returns: color value
build_pane_border_format() {
    local type="${1:-inactive}"
    local fg_color

    # Check if unified border color is enabled
    local unified
    unified=$(get_tmux_option '@powerkit_pane_border_unified' "${POWERKIT_DEFAULT_PANE_BORDER_UNIFIED}")

    if [[ "$unified" == "true" ]]; then
        # Use single color for both active and inactive
        fg_color=$(resolve_color "$(get_tmux_option '@powerkit_pane_border_color' "${POWERKIT_DEFAULT_PANE_BORDER_COLOR}")")
    elif [[ "$type" == "active" ]]; then
        fg_color=$(resolve_color "$(get_tmux_option '@powerkit_active_pane_border_color' "${POWERKIT_DEFAULT_ACTIVE_PANE_BORDER_COLOR}")")
    else
        fg_color=$(resolve_color "$(get_tmux_option '@powerkit_inactive_pane_border_color' "${POWERKIT_DEFAULT_INACTIVE_PANE_BORDER_COLOR}")")
    fi

    printf '%s' "$fg_color"
}

# Build pane border style
# Usage: build_pane_border_style "active|inactive"
# Returns: "fg=COLOR"
build_pane_border_style() {
    local type="${1:-inactive}"
    local fg_color

    fg_color=$(build_pane_border_format "$type")

    printf 'fg=%s' "$fg_color"
}

# =============================================================================
# Message Styles
# =============================================================================

# Build message style
# Usage: build_message_style
# Returns: "fg=COLOR,bg=COLOR"
build_message_style() {
    local bg fg

    bg=$(resolve_color "message-bg")
    fg=$(resolve_color "message-fg")

    printf 'fg=%s,bg=%s' "$fg" "$bg"
}

# Build command message style
# Usage: build_message_command_style
# Returns: "fg=COLOR,bg=COLOR"
build_message_command_style() {
    local bg fg

    bg=$(resolve_color "session-command-bg")
    fg=$(resolve_color "session-fg")

    printf 'fg=%s,bg=%s' "$fg" "$bg"
}

# =============================================================================
# Clock Style
# =============================================================================

# Build clock mode format (color)
# Usage: build_clock_format
# Returns: color value
build_clock_format() {
    local color
    color=$(resolve_color "#c0caf5")

    printf '%s' "$color"
}

# =============================================================================
# Copy Mode Style
# =============================================================================

# Build copy mode style
# Usage: build_mode_style
# Returns: "fg=COLOR,bg=COLOR"
build_mode_style() {
    local bg fg

    bg=$(resolve_color "session-copy-bg")
    fg=$(resolve_color "session-fg")

    printf 'fg=%s,bg=%s' "$fg" "$bg"
}

# =============================================================================
# Popup Styles
# =============================================================================

# Build popup style (background and foreground)
# Usage: build_popup_style
# Returns: "fg=COLOR,bg=COLOR"
build_popup_style() {
    local bg fg

    bg=$(resolve_color "popup-bg")
    fg=$(resolve_color "popup-fg")

    printf 'fg=%s,bg=%s' "$fg" "$bg"
}

# Build popup border style
# Usage: build_popup_border_style
# Returns: "fg=COLOR"
build_popup_border_style() {
    local border_color

    border_color=$(resolve_color "popup-border")

    printf 'fg=%s' "$border_color"
}

# =============================================================================
# Menu Styles
# =============================================================================

# Build menu style (background and foreground)
# Usage: build_menu_style
# Returns: "fg=COLOR,bg=COLOR"
build_menu_style() {
    local bg fg

    bg=$(resolve_color "menu-bg")
    fg=$(resolve_color "menu-fg")

    printf 'fg=%s,bg=%s' "$fg" "$bg"
}

# Build menu selected item style
# Usage: build_menu_selected_style
# Returns: "fg=COLOR,bg=COLOR"
build_menu_selected_style() {
    local bg fg

    bg=$(resolve_color "menu-selected-bg")
    fg=$(resolve_color "menu-selected-fg")

    printf 'fg=%s,bg=%s' "$fg" "$bg"
}

# Build menu border style
# Usage: build_menu_border_style
# Returns: "fg=COLOR"
build_menu_border_style() {
    local border_color

    border_color=$(resolve_color "menu-border")

    printf 'fg=%s' "$border_color"
}
