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
# Sets: _W_TRANSPARENT, _W_SPACING_BG, _W_STATUS_BG, _W_SEP_CHAR
_windows_get_common_settings() {
    local side="$1"

    _W_TRANSPARENT=$(get_tmux_option "@powerkit_transparent" "${POWERKIT_DEFAULT_TRANSPARENT}")
    if [[ "$_W_TRANSPARENT" == "true" ]]; then
        _W_SPACING_BG="default"
        _W_STATUS_BG="default"
    else
        _W_SPACING_BG=$(resolve_color "statusbar-bg")
        _W_STATUS_BG="$_W_SPACING_BG"
    fi

    if [[ "$side" == "left" ]]; then
        _W_SEP_CHAR=$(get_right_separator)
    else
        _W_SEP_CHAR=$(get_left_separator)
    fi
}

# Build window-to-window separator
# Usage: _windows_build_separator "side" "index_bg" "previous_bg"
_windows_build_separator() {
    local side="$1" index_bg="$2" previous_bg="$3"

    if has_window_spacing; then
        local sep_fg="$_W_SPACING_BG"
        [[ "$_W_TRANSPARENT" == "true" ]] && sep_fg=$(resolve_color "background")
        if [[ "$side" == "left" ]]; then
            printf '#[fg=%s,bg=%s]%s' "$sep_fg" "$index_bg" "$_W_SEP_CHAR"
        else
            printf '#[fg=%s,bg=%s]%s' "$index_bg" "$sep_fg" "$_W_SEP_CHAR"
        fi
    else
        if [[ "$side" == "left" ]]; then
            printf '#{?#{!=:#{window_index},1},#[fg=%s#,bg=%s]%s,}' "$previous_bg" "$index_bg" "$_W_SEP_CHAR"
        else
            local edge_sep
            edge_sep=$(_get_separator_glyph "$(get_edge_separator_style)" "left")
            printf '#{?#{==:#{window_index},1},#[fg=%s#,bg=%s]%s,#[fg=%s#,bg=%s]%s}' \
                "$index_bg" "$_W_STATUS_BG" "$edge_sep" "$index_bg" "$previous_bg" "$_W_SEP_CHAR"
        fi
    fi
}

# Build index-to-content separator
# Usage: _windows_build_index_sep "side" "index_bg" "content_bg"
_windows_build_index_sep() {
    local side="$1" index_bg="$2" content_bg="$3"

    if [[ "$side" == "left" ]]; then
        printf '#[fg=%s,bg=%s]%s' "$index_bg" "$content_bg" "$_W_SEP_CHAR"
    else
        printf '#[fg=%s,bg=%s]%s' "$content_bg" "$index_bg" "$_W_SEP_CHAR"
    fi
}

# Build spacing separator (if enabled)
# Usage: _windows_build_spacing "side" "content_bg"
_windows_build_spacing() {
    local side="$1" content_bg="$2"

    has_window_spacing || return

    if [[ "$side" == "left" ]]; then
        printf '#[fg=%s,bg=%s]%s#[bg=%s]' "$content_bg" "$_W_SPACING_BG" "$_W_SEP_CHAR" "$_W_SPACING_BG"
    else
        printf '#[fg=%s,bg=%s]%s#[bg=%s]' "$_W_SPACING_BG" "$content_bg" "$_W_SEP_CHAR" "$_W_SPACING_BG"
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
    local window_icon window_title zoomed_icon
    window_icon=$(get_tmux_option "@powerkit_inactive_window_icon" "${POWERKIT_DEFAULT_INACTIVE_WINDOW_ICON}")
    window_title=$(get_tmux_option "@powerkit_inactive_window_title" "${POWERKIT_DEFAULT_INACTIVE_WINDOW_TITLE}")
    zoomed_icon=$(get_tmux_option "@powerkit_zoomed_window_icon" "${POWERKIT_DEFAULT_ZOOMED_WINDOW_ICON}")

    local format=""
    format+="#[range=window|#{window_id}]"
    format+=$(_windows_build_separator "$side" "$index_bg" "$previous_bg")
    format+="#[fg=${index_fg},bg=${index_bg}${style_attr}] $(window_get_index_display) "
    format+=$(_windows_build_index_sep "$side" "$index_bg" "$content_bg")
    format+="#[fg=${content_fg},bg=${content_bg}${style_attr}] #{?window_zoomed_flag,${zoomed_icon},${window_icon}} ${window_title} "
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
    local window_icon window_title zoomed_icon pane_sync_icon
    window_icon=$(get_tmux_option "@powerkit_active_window_icon" "${POWERKIT_DEFAULT_ACTIVE_WINDOW_ICON}")
    window_title=$(get_tmux_option "@powerkit_active_window_title" "${POWERKIT_DEFAULT_ACTIVE_WINDOW_TITLE}")
    zoomed_icon=$(get_tmux_option "@powerkit_zoomed_window_icon" "${POWERKIT_DEFAULT_ZOOMED_WINDOW_ICON}")
    pane_sync_icon=$(get_tmux_option "@powerkit_pane_synchronized_icon" "${POWERKIT_DEFAULT_PANE_SYNCHRONIZED_ICON}")

    local format=""
    format+="#[range=window|#{window_id}]"
    format+=$(_windows_build_separator "$side" "$index_bg" "$previous_bg")
    format+="#[fg=${index_fg},bg=${index_bg}${style_attr}] $(window_get_index_display) "
    format+=$(_windows_build_index_sep "$side" "$index_bg" "$content_bg")
    format+="#[fg=${content_fg},bg=${content_bg}${style_attr}] #{?window_zoomed_flag,${zoomed_icon},${window_icon}} ${window_title} #{?pane_synchronized,${pane_sync_icon},}"
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

    # If window 1 is active, use active color; else use inactive
    printf '#{?#{==:#{active_window_index},1},%s,%s}' "$active_index_bg" "$inactive_index_bg"
}

# Get the background color of the last window (for outgoing separator)
# Returns: tmux conditional for last window's content background
windows_get_last_bg() {
    local active_content_bg inactive_content_bg
    active_content_bg=$(resolve_color "window-active-base")
    inactive_content_bg=$(resolve_color "window-inactive-base")

    # If last window is active, use active color; else use inactive
    # #{session_windows} gives the number of windows (== last window index for 1-based)
    printf '#{?#{==:#{active_window_index},#{session_windows}},%s,%s}' "$active_content_bg" "$inactive_content_bg"
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
