#!/usr/bin/env bash
# =============================================================================
# PowerKit Renderer: Separator
# Description: Powerline separator glyph management and transition logic
# =============================================================================
# This module handles:
# - Separator glyphs (powerline characters)
# - Transition colors between elements (window-to-window, session-to-window)
# - Spacing segments for visual gaps
# - Direction-aware separator rendering (left vs right side of status bar)
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "renderer_separator" && return 0

. "${POWERKIT_ROOT}/src/core/defaults.sh"
. "${POWERKIT_ROOT}/src/core/options.sh"

# =============================================================================
# Separator Style Configuration
# =============================================================================
# Powerline glyphs are defined in defaults.sh as POWERKIT_SEP_* constants

# Get separator style from options
get_separator_style() {
    get_tmux_option "@powerkit_separator_style" "${POWERKIT_DEFAULT_SEPARATOR_STYLE}"
}

# Get edge separator style (boundaries: end of windows, start of plugins)
# Returns the style to use for edge separators, or main style if "same"
get_edge_separator_style() {
    local style
    style=$(get_tmux_option "@powerkit_edge_separator_style" "${POWERKIT_DEFAULT_EDGE_SEPARATOR_STYLE}")

    if [[ "$style" == "same" ]]; then
        get_separator_style
    else
        printf '%s' "$style"
    fi
}

# Get initial separator style (first plugin in status-right)
# Returns the style to use for first plugin separator, defaults to edge style for symmetry
get_initial_separator_style() {
    local style
    style=$(get_tmux_option "@powerkit_initial_separator_style" "")
    
    # If not set, use edge_separator_style for visual symmetry
    if [[ -z "$style" || "$style" == "same" ]]; then
        get_edge_separator_style
    else
        printf '%s' "$style"
    fi
}

# =============================================================================
# Separator Character Functions
# =============================================================================

# Get separator glyph for a specific style and direction
# Usage: _get_separator_glyph "style" "direction"
# direction: "left" or "right"
_get_separator_glyph() {
    local style="$1"
    local direction="${2:-right}"

    if [[ "$direction" == "left" ]]; then
        case "$style" in
            normal)    printf '%s' "$POWERKIT_SEP_SOLID_LEFT" ;;
            rounded)   printf '%s' "$POWERKIT_SEP_ROUND_LEFT" ;;
            flame)     printf '%s' "$POWERKIT_SEP_FLAME_LEFT" ;;
            pixel)     printf '%s' "$POWERKIT_SEP_PIXEL_LEFT" ;;
            honeycomb) printf '%s' "$POWERKIT_SEP_HONEYCOMB_LEFT" ;;
            none)      printf '' ;;
            *)         printf '%s' "$POWERKIT_SEP_ROUND_LEFT" ;;
        esac
    else
        case "$style" in
            normal)    printf '%s' "$POWERKIT_SEP_SOLID_RIGHT" ;;
            rounded)   printf '%s' "$POWERKIT_SEP_ROUND_RIGHT" ;;
            flame)     printf '%s' "$POWERKIT_SEP_FLAME_RIGHT" ;;
            pixel)     printf '%s' "$POWERKIT_SEP_PIXEL_RIGHT" ;;
            honeycomb) printf '%s' "$POWERKIT_SEP_HONEYCOMB_RIGHT" ;;
            none)      printf '' ;;
            *)         printf '%s' "$POWERKIT_SEP_ROUND_RIGHT" ;;
        esac
    fi
}

# Get LEFT separator character (points left ◀, used in status-right)
# Usage: get_left_separator
get_left_separator() {
    _get_separator_glyph "$(get_separator_style)" "left"
}

# Get RIGHT separator character (points right ▶, used in status-left and windows)
# Usage: get_right_separator
get_right_separator() {
    _get_separator_glyph "$(get_separator_style)" "right"
}

# Get FINAL separator character (end of window list, uses edge style)
# Usage: get_final_separator
get_final_separator() {
    _get_separator_glyph "$(get_edge_separator_style)" "right"
}

# Get INITIAL separator character (first plugin in status-right, can have different style)
# Usage: get_initial_separator
get_initial_separator() {
    _get_separator_glyph "$(get_initial_separator_style)" "left"
}

# =============================================================================
# Spacing Configuration
# =============================================================================

# Get spacing mode
# Usage: get_spacing_mode
# Returns: "false", "true" (both), "windows", or "plugins"
get_spacing_mode() {
    get_tmux_option "@powerkit_elements_spacing" "${POWERKIT_DEFAULT_ELEMENTS_SPACING}"
}

# Check if spacing is enabled for windows
has_window_spacing() {
    local mode
    mode=$(get_spacing_mode)
    [[ "$mode" == "both" || "$mode" == "windows" || "$mode" == "true" ]]
}

# Check if spacing is enabled for plugins
has_plugin_spacing() {
    local mode
    mode=$(get_spacing_mode)
    [[ "$mode" == "both" || "$mode" == "plugins" || "$mode" == "true" ]]
}

# =============================================================================
# Window Transition Functions
# These calculate the correct colors for transitions between windows
# =============================================================================

# Calculate previous window background for separator transition
# Usage: get_previous_window_background "active|inactive" "session_bg" "spacing_bg" "active_content_bg" "inactive_content_bg"
get_previous_window_background() {
    local current_window_state="$1"
    local session_color="$2"
    local spacing_bg="$3"
    local active_content_bg="$4"
    local inactive_content_bg="$5"

    local separator_color

    # Check if spacing is enabled
    if has_window_spacing; then
        # Spacing enabled: previous bg is always spacing color
        printf '%s' "$spacing_bg"
        return
    fi

    if [[ "$current_window_state" == "active" ]]; then
        # For active window: previous window is always inactive (or session for first)
        # Use window_index comparison for first window detection
        separator_color="#{?#{==:#{window_index},1},${session_color},${inactive_content_bg}}"
    else
        # For inactive window: check if previous window is active
        # If first window, previous is session
        # If previous window is active, use active_content_bg
        # Else previous is inactive window
        separator_color="#{?#{==:#{e|-:#{window_index},1},0},${session_color},#{?#{==:#{e|-:#{window_index},1},#{active_window_index}},${active_content_bg},${inactive_content_bg}}}"
    fi

    printf '%s' "$separator_color"
}

# =============================================================================
# Separator Building Functions
# =============================================================================

# Build a RIGHT-facing separator (▶) - used for status-left and windows
# The fg color is the PREVIOUS element, bg is the NEXT element
# Usage: build_right_separator "previous_bg" "next_bg"
build_right_separator() {
    local prev_bg="$1"
    local next_bg="$2"

    local sep
    sep=$(get_right_separator)

    [[ -z "$sep" ]] && return

    printf '#[fg=%s,bg=%s]%s' "$prev_bg" "$next_bg" "$sep"
}

# Build a LEFT-facing separator (◀) - used for status-right (plugins)
# The fg color is the NEXT element, bg is the PREVIOUS element
# Usage: build_left_separator "prev_bg" "next_bg"
build_left_separator() {
    local prev_bg="$1"
    local next_bg="$2"

    local sep
    sep=$(get_left_separator)

    [[ -z "$sep" ]] && return

    # For left-facing: fg=next (where arrow points), bg=previous (where we are)
    printf '#[fg=%s,bg=%s]%s' "$next_bg" "$prev_bg" "$sep"
}

# =============================================================================
# Window Separator Functions
# =============================================================================

# Create window-to-window separator
# Right-facing separator (→): fg=previous, bg=current
# Usage: create_window_separator "active|inactive" "session_bg" "spacing_bg" "active_content_bg" "inactive_content_bg" "current_index_bg"
create_window_separator() {
    local window_state="$1"
    local session_bg="$2"
    local spacing_bg="$3"
    local active_content_bg="$4"
    local inactive_content_bg="$5"
    local current_index_bg="$6"

    local previous_bg
    previous_bg=$(get_previous_window_background "$window_state" "$session_bg" "$spacing_bg" "$active_content_bg" "$inactive_content_bg")

    build_right_separator "$previous_bg" "$current_index_bg"
}

# Create index-to-content separator (between window number and content)
# Right-facing separator (→): fg=index_bg, bg=content_bg
# Usage: create_index_content_separator "index_bg" "content_bg"
create_index_content_separator() {
    local index_bg="$1"
    local content_bg="$2"

    build_right_separator "$index_bg" "$content_bg"
}

# =============================================================================
# Spacing Segment Functions
# =============================================================================

# Create spacing segment between elements
# Usage: create_spacing_segment "current_bg" "spacing_bg"
create_spacing_segment() {
    local current_bg="$1"
    local spacing_bg="$2"

    local sep
    sep=$(get_right_separator)

    # Create spacing: close current element with separator + small gap
    printf '#[fg=%s,bg=%s]%s#[bg=%s] ' "$current_bg" "$spacing_bg" "$sep" "$spacing_bg"
}

# Create final separator (end of window list to status bar)
# Uses @powerkit_edge_separator_style for different pill/rounded effects
# Usage: create_final_separator "status_bg" "active_content_bg" "inactive_content_bg"
create_final_separator() {
    local status_bg="$1"
    local active_content_bg="$2"
    local inactive_content_bg="$3"

    # If spacing is enabled, each window already adds its own separator + spacing
    # The last window's separator IS the final separator, so we don't add another
    if has_window_spacing; then
        printf ''
        return
    fi

    local sep
    sep=$(get_final_separator)

    # Handle none style
    [[ -z "$sep" ]] && return

    # Conditional: if last window is active, use active_content_bg, else inactive_content_bg
    # #{?#{==:#{session_windows},#{active_window_index}},active,inactive}
    # fg = window content color (what we're leaving)
    # bg = status bar background (where we're going)
    printf '#{?#{==:#{session_windows},#{active_window_index}},#[fg=%s],#[fg=%s]}#[bg=%s]%s' \
        "$active_content_bg" "$inactive_content_bg" "$status_bg" "$sep"
}

# =============================================================================
# Plugin Separator Functions (for status-right)
# =============================================================================

# Build transition for status-right plugins (left-facing)
# In status-right, content flows right-to-left, so separators point left
# Usage: build_plugin_transition "from_bg" "to_bg"
build_plugin_transition() {
    local from_bg="$1"
    local to_bg="$2"

    build_left_separator "$from_bg" "$to_bg"
}

# =============================================================================
# Utility Functions
# =============================================================================

# List all available separator styles
list_separator_styles() {
    printf 'normal rounded flame pixel honeycomb none\n'
}

# Check if separator style is valid
is_valid_separator_style() {
    local style="$1"
    case "$style" in
        normal|rounded|flame|pixel|honeycomb|none) return 0 ;;
        *) return 1 ;;
    esac
}
