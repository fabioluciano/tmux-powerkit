#!/usr/bin/env bash
# =============================================================================
#  WINDOW CONTRACT
#  Window render contract interface
# =============================================================================
#
# TABLE OF CONTENTS
# =================
#   1. Overview
#   2. Window States
#   3. Format Building Functions
#   4. Conditional State Formats
#   5. Icon Resolution
#   6. Complete Window Templates
#   7. API Reference
#
# =============================================================================
#
# 1. OVERVIEW
# ===========
#
# The Window Contract defines how windows are rendered in the tmux status bar.
# Unlike plugins, windows use tmux variables directly - no data collection needed.
#
# Key Concepts:
#   - Windows get their state from tmux variables (#{window_active}, etc.)
#   - Format strings use tmux conditionals for dynamic behavior
#   - Icons can be mapped from command names (vim → , bash → , etc.)
#
# Available tmux variables:
#   #{window_index}        - Window index number
#   #{window_name}         - Window name
#   #{window_flags}        - Window flags (#, !, ~, *, -, Z, etc.)
#   #{window_activity_flag} - 1 if window has activity
#   #{window_bell_flag}    - 1 if window has bell
#   #{window_zoomed_flag}  - 1 if window is zoomed
#   #{window_last_flag}    - 1 if window was last active
#   #{window_marked_flag}  - 1 if window is marked
#   #{window_active}       - 1 if window is current
#   #{pane_current_command} - Current command running in pane
#
# =============================================================================
#
# 2. API REFERENCE
# ================
#
#   Format Building:
#     window_index_format()         - Returns "#{window_index}"
#     window_name_format()          - Returns "#{window_name}"
#     window_flags_format()         - Returns "#{window_flags}"
#     window_basic_format()         - Returns "#{window_index}:#{window_name}"
#
#   State Indicators:
#     window_zoom_format(zoomed, normal)       - Conditional zoom format
#     window_activity_format(active, normal)   - Conditional activity format
#     window_bell_format(bell, normal)         - Conditional bell format
#     window_last_format(last, normal)         - Conditional last window format
#     window_state_indicators()                - Combined state indicators
#
#   Index Icons:
#     window_get_index_icon_format() - Tmux conditional for numeric icons (1-10)
#     window_get_index_display()     - Returns icon format or #{window_index}
#
#   Command Icons:
#     window_get_icon_format()      - Dynamic icon based on command
#     window_get_simple_icon(active) - Simple static icon
#
#   Templates:
#     window_get_active_format()    - Complete active window format
#     window_get_inactive_format()  - Complete inactive window format
#
#   Validation:
#     is_valid_window_state(state)  - Check if state is valid
#
# =============================================================================
# END OF DOCUMENTATION
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "contract_window" && return 0

# Note: All core and utils modules are loaded by bootstrap.sh

# =============================================================================
# Window States
# =============================================================================

# Note: WINDOW_STATES is now defined in registry.sh for centralization
# This alias is kept for backward compatibility
# shellcheck disable=SC2034
declare -gra _WINDOW_STATES=("${WINDOW_STATES[@]}")

# =============================================================================
# Window Format Building
# =============================================================================

# Build basic window index format
window_index_format() {
    printf '#{window_index}'
}

# Build window name format
window_name_format() {
    printf '#{window_name}'
}

# Build window flags format
window_flags_format() {
    printf '#{window_flags}'
}

# Build combined window format
# Returns: "index:name"
window_basic_format() {
    printf '#{window_index}:#{window_name}'
}

# =============================================================================
# Conditional State Formats
# =============================================================================

# Build zoom indicator format
# Usage: window_zoom_format "[Z]" ""
window_zoom_format() {
    local zoomed_text="${1:-[Z]}"
    local normal_text="${2:-}"
    printf '#{?window_zoomed_flag,%s,%s}' "$zoomed_text" "$normal_text"
}

# Build activity indicator format
# Usage: window_activity_format "!" ""
window_activity_format() {
    local activity_text="${1:-!}"
    local normal_text="${2:-}"
    printf '#{?window_activity_flag,%s,%s}' "$activity_text" "$normal_text"
}

# Build bell indicator format
# Usage: window_bell_format "B" ""
window_bell_format() {
    local bell_text="${1:-B}"
    local normal_text="${2:-}"
    printf '#{?window_bell_flag,%s,%s}' "$bell_text" "$normal_text"
}

# Build last window indicator format
# Usage: window_last_format "-" ""
window_last_format() {
    local last_text="${1:--}"
    local normal_text="${2:-}"
    printf '#{?window_last_flag,%s,%s}' "$last_text" "$normal_text"
}

# Build combined state indicators
window_state_indicators() {
    local format=""
    format+='#{?window_zoomed_flag,Z,}'
    format+='#{?window_activity_flag,!,}'
    format+='#{?window_bell_flag,B,}'
    printf '%s' "$format"
}

# =============================================================================
# Window Index Icon Resolution
# =============================================================================

# Build tmux conditional format for index-based icons
# Uses get_window_index_icon from registry.sh
# Returns: nested conditional that maps #{window_index} to styled icons/text
# Supports: text, numeric, box, box_outline, box_multiple, box_multiple_outline
window_get_index_icon_format() {
    local style="${1:-numeric}"
    local fallback='#{window_index}'
    local format="$fallback"

    # For text style, just return the plain index
    [[ "$style" == "text" ]] && { printf '%s' "$fallback"; return; }

    # Generate icons for indices 0-49 (descending order for correct conditional evaluation)
    for index in {49..0}; do
        local icon
        icon="$(get_window_index_icon "$index" "$style")"
        format="#{?#{==:#{window_index},$index},$icon,$format}"
    done

    printf '%s' "$format"
}

# Get window index format based on settings
# Uses @powerkit_window_index_style to determine display format
# Values: text, numeric, box, box_outline, box_multiple, box_multiple_outline
window_get_index_display() {
    local style
    style=$(get_tmux_option "@powerkit_window_index_style" "${POWERKIT_DEFAULT_WINDOW_INDEX_STYLE:-text}")

    if [[ "$style" == "text" ]]; then
        printf '#{window_index}'
    else
        window_get_index_icon_format "$style"
    fi
}

# =============================================================================
# Window Icon Resolution
# =============================================================================

# Build tmux conditional format for command-based icons
# Uses WINDOW_ICON_MAP from registry.sh
window_get_icon_format() {
    local default_icon
    default_icon=$(get_tmux_option "@powerkit_window_default_icon" "$WINDOW_DEFAULT_ICON")

    # Build nested conditional format from the icon map
    local format="$default_icon"
    local cmd icon

    # Iterate through icon map (from registry.sh)
    for cmd in "${!WINDOW_ICON_MAP[@]}"; do
        icon="${WINDOW_ICON_MAP[$cmd]}"
        format="#{?#{==:#{pane_current_command},$cmd},$icon,$format}"
    done

    printf '%s' "$format"
}

# Simpler icon format (just returns default or custom)
# Usage: window_get_simple_icon "1" (active) or "0" (inactive)
window_get_simple_icon() {
    local is_active="$1"

    local active_icon inactive_icon
    active_icon=$(get_tmux_option "@powerkit_active_window_icon" "")
    inactive_icon=$(get_tmux_option "@powerkit_inactive_window_icon" "")

    if [[ "$is_active" == "1" && -n "$active_icon" ]]; then
        printf '%s' "$active_icon"
    elif [[ "$is_active" != "1" && -n "$inactive_icon" ]]; then
        printf '%s' "$inactive_icon"
    fi
}

# =============================================================================
# Complete Window Format Templates (DRY implementation)
# =============================================================================

# Internal: Build window format based on type
# Usage: _window_get_format "active" or _window_get_format "inactive"
_window_get_format() {
    local type="$1"
    local prefix="@powerkit_${type}_window"

    # Defaults differ by type
    local default_show_icon="false"
    [[ "$type" == "active" ]] && default_show_icon="true"

    # Get options
    local show_icon show_index show_name show_flags
    show_icon=$(get_tmux_option "${prefix}_show_icon" "$default_show_icon")
    show_index=$(get_tmux_option "${prefix}_show_index" "true")
    show_name=$(get_tmux_option "${prefix}_show_name" "true")
    show_flags=$(get_tmux_option "${prefix}_show_flags" "false")

    # Determine is_active for icon lookup
    local is_active="0"
    [[ "$type" == "active" ]] && is_active="1"

    # Build format string
    local format=""

    # Icon (if enabled)
    if [[ "$show_icon" == "true" ]]; then
        local icon
        icon=$(window_get_simple_icon "$is_active")
        [[ -n "$icon" ]] && format+="${icon} "
    fi

    # Index (if enabled)
    [[ "$show_index" == "true" ]] && format+="#{window_index}"

    # Separator between index and name
    if [[ "$show_index" == "true" && "$show_name" == "true" ]]; then
        format+=":"
    fi

    # Name (if enabled)
    [[ "$show_name" == "true" ]] && format+="#{window_name}"

    # Flags (if enabled)
    [[ "$show_flags" == "true" ]] && format+="#{window_flags}"

    printf '%s' "$format"
}

# Get active window format (public API)
# Usage: window_get_active_format
window_get_active_format() {
    _window_get_format "active"
}

# Get inactive window format (public API)
# Usage: window_get_inactive_format
window_get_inactive_format() {
    _window_get_format "inactive"
}

# =============================================================================
# Utility Functions
# =============================================================================

# Check if state is valid
# Uses validate_against_enum from validation.sh
is_valid_window_state() {
    local state="$1"
    validate_against_enum "$state" WINDOW_STATES
}
