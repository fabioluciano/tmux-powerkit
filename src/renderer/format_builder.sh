#!/usr/bin/env bash
# =============================================================================
# PowerKit Renderer: Format Builder
# Description: Builds tmux format strings for status bar with proper transitions
# =============================================================================
# This module creates tmux format strings that handle:
# - Session segment (status-left) with mode-aware colors
# - Window formats with proper separator transitions
# - Plugin segments (status-right) with left-facing separators
# - Spacing between elements when enabled
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "renderer_format_builder" && return 0

. "${POWERKIT_ROOT}/src/core/defaults.sh"
. "${POWERKIT_ROOT}/src/core/logger.sh"
. "${POWERKIT_ROOT}/src/core/options.sh"
. "${POWERKIT_ROOT}/src/renderer/color_resolver.sh"
. "${POWERKIT_ROOT}/src/renderer/separator.sh"
. "${POWERKIT_ROOT}/src/renderer/icon_resolver.sh"
. "${POWERKIT_ROOT}/src/contract/session_contract.sh"
. "${POWERKIT_ROOT}/src/contract/window_contract.sh"

# =============================================================================
# Status Left Format (Session Segment)
# =============================================================================

# Build status-left format string
# Usage: build_status_left_format
build_status_left_format() {
    local sep_right
    sep_right=$(get_right_separator)

    # Get session icons for different modes
    local session_icon_normal session_icon_prefix session_icon_copy
    session_icon_normal=$(resolve_session_icon)
    session_icon_prefix=$(get_tmux_option "@powerkit_session_prefix_icon" "${POWERKIT_DEFAULT_SESSION_PREFIX_ICON}")
    session_icon_copy=$(get_tmux_option "@powerkit_session_copy_icon" "${POWERKIT_DEFAULT_SESSION_COPY_ICON}")

    # Build conditional icon: prefix -> prefix_icon, copy_mode -> copy_icon, else -> normal_icon
    local icon_condition="#{?client_prefix,${session_icon_prefix},#{?pane_in_mode,${session_icon_copy},${session_icon_normal}}}"

    # Text color (use session-fg for session segment)
    local text_color
    text_color=$(resolve_color "session-fg")

    # Get colors for different session modes
    local prefix_color_name copy_color_name normal_color_name
    prefix_color_name=$(get_tmux_option "@powerkit_session_prefix_color" "${POWERKIT_DEFAULT_SESSION_PREFIX_COLOR}")
    copy_color_name=$(get_tmux_option "@powerkit_session_copy_mode_color" "${POWERKIT_DEFAULT_SESSION_COPY_MODE_COLOR}")
    normal_color_name=$(get_tmux_option "@powerkit_session_normal_color" "${POWERKIT_DEFAULT_SESSION_NORMAL_COLOR}")

    local prefix_bg copy_bg normal_bg
    prefix_bg=$(resolve_color "$prefix_color_name")
    copy_bg=$(resolve_color "$copy_color_name")
    normal_bg=$(resolve_color "$normal_color_name")

    # Build conditional background: prefix -> warning, copy_mode -> info, else -> primary
    local bg_condition="#{?client_prefix,${prefix_bg},#{?pane_in_mode,${copy_bg},${normal_bg}}}"

    # Get spacing/transparency settings
    local transparent spacing_bg
    transparent=$(get_tmux_option "@powerkit_transparent" "${POWERKIT_DEFAULT_TRANSPARENT}")
    if [[ "$transparent" == "true" ]]; then
        spacing_bg="default"
    else
        spacing_bg=$(resolve_color "statusbar-bg")
    fi

    # Get first window's index background color (active or inactive depending on which is first)
    # This is used for the session-to-window separator
    # Colors are derived from base: window-{state}-base-light for index bg
    local active_index_bg inactive_index_bg
    active_index_bg=$(resolve_color "window-active-base-light")
    inactive_index_bg=$(resolve_color "window-inactive-base-light")

    # First window's bg: if window 1 is active, use active color; else use inactive color
    local first_window_bg="#{?#{==:#{active_window_index},1},${active_index_bg},${inactive_index_bg}}"

    # Build session segment with conditional icon
    local format=""
    format+="#[fg=${text_color},bold,bg=${bg_condition}] ${icon_condition} #S "

    # Check if spacing is enabled
    if has_window_spacing; then
        # Spacing enabled: add separator + gap
        format+="#[fg=${bg_condition},bg=${spacing_bg}]${sep_right}#[bg=${spacing_bg}]"
    else
        # No spacing: add separator to first window
        # IMPORTANT: This separator is rendered in status-left context,
        # so pane_in_mode refers to the ACTIVE pane, not per-window pane.
        # This ensures correct session-to-window color transition when in copy mode.
        format+="#[fg=${bg_condition},bg=${first_window_bg}]${sep_right}"
    fi

    printf '%s' "$format"
}

# =============================================================================
# Window Format Functions
# =============================================================================

# Get final separator character
# Uses @powerkit_edge_separator_style option (defaults to main style)
_get_final_separator_char() {
    get_final_separator
}

# Get window colors using base + variants system
# Usage: _get_window_colors "active|inactive"
# Returns: "index_bg index_fg content_bg content_fg style"
# Colors derived from:
#   - Index: bg = -light, fg = -dark
#   - Content: bg = base, fg = -lightest
_get_window_colors() {
    local state="$1"

    local index_bg index_fg content_bg content_fg style
    local base_color

    if [[ "$state" == "active" ]]; then
        base_color="window-active-base"
        # Active window: use lightest variant for text
        index_bg=$(resolve_color "${base_color}-light")
        index_fg=$(resolve_color "${base_color}-darkest")
        content_bg=$(resolve_color "$base_color")
        content_fg=$(resolve_color "${base_color}-darkest")
    else
        base_color="window-inactive-base"
        # Inactive window: always use white text for readability
        index_bg=$(resolve_color "${base_color}-light")
        index_fg=$(resolve_color "white")
        content_bg=$(resolve_color "$base_color")
        content_fg=$(resolve_color "white")
    fi

    style=$(get_window_style "$state")

    printf '%s %s %s %s %s' "$index_bg" "$index_fg" "$content_bg" "$content_fg" "$style"
}

# Build window format (inactive windows)
# Usage: build_window_format
build_window_format() {
    local index_bg index_fg content_bg content_fg style
    read -r index_bg index_fg content_bg content_fg style <<< "$(_get_window_colors "inactive")"

    # Build style attribute string (empty if none)
    local style_attr=""
    [[ -n "$style" && "$style" != "none" ]] && style_attr=",${style}"

    # Get active window content bg for transitions (derived from base)
    local active_content_bg
    active_content_bg=$(resolve_color "window-active-base")

    # Get spacing/status bar background
    local transparent spacing_bg status_bg
    transparent=$(get_tmux_option "@powerkit_transparent" "${POWERKIT_DEFAULT_TRANSPARENT}")
    if [[ "$transparent" == "true" ]]; then
        spacing_bg="default"
        status_bg="default"
    else
        spacing_bg=$(resolve_color "statusbar-bg")
        status_bg=$(resolve_color "statusbar-bg")
    fi

    # Get separators
    local sep_right final_sep
    sep_right=$(get_right_separator)
    final_sep=$(_get_final_separator_char)

    # Calculate previous window background for window-to-window transitions
    # NOTE: First window (index 1) separator is handled by status-left, not here
    # For other windows, previous can be: active window content or inactive window content
    local previous_bg
    # If previous window is active, use active_content_bg; else use inactive (this window's) content_bg
    previous_bg="#{?#{==:#{e|-:#{window_index},1},#{active_window_index}},${active_content_bg},${content_bg}}"

    # Window icon and title
    local window_icon window_title zoomed_icon
    window_icon=$(get_tmux_option "@powerkit_inactive_window_icon" "${POWERKIT_DEFAULT_INACTIVE_WINDOW_ICON}")
    window_title=$(get_tmux_option "@powerkit_inactive_window_title" "${POWERKIT_DEFAULT_INACTIVE_WINDOW_TITLE}")
    zoomed_icon=$(get_tmux_option "@powerkit_zoomed_window_icon" "${POWERKIT_DEFAULT_ZOOMED_WINDOW_ICON}")

    # Build format
    local format=""

    # Window-to-window separator: only for windows after the first one
    # First window's separator is in status-left (session segment)
    # #{?#{!=:#{window_index},1},separator,}
    if has_window_spacing; then
        # Spacing mode: separator from gap to window
        # For sep_right (▶): fg=source color (previous/spacing), bg=destination (window)
        # When transparent, 'default' as fg renders WHITE - use theme background color instead
        local sep_fg="$spacing_bg"
        if [[ "$transparent" == "true" ]]; then
            sep_fg=$(resolve_color "background")
        fi
        format+="#[fg=${sep_fg},bg=${index_bg}]${sep_right}"
    else
        # No spacing: add separator only if NOT first window (index != 1)
        format+="#{?#{!=:#{window_index},1},#[fg=${previous_bg}#,bg=${index_bg}]${sep_right},}"
    fi

    # Index segment (uses index_fg for text)
    format+="#[fg=${index_fg},bg=${index_bg}${style_attr}] #I "

    # Index-to-content separator: fg=index, bg=content
    format+="#[fg=${index_bg},bg=${content_bg}]${sep_right}"

    # Content segment (uses content_fg for text - lighter on inactive)
    format+="#[fg=${content_fg},bg=${content_bg}${style_attr}] #{?window_zoomed_flag,${zoomed_icon},${window_icon}} ${window_title} "

    # Add spacing OR final separator based on window position
    if has_window_spacing; then
        # Spacing mode: each window adds its own separator + spacing
        format+="#[fg=${content_bg},bg=${spacing_bg}]${sep_right}#[bg=${spacing_bg}]"
    else
        # No spacing: add final separator only if this is the last window
        # #{?window_end_flag,final_separator,}
        format+="#{?window_end_flag,#[fg=${content_bg}]#[bg=${status_bg}]${final_sep},}"
    fi

    printf '%s' "$format"
}

# Build window-status-current-format (active window)
# Usage: build_window_current_format
build_window_current_format() {
    local index_bg index_fg content_bg content_fg style
    read -r index_bg index_fg content_bg content_fg style <<< "$(_get_window_colors "active")"

    # Build style attribute string (default to bold if no style set)
    local style_attr=""
    if [[ -n "$style" && "$style" != "none" ]]; then
        style_attr=",${style}"
    else
        style_attr=",bold"  # Default to bold for active window
    fi

    # Get inactive window content bg for transitions (derived from base)
    local inactive_content_bg
    inactive_content_bg=$(resolve_color "window-inactive-base")

    # Get spacing/status bar background
    local transparent spacing_bg status_bg
    transparent=$(get_tmux_option "@powerkit_transparent" "${POWERKIT_DEFAULT_TRANSPARENT}")
    if [[ "$transparent" == "true" ]]; then
        spacing_bg="default"
        status_bg="default"
    else
        spacing_bg=$(resolve_color "statusbar-bg")
        status_bg=$(resolve_color "statusbar-bg")
    fi

    # Get separators
    local sep_right final_sep
    sep_right=$(get_right_separator)
    final_sep=$(_get_final_separator_char)

    # Calculate previous window background for window-to-window transitions
    # NOTE: First window (index 1) separator is handled by status-left, not here
    # For other windows, previous is always inactive content (since this is the active window,
    # the previous one must be inactive)
    local previous_bg="${inactive_content_bg}"

    # Window icon and title
    local window_icon window_title zoomed_icon pane_sync_icon
    window_icon=$(get_tmux_option "@powerkit_active_window_icon" "${POWERKIT_DEFAULT_ACTIVE_WINDOW_ICON}")
    window_title=$(get_tmux_option "@powerkit_active_window_title" "${POWERKIT_DEFAULT_ACTIVE_WINDOW_TITLE}")
    zoomed_icon=$(get_tmux_option "@powerkit_zoomed_window_icon" "${POWERKIT_DEFAULT_ZOOMED_WINDOW_ICON}")
    pane_sync_icon=$(get_tmux_option "@powerkit_pane_synchronized_icon" "${POWERKIT_DEFAULT_PANE_SYNCHRONIZED_ICON}")

    # Build format
    local format=""

    # Window-to-window separator: only for windows after the first one
    # First window's separator is in status-left (session segment)
    if has_window_spacing; then
        # Spacing mode: separator from gap to window
        # For sep_right (▶): fg=source color (previous/spacing), bg=destination (window)
        # When transparent, 'default' as fg renders WHITE - use theme background color instead
        local sep_fg="$spacing_bg"
        if [[ "$transparent" == "true" ]]; then
            sep_fg=$(resolve_color "background")
        fi
        format+="#[fg=${sep_fg},bg=${index_bg}]${sep_right}"
    else
        # No spacing: add separator only if NOT first window (index != 1)
        format+="#{?#{!=:#{window_index},1},#[fg=${previous_bg}#,bg=${index_bg}]${sep_right},}"
    fi

    # Index segment (uses index_fg for text)
    format+="#[fg=${index_fg},bg=${index_bg}${style_attr}] #I "

    # Index-to-content separator: fg=index, bg=content
    format+="#[fg=${index_bg},bg=${content_bg}]${sep_right}"

    # Content segment (uses content_fg for text, with sync indicator)
    format+="#[fg=${content_fg},bg=${content_bg}${style_attr}] #{?window_zoomed_flag,${zoomed_icon},${window_icon}} ${window_title} #{?pane_synchronized,${pane_sync_icon},}"

    # Add spacing OR final separator based on window position
    if has_window_spacing; then
        # Spacing mode: each window adds its own separator + spacing
        format+="#[fg=${content_bg},bg=${spacing_bg}]${sep_right}#[bg=${spacing_bg}]"
    else
        # No spacing: add final separator only if this is the last window
        # #{?window_end_flag,final_separator,}
        format+="#{?window_end_flag,#[fg=${content_bg}]#[bg=${status_bg}]${final_sep},}"
    fi

    printf '%s' "$format"
}

# Build window separator format
# Usage: build_window_separator_format
build_window_separator_format() {
    # Window separator is empty - transitions are handled in window formats
    printf ''
}

# Build final separator (end of window list)
# Usage: build_final_window_separator
build_final_window_separator() {
    # Get status bar background
    local transparent status_bg
    transparent=$(get_tmux_option "@powerkit_transparent" "${POWERKIT_DEFAULT_TRANSPARENT}")
    if [[ "$transparent" == "true" ]]; then
        status_bg="default"
    else
        status_bg=$(resolve_color "statusbar-bg")
    fi

    # Get active and inactive content backgrounds (derived from base colors)
    local active_content_bg inactive_content_bg
    active_content_bg=$(resolve_color "window-active-base")
    inactive_content_bg=$(resolve_color "window-inactive-base")

    create_final_separator "$status_bg" "$active_content_bg" "$inactive_content_bg"
}

# =============================================================================
# Status Right Format (Plugins)
# =============================================================================

# Build status-right format string for all plugins
# Uses #() to call powerkit-render for fully dynamic plugin rendering
# Usage: build_status_right_format
build_status_right_format() {
    local render_script="${POWERKIT_ROOT}/bin/powerkit-render"

    # Use #() for dynamic rendering - entire status-right is regenerated each interval
    printf '#(%s)' "$render_script"
}

# =============================================================================
# Pane Border Format
# =============================================================================

# Build pane border format
# Usage: build_pane_border_format "active|inactive"
build_pane_border_format() {
    local type="${1:-inactive}"

    local fg_color

    if [[ "$type" == "active" ]]; then
        fg_color=$(resolve_color "${POWERKIT_DEFAULT_ACTIVE_PANE_BORDER_COLOR}")
    else
        fg_color=$(resolve_color "${POWERKIT_DEFAULT_INACTIVE_PANE_BORDER_COLOR}")
    fi

    printf '%s' "$fg_color"
}

# Build pane border style
# Usage: build_pane_border_style "active|inactive"
build_pane_border_style() {
    local type="${1:-inactive}"
    local fg_color

    fg_color=$(build_pane_border_format "$type")

    printf 'fg=%s' "$fg_color"
}

# =============================================================================
# Message Format
# =============================================================================

# Build message style
# Usage: build_message_style
build_message_style() {
    local bg fg

    bg=$(resolve_color "message-bg")
    fg=$(resolve_color "message-fg")

    printf 'fg=%s,bg=%s' "$fg" "$bg"
}

# Build command message style
# Usage: build_message_command_style
build_message_command_style() {
    local bg fg

    bg=$(resolve_color "session-command-bg")
    fg=$(resolve_color "session-fg")

    printf 'fg=%s,bg=%s' "$fg" "$bg"
}

# =============================================================================
# Clock Format
# =============================================================================

# Build clock mode format
# Usage: build_clock_format
build_clock_format() {
    local color
    color=$(resolve_color "#c0caf5")

    printf '%s' "$color"
}

# =============================================================================
# Status Bar Style
# =============================================================================

# Build status bar style
# Usage: build_status_style
build_status_style() {
    local bg fg

    bg=$(resolve_background)
    fg=$(resolve_color "statusbar-fg")

    printf 'fg=%s,bg=%s' "$fg" "$bg"
}
