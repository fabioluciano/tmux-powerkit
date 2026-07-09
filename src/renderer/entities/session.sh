#!/usr/bin/env bash
# =============================================================================
# PowerKit Entity: Session
# Description: Renders the session indicator segment
# =============================================================================
# This entity renders ONLY the session content (icon + name).
# It does NOT know about windows or plugins - separators between entities
# are handled by the compositor.
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "entity_session" && return 0

. "${POWERKIT_ROOT}/src/core/defaults.sh"
. "${POWERKIT_ROOT}/src/core/options.sh"
. "${POWERKIT_ROOT}/src/renderer/color_resolver.sh"
. "${POWERKIT_ROOT}/src/utils/platform.sh"

# =============================================================================
# Session Icon Resolution
# =============================================================================

# Resolve session icon based on user configuration
# Usage: resolve_session_icon
# Returns: Icon character for session segment
resolve_session_icon() {
    local session_icon
    session_icon=$(get_tmux_option "@powerkit_session_icon" "${POWERKIT_DEFAULT_SESSION_ICON}")

    if [[ "$session_icon" == "auto" ]]; then
        get_os_icon
    else
        printf '%s' "$session_icon"
    fi
}

# =============================================================================
# Private Helper Functions
# =============================================================================

# Build the conditional icon based on session mode
# Returns: tmux format string with conditional icon
_session_build_icon_condition() {
    local icon_normal icon_prefix icon_copy

    icon_normal=$(resolve_session_icon)
    icon_prefix=$(get_tmux_option "@powerkit_session_prefix_icon" "${POWERKIT_DEFAULT_SESSION_PREFIX_ICON}")
    icon_copy=$(get_tmux_option "@powerkit_session_copy_icon" "${POWERKIT_DEFAULT_SESSION_COPY_ICON}")

    # Conditional: prefix mode -> prefix_icon, copy mode -> copy_icon, else -> normal_icon
    printf '#{?client_prefix,%s,#{?pane_in_mode,%s,%s}}' "$icon_prefix" "$icon_copy" "$icon_normal"
}

# Build the conditional background color based on session mode
# Returns: tmux format string with conditional background color
_session_build_bg_condition() {
    local prefix_color_name copy_color_name normal_color_name
    prefix_color_name=$(get_tmux_option "@powerkit_session_prefix_color" "${POWERKIT_DEFAULT_SESSION_PREFIX_COLOR}")
    copy_color_name=$(get_tmux_option "@powerkit_session_copy_mode_color" "${POWERKIT_DEFAULT_SESSION_COPY_MODE_COLOR}")
    normal_color_name=$(get_tmux_option "@powerkit_session_normal_color" "${POWERKIT_DEFAULT_SESSION_NORMAL_COLOR}")

    local prefix_bg copy_bg normal_bg
    prefix_bg=$(resolve_color "$prefix_color_name")
    copy_bg=$(resolve_color "$copy_color_name")
    normal_bg=$(resolve_color "$normal_color_name")

    # Conditional: prefix mode -> prefix_bg, copy mode -> copy_bg, else -> normal_bg
    printf '#{?client_prefix,%s,#{?pane_in_mode,%s,%s}}' "$prefix_bg" "$copy_bg" "$normal_bg"
}

# Build the mode text indicator (copy/prefix/search/command)
# Returns: tmux format string with conditional mode text
_session_build_mode_text() {
    # All modes with proper nesting:
    # prefix > search > copy > command > normal (no text)
    printf '#{?client_prefix,(prefix) ,#{?pane_in_mode,#{?search_present,(search) ,(copy) },#{?command_prompt,(command) ,}}}'
}

# =============================================================================
# Entity Interface (Required)
# =============================================================================

# Render the session content
# Usage: session_render [side]
# Arguments:
#   side - "left" or "right" (determines separator direction for internal elements)
#          Note: Session has no internal separators, so side is ignored
# Returns: Formatted session content (icon + session name)
session_render() {
    # side parameter not used - session has no internal separators
    # local side="${1:-left}"

    local icon_condition bg_condition text_color mode_text show_mode

    icon_condition=$(_session_build_icon_condition)
    bg_condition=$(_session_build_bg_condition)
    text_color=$(resolve_color "session-fg")
    show_mode=$(get_tmux_option "@powerkit_session_show_mode" "${POWERKIT_DEFAULT_SESSION_SHOW_MODE}")

    # Build mode text if enabled
    if [[ "$show_mode" == "true" ]]; then
        mode_text=$(_session_build_mode_text)
        # Session content: bold text with mode text and mode-aware background
        printf '#[fg=%s,bold,bg=%s] %s #S %s' "$text_color" "$bg_condition" "$icon_condition" "$mode_text"
    else
        # Session content: bold text with mode-aware background (no mode display)
        printf '#[fg=%s,bold,bg=%s] %s #S ' "$text_color" "$bg_condition" "$icon_condition"
    fi
}

# Get the background color of the session
# Used by compositor to build separators between entities
# Returns: tmux conditional format string for background color
session_get_bg() {
    _session_build_bg_condition
}

# =============================================================================
# Entity Interface (Optional)
# =============================================================================

# Session has uniform background, so first_bg = last_bg = get_bg
session_get_first_bg() {
    session_get_bg
}

session_get_last_bg() {
    session_get_bg
}

# No additional configuration needed for session
session_configure() {
    : # No-op
}
