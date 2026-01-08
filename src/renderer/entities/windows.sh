#!/usr/bin/env bash
# =============================================================================
# PowerKit Entity: Windows
# Description: Renders the window list and configures window formats
# =============================================================================
# This entity handles:
# - Window list rendering (#{W:...} format)
# - window-status-format configuration
# - window-status-current-format configuration
# - Internal separators (between windows)
#
# External separators (to/from other entities) are handled by the compositor.
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "entity_windows" && return 0

. "${POWERKIT_ROOT}/src/core/defaults.sh"
. "${POWERKIT_ROOT}/src/core/options.sh"
. "${POWERKIT_ROOT}/src/renderer/color_resolver.sh"
. "${POWERKIT_ROOT}/src/renderer/separator.sh"
. "${POWERKIT_ROOT}/src/contract/window_contract.sh"
. "${POWERKIT_ROOT}/src/contract/pane_contract.sh"

# =============================================================================
# Window Icon Resolution
# =============================================================================

# Resolve window icon based on window state
# Usage: resolve_window_icon "active|inactive" "is_zoomed"
# Returns: Icon character for window
resolve_window_icon() {
    local state="$1"
    local is_zoomed="${2:-false}"

    if [[ "$is_zoomed" == "true" || "$is_zoomed" == "1" ]]; then
        get_tmux_option "@powerkit_zoomed_window_icon" "${POWERKIT_DEFAULT_ZOOMED_WINDOW_ICON}"
        return
    fi

    if [[ "$state" == "active" ]]; then
        get_tmux_option "@powerkit_active_window_icon" "${POWERKIT_DEFAULT_ACTIVE_WINDOW_ICON}"
    else
        get_tmux_option "@powerkit_inactive_window_icon" "${POWERKIT_DEFAULT_INACTIVE_WINDOW_ICON}"
    fi
}

# =============================================================================
# Private Helper Functions
# =============================================================================

# Get window colors using base + variants system
# Usage: _windows_get_colors "active|inactive"
# Returns: "index_bg index_fg content_bg content_fg style"
_windows_get_colors() {
    local state="$1"
    local base_color index_bg index_fg content_bg content_fg style

    if [[ "$state" == "active" ]]; then
        base_color="window-active-base"
        index_fg=$(resolve_color "${base_color}-lightest")
        content_fg=$(resolve_color "${base_color}-lightest")
    else
        base_color="window-inactive-base"
        index_fg=$(resolve_color "white")
        content_fg=$(resolve_color "white")
    fi

    index_bg=$(resolve_color "${base_color}-light")
    content_bg=$(resolve_color "$base_color")
    style=$(get_window_style "$state")

    printf '%s %s %s %s %s' "$index_bg" "$index_fg" "$content_bg" "$content_fg" "$style"
}

# Get common window format settings
# Usage: _windows_get_common_settings "side"
# Sets: _W_TRANSPARENT, _W_SPACING_BG, _W_SPACING_FG, _W_STATUS_BG, _W_SEP_CHAR, _W_EDGE_SEP_CHAR, _W_ROUND_ALL_EDGES
# Note: "center" behaves like "left" for separator direction (right-pointing ▶)
_windows_get_common_settings() {
    local side="$1"

    _W_TRANSPARENT=$(get_tmux_option "@powerkit_transparent" "${POWERKIT_DEFAULT_TRANSPARENT}")
    _W_ROUND_ALL_EDGES=$(should_apply_all_edges && echo "true" || echo "false")

    # Always resolve the actual statusbar-bg color for use in fg
    # (because fg=default gives terminal's default TEXT color, not background)
    local resolved_statusbar_bg
    resolved_statusbar_bg=$(resolve_color "statusbar-bg")

    if [[ "$_W_TRANSPARENT" == "true" ]]; then
        _W_SPACING_BG="default"           # bg=default works (terminal background)
        _W_SPACING_FG="$resolved_statusbar_bg"  # fg needs actual color (not "default" which is white)
        _W_STATUS_BG="default"
    else
        _W_SPACING_BG="$resolved_statusbar_bg"
        _W_SPACING_FG="$resolved_statusbar_bg"
        _W_STATUS_BG="$resolved_statusbar_bg"
    fi

    # "center" uses same separator direction as "left" (right-pointing ▶)
    if [[ "$side" == "left" || "$side" == "center" ]]; then
        _W_SEP_CHAR=$(get_right_separator)
        _W_EDGE_SEP_CHAR=$(get_edge_right_separator)
    else
        _W_SEP_CHAR=$(get_left_separator)
        _W_EDGE_SEP_CHAR=$(get_edge_left_separator)
    fi
}

# Build window-to-window separator
# Usage: _windows_build_separator "side" "index_bg" "previous_bg"
# Note: "center" behaves like "left" for separator direction
# Note: Edge separators are handled by the compositor, except for first window with spacing
# Note: When :all suffix is enabled, first window uses edge-style separator
_windows_build_separator() {
    local side="$1" index_bg="$2" previous_bg="$3"

    if has_window_spacing; then
        # With spacing: transition FROM spacing gap TO window
        local spacing_fg transparent_mode
        transparent_mode=$(get_tmux_option "@powerkit_transparent" "${POWERKIT_DEFAULT_TRANSPARENT}")

        if [[ "$transparent_mode" == "true" ]]; then
            spacing_fg=$(resolve_color "background")
        else
            spacing_fg=$(resolve_color "statusbar-bg")
        fi

        # Check for first window - use #{base-index} to support both base-index=0 and base-index=1
        local is_first='#{?#{==:#{window_index},#{base-index}},'
        local not_first='#{?#{!=:#{window_index},#{base-index}},'

        if [[ "$side" == "left" ]]; then
            # Left side ▶: gap → window
            # ▶: fg=gap (left), bg=window (right)
            # When :all suffix is enabled, first window uses edge separator
            if [[ "$_W_ROUND_ALL_EDGES" == "true" ]]; then
                # First window: edge separator, others: normal separator
                printf '%s#[fg=%s#,bg=%s]%s,%s#[fg=%s#,bg=%s]%s,}' \
                    "$is_first" "$spacing_fg" "$index_bg" "$_W_EDGE_SEP_CHAR" \
                    "$not_first" "$spacing_fg" "$index_bg" "$_W_SEP_CHAR"
            else
                printf '#[fg=%s#,bg=%s]%s' "$spacing_fg" "$index_bg" "$_W_SEP_CHAR"
            fi
        elif [[ "$side" == "center" ]]; then
            # Center side ▶: gap → window
            # ▶: fg=gap (left), bg=window (right)
            # Skip first window - compositor handles edge separator
            printf '%s#[fg=%s#,bg=%s]%s,}' "$not_first" "$spacing_fg" "$index_bg" "$_W_SEP_CHAR"
        elif [[ "$side" == "right" ]]; then
            # Right side ◀: gap → window
            # ◀: fg=window (right), bg=gap (left)
            # Skip first window - compositor handles edge separator
            printf '%s#[fg=%s#,bg=%s]%s,}' "$not_first" "$index_bg" "$spacing_fg" "$_W_SEP_CHAR"
        fi
    else
        # For all sides, first window doesn't need edge separator (handled by compositor)
        # Only add inter-window separators (window 2+)
        # Use #{base-index} to support both base-index=0 and base-index=1
        if [[ "$side" == "left" || "$side" == "center" ]]; then
            printf '#{?#{!=:#{window_index},#{base-index}},#[fg=%s#,bg=%s]%s,}' "$previous_bg" "$index_bg" "$_W_SEP_CHAR"
        else
            # Right side: separator points left (◀)
            printf '#{?#{!=:#{window_index},#{base-index}},#[fg=%s#,bg=%s]%s,}' "$index_bg" "$previous_bg" "$_W_SEP_CHAR"
        fi
    fi
}

# Build index-to-content separator
# Usage: _windows_build_index_sep "side" "index_bg" "content_bg"
# Note: "center" behaves like "left" for separator direction
_windows_build_index_sep() {
    local side="$1" index_bg="$2" content_bg="$3"

    if [[ "$side" == "left" || "$side" == "center" ]]; then
        printf '#[fg=%s,bg=%s]%s' "$index_bg" "$content_bg" "$_W_SEP_CHAR"
    else
        printf '#[fg=%s,bg=%s]%s' "$content_bg" "$index_bg" "$_W_SEP_CHAR"
    fi
}

# Build spacing separator (if enabled)
# Usage: _windows_build_spacing "side" "content_bg"
# Note: "center" behaves like "left" for separator direction
# Note: Only handles inter-window exit separators
#       Edge separators are handled by the compositor
_windows_build_spacing() {
    local side="$1" content_bg="$2"

    has_window_spacing || return

    # For fg in powerline glyphs, use the appropriate background color
    # In transparent mode: use theme's "background" (terminal background)
    # In normal mode: use statusbar-bg
    local spacing_fg transparent_mode
    transparent_mode=$(get_tmux_option "@powerkit_transparent" "${POWERKIT_DEFAULT_TRANSPARENT}")

    if [[ "$transparent_mode" == "true" ]]; then
        spacing_fg=$(resolve_color "background")
    else
        spacing_fg=$(resolve_color "statusbar-bg")
    fi

    # Exit separator: window → gap (between windows only)
    # Skip for LAST window (edge separator handled by compositor)
    # Last window index = base-index + session_windows - 1
    local not_last_cond='#{?#{!=:#{window_index},#{e|-:#{e|+:#{base-index},#{session_windows}},1}},'

    if [[ "$side" == "left" || "$side" == "center" ]]; then
        # Left side ▶: window → gap
        # ▶: fg=window (left), bg=gap (right)
        printf '%s#[fg=%s#,bg=%s]%s,}' \
            "$not_last_cond" \
            "$content_bg" "$spacing_fg" "$_W_SEP_CHAR"
    else
        # Right side ◀: window → gap
        # ◀: fg=gap (right), bg=window (left)
        printf '%s#[fg=%s#,bg=%s]%s,}' \
            "$not_last_cond" \
            "$spacing_fg" "$content_bg" "$_W_SEP_CHAR"
    fi
}

# Build window format for inactive windows
# Usage: _windows_build_format "side"
_windows_build_format() {
    local side="${1:-left}"

    local index_bg index_fg content_bg content_fg style
    read -r index_bg index_fg content_bg content_fg style <<< "$(_windows_get_colors "inactive")"

    local style_attr=""
    [[ -n "$style" && "$style" != "none" ]] && style_attr=",${style}"

    _windows_get_common_settings "$side"

    # Previous window background for transitions
    local active_content_bg previous_bg
    active_content_bg=$(resolve_color "window-active-base")
    previous_bg="#{?#{==:#{e|-:#{window_index},1},#{active_window_index}},${active_content_bg},${content_bg}}"

    # Window icons and title
    local window_icon window_title zoomed_icon activity_icon bell_icon marked_icon
    window_icon=$(get_tmux_option "@powerkit_inactive_window_icon" "${POWERKIT_DEFAULT_INACTIVE_WINDOW_ICON}")
    window_title=$(get_tmux_option "@powerkit_inactive_window_title" "${POWERKIT_DEFAULT_INACTIVE_WINDOW_TITLE}")
    zoomed_icon=$(get_tmux_option "@powerkit_zoomed_window_icon" "${POWERKIT_DEFAULT_ZOOMED_WINDOW_ICON}")
    activity_icon=$(get_tmux_option "@powerkit_window_activity_icon" "${POWERKIT_DEFAULT_WINDOW_ACTIVITY_ICON}")
    bell_icon=$(get_tmux_option "@powerkit_window_bell_icon" "${POWERKIT_DEFAULT_WINDOW_BELL_ICON}")
    marked_icon=$(get_tmux_option "@powerkit_window_marked_icon" "${POWERKIT_DEFAULT_WINDOW_MARKED_ICON}")

    # Icon priority: zoomed > activity > bell > marked > normal
    local icon_conditional
    icon_conditional="#{?window_zoomed_flag,${zoomed_icon},#{?window_activity_flag,${activity_icon},#{?window_bell_flag,${bell_icon},#{?window_marked_flag,${marked_icon},${window_icon}}}}}"

    local format=""
    format+="#[range=window|#{window_id}]"
    format+=$(_windows_build_separator "$side" "$index_bg" "$previous_bg")
    format+="#[fg=${index_fg},bg=${index_bg}${style_attr}]$(window_get_index_display) "
    format+=$(_windows_build_index_sep "$side" "$index_bg" "$content_bg")
    format+="#[fg=${content_fg},bg=${content_bg}${style_attr}]${icon_conditional} ${window_title} "
    format+=$(_windows_build_spacing "$side" "$content_bg")
    format+="#[norange]"

    printf '%s' "$format"
}

# Build window format for active window
# Usage: _windows_build_current_format "side"
_windows_build_current_format() {
    local side="${1:-left}"

    local index_bg index_fg content_bg content_fg style
    read -r index_bg index_fg content_bg content_fg style <<< "$(_windows_get_colors "active")"

    local style_attr=",bold"
    [[ -n "$style" && "$style" != "none" ]] && style_attr=",${style}"

    _windows_get_common_settings "$side"

    # Previous window is always inactive for active window
    local previous_bg
    previous_bg=$(resolve_color "window-inactive-base")

    # Window icons and title
    local window_icon window_title zoomed_icon marked_icon
    window_icon=$(get_tmux_option "@powerkit_active_window_icon" "${POWERKIT_DEFAULT_ACTIVE_WINDOW_ICON}")
    window_title=$(get_tmux_option "@powerkit_active_window_title" "${POWERKIT_DEFAULT_ACTIVE_WINDOW_TITLE}")
    zoomed_icon=$(get_tmux_option "@powerkit_zoomed_window_icon" "${POWERKIT_DEFAULT_ZOOMED_WINDOW_ICON}")
    marked_icon=$(get_tmux_option "@powerkit_window_marked_icon" "${POWERKIT_DEFAULT_WINDOW_MARKED_ICON}")

    # Icon priority for active window: zoomed > marked > normal
    # Note: activity/bell are not shown for active window (you're already looking at it)
    local icon_conditional
    icon_conditional="#{?window_zoomed_flag,${zoomed_icon},#{?window_marked_flag,${marked_icon},${window_icon}}}"

    local format=""
    format+="#[range=window|#{window_id}]"
    format+=$(_windows_build_separator "$side" "$index_bg" "$previous_bg")
    format+="#[fg=${index_fg},bg=${index_bg}${style_attr}]$(window_get_index_display) "
    format+=$(_windows_build_index_sep "$side" "$index_bg" "$content_bg")
    format+="#[fg=${content_fg},bg=${content_bg}${style_attr}]${icon_conditional} ${window_title} $(pane_sync_format)"
    format+=$(_windows_build_spacing "$side" "$content_bg")
    format+="#[norange]"

    printf '%s' "$format"
}

# =============================================================================
# Entity Interface (Required)
# =============================================================================

# Render the windows list
# Usage: windows_render [side]
# Returns: #{W:...} format string for window list
windows_render() {
    local side="${1:-left}"

    # The window list is rendered using tmux's #{W:} which iterates windows
    # and applies window-status-format or window-status-current-format
    # #[list=on] enables click handling
    printf '#[list=on]#{W:#{T:window-status-format},#{T:window-status-current-format}}#[nolist]'
}

# Get the background color of windows (generic)
# Returns: statusbar-bg as fallback
windows_get_bg() {
    resolve_color "statusbar-bg"
}

# =============================================================================
# Entity Interface (Optional)
# =============================================================================

# Get the background color of the first window (for incoming separator)
# Returns: tmux conditional for first window's index background
windows_get_first_bg() {
    local active_index_bg inactive_index_bg
    active_index_bg=$(resolve_color "window-active-base-light")
    inactive_index_bg=$(resolve_color "window-inactive-base-light")

    # If first window (base-index) is active, use active color; else use inactive
    # Use #{base-index} to support both base-index=0 and base-index=1
    printf '#{?#{==:#{active_window_index},#{base-index}},%s,%s}' "$active_index_bg" "$inactive_index_bg"
}

# Get the background color of the last window (for outgoing separator)
# Returns: tmux conditional for last window's content background
windows_get_last_bg() {
    local active_content_bg inactive_content_bg
    active_content_bg=$(resolve_color "window-active-base")
    inactive_content_bg=$(resolve_color "window-inactive-base")

    # If last window is active, use active color; else use inactive
    # Last window index = base-index + session_windows - 1
    printf '#{?#{==:#{active_window_index},#{e|-:#{e|+:#{base-index},#{session_windows}},1}},%s,%s}' "$active_content_bg" "$inactive_content_bg"
}

# Configure window formats in tmux
# This sets window-status-format and window-status-current-format
# Usage: windows_configure [side]
windows_configure() {
    local side="${1:-left}"

    # Build and set window formats
    local window_format current_format
    window_format=$(_windows_build_format "$side")
    current_format=$(_windows_build_current_format "$side")

    tmux set-option -g window-status-format "$window_format"
    tmux set-option -g window-status-current-format "$current_format"

    # Window separator is empty - transitions handled in formats
    tmux set-option -g window-status-separator ""

    # Window status styles
    tmux set-option -g window-status-style "default"
    tmux set-option -g window-status-current-style "default"

    # Activity/bell styles
    local activity_style bell_style
    activity_style=$(resolve_color "window-activity-style")
    bell_style=$(resolve_color "window-bell-style")
    [[ -z "$activity_style" || "$activity_style" == "default" || "$activity_style" == "none" ]] && activity_style="italics"
    [[ -z "$bell_style" || "$bell_style" == "default" || "$bell_style" == "none" ]] && bell_style="bold"
    tmux set-window-option -g window-status-activity-style "$activity_style"
    tmux set-window-option -g window-status-bell-style "$bell_style"
}
