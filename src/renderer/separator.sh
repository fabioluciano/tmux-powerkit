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

# Per-cycle cache for separator characters (avoids repeated tmux option lookups)
declare -g _SEP_CACHE_STYLE=""
declare -g _SEP_CACHE_EDGE_STYLE=""
declare -g _SEP_CACHE_EDGE_APPLY_ALL=""
declare -g _SEP_CACHE_INITIAL_STYLE=""
declare -g _SEP_CACHE_LEFT=""
declare -g _SEP_CACHE_RIGHT=""
declare -g _SEP_CACHE_INITIAL=""
declare -g _SEP_CACHE_FINAL=""
declare -g _SEP_CACHE_SPACING_MODE=""
declare -g _SEP_CACHE_EDGE_LEFT=""
declare -g _SEP_CACHE_EDGE_RIGHT=""

# Reset separator cache (call at start of each render cycle along with cache_reset_cycle)
separator_reset_cache() {
    _SEP_CACHE_STYLE=""
    _SEP_CACHE_EDGE_STYLE=""
    _SEP_CACHE_EDGE_APPLY_ALL=""
    _SEP_CACHE_INITIAL_STYLE=""
    _SEP_CACHE_LEFT=""
    _SEP_CACHE_RIGHT=""
    _SEP_CACHE_INITIAL=""
    _SEP_CACHE_FINAL=""
    _SEP_CACHE_SPACING_MODE=""
    _SEP_CACHE_EDGE_LEFT=""
    _SEP_CACHE_EDGE_RIGHT=""
}

# Pre-populate separator cache (call early in render cycle to avoid subshell losses)
# After calling this, use $_SEP_CACHE_LEFT, $_SEP_CACHE_RIGHT directly instead of
# $(get_left_separator), $(get_right_separator) to avoid subshell overhead.
# Usage: separator_ensure_cache
separator_ensure_cache() {
    # Ensure style is loaded first
    [[ -z "$_SEP_CACHE_STYLE" ]] && _SEP_CACHE_STYLE=$(get_tmux_option "@powerkit_separator_style" "${POWERKIT_DEFAULT_SEPARATOR_STYLE}")

    # Pre-populate all separator glyphs
    [[ -z "$_SEP_CACHE_LEFT" ]] && _SEP_CACHE_LEFT=$(_get_separator_glyph "$_SEP_CACHE_STYLE" "left")
    [[ -z "$_SEP_CACHE_RIGHT" ]] && _SEP_CACHE_RIGHT=$(_get_separator_glyph "$_SEP_CACHE_STYLE" "right")

    # Edge style - parse :all suffix for apply-all-edges feature
    [[ -z "$_SEP_CACHE_EDGE_STYLE" ]] && {
        local raw_style
        raw_style=$(get_tmux_option "@powerkit_edge_separator_style" "${POWERKIT_DEFAULT_EDGE_SEPARATOR_STYLE}")
        # Remove :all suffix if present and cache the flag
        if [[ "$raw_style" == *":all" ]]; then
            _SEP_CACHE_EDGE_APPLY_ALL="true"
            _SEP_CACHE_EDGE_STYLE="${raw_style%%:all}"
        else
            _SEP_CACHE_EDGE_APPLY_ALL="false"
            _SEP_CACHE_EDGE_STYLE="$raw_style"
        fi
        [[ "$_SEP_CACHE_EDGE_STYLE" == "same" ]] && _SEP_CACHE_EDGE_STYLE="$_SEP_CACHE_STYLE"
    }

    [[ -z "$_SEP_CACHE_FINAL" ]] && _SEP_CACHE_FINAL=$(_get_separator_glyph "$_SEP_CACHE_EDGE_STYLE" "right")

    # Initial style
    [[ -z "$_SEP_CACHE_INITIAL_STYLE" ]] && {
        local style
        style=$(get_tmux_option "@powerkit_initial_separator_style" "")
        [[ -z "$style" || "$style" == "same" ]] && style="$_SEP_CACHE_EDGE_STYLE"
        _SEP_CACHE_INITIAL_STYLE="$style"
    }

    [[ -z "$_SEP_CACHE_INITIAL" ]] && _SEP_CACHE_INITIAL=$(_get_separator_glyph "$_SEP_CACHE_INITIAL_STYLE" "left")

    # Spacing mode
    [[ -z "$_SEP_CACHE_SPACING_MODE" ]] && _SEP_CACHE_SPACING_MODE=$(get_tmux_option "@powerkit_elements_spacing" "${POWERKIT_DEFAULT_ELEMENTS_SPACING}")

    # Edge separator glyphs
    [[ -z "$_SEP_CACHE_EDGE_LEFT" ]] && _SEP_CACHE_EDGE_LEFT=$(_get_separator_glyph "$_SEP_CACHE_EDGE_STYLE" "left")
    [[ -z "$_SEP_CACHE_EDGE_RIGHT" ]] && _SEP_CACHE_EDGE_RIGHT=$(_get_separator_glyph "$_SEP_CACHE_EDGE_STYLE" "right")
}

# Get separator style from options (cached per-cycle)
get_separator_style() {
    if [[ -z "$_SEP_CACHE_STYLE" ]]; then
        _SEP_CACHE_STYLE=$(get_tmux_option "@powerkit_separator_style" "${POWERKIT_DEFAULT_SEPARATOR_STYLE}")
    fi
    printf '%s' "$_SEP_CACHE_STYLE"
}

# Get edge separator style (boundaries: end of windows, start of plugins)
# Returns the style to use for edge separators (without :all suffix), or main style if "same"
# Parses :all suffix and caches the apply-all flag
# Usage: get_edge_separator_style
get_edge_separator_style() {
    if [[ -z "$_SEP_CACHE_EDGE_STYLE" ]]; then
        local raw_style
        raw_style=$(get_tmux_option "@powerkit_edge_separator_style" "${POWERKIT_DEFAULT_EDGE_SEPARATOR_STYLE}")

        # Remove :all suffix if present and cache the flag
        if [[ "$raw_style" == *":all" ]]; then
            _SEP_CACHE_EDGE_APPLY_ALL="true"
            _SEP_CACHE_EDGE_STYLE="${raw_style%%:all}"
        else
            _SEP_CACHE_EDGE_APPLY_ALL="false"
            _SEP_CACHE_EDGE_STYLE="$raw_style"
        fi

        [[ "$_SEP_CACHE_EDGE_STYLE" == "same" ]] && _SEP_CACHE_EDGE_STYLE=$(get_separator_style)
    fi
    printf '%s' "$_SEP_CACHE_EDGE_STYLE"
}

# Get initial separator style (first plugin in status-right)
# Returns the style to use for first plugin separator, defaults to edge style for symmetry (cached per-cycle)
get_initial_separator_style() {
    if [[ -z "$_SEP_CACHE_INITIAL_STYLE" ]]; then
        local style
        style=$(get_tmux_option "@powerkit_initial_separator_style" "")

        # If not set, use edge_separator_style for visual symmetry
        if [[ -z "$style" || "$style" == "same" ]]; then
            _SEP_CACHE_INITIAL_STYLE=$(get_edge_separator_style)
        else
            _SEP_CACHE_INITIAL_STYLE="$style"
        fi
    fi
    printf '%s' "$_SEP_CACHE_INITIAL_STYLE"
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
            normal)           printf '%s' "$POWERKIT_SEP_SOLID_LEFT" ;;
            rounded)          printf '%s' "$POWERKIT_SEP_ROUND_LEFT" ;;
            slant)            printf '%s' "$POWERKIT_SEP_SLANT_LEFT" ;;
            slantup|slant-up) printf '%s' "$POWERKIT_SEP_SLANT_UP_LEFT" ;;
            flame)            printf '%s' "$POWERKIT_SEP_FLAME_LEFT" ;;
            pixel)            printf '%s' "$POWERKIT_SEP_PIXEL_LEFT" ;;
            honeycomb)        printf '%s' "$POWERKIT_SEP_HONEYCOMB_LEFT" ;;
            trapezoid)        printf '%s' "$POWERKIT_SEP_TRAPEZOID_LEFT" ;;
            none)             printf '' ;;
            *)                printf '%s' "$POWERKIT_SEP_ROUND_LEFT" ;;
        esac
    else
        case "$style" in
            normal)           printf '%s' "$POWERKIT_SEP_SOLID_RIGHT" ;;
            rounded)          printf '%s' "$POWERKIT_SEP_ROUND_RIGHT" ;;
            slant)            printf '%s' "$POWERKIT_SEP_SLANT_RIGHT" ;;
            slantup|slant-up) printf '%s' "$POWERKIT_SEP_SLANT_UP_RIGHT" ;;
            flame)            printf '%s' "$POWERKIT_SEP_FLAME_RIGHT" ;;
            pixel)            printf '%s' "$POWERKIT_SEP_PIXEL_RIGHT" ;;
            honeycomb)        printf '%s' "$POWERKIT_SEP_HONEYCOMB_RIGHT" ;;
            trapezoid)        printf '%s' "$POWERKIT_SEP_TRAPEZOID_RIGHT" ;;
            none)             printf '' ;;
            *)                printf '%s' "$POWERKIT_SEP_ROUND_RIGHT" ;;
        esac
    fi
}

# Get LEFT separator character (points left ◀, used in status-right) (cached per-cycle)
# Usage: get_left_separator
get_left_separator() {
    if [[ -z "$_SEP_CACHE_LEFT" ]]; then
        _SEP_CACHE_LEFT=$(_get_separator_glyph "$(get_separator_style)" "left")
    fi
    printf '%s' "$_SEP_CACHE_LEFT"
}

# Get RIGHT separator character (points right ▶, used in status-left and windows) (cached per-cycle)
# Usage: get_right_separator
get_right_separator() {
    if [[ -z "$_SEP_CACHE_RIGHT" ]]; then
        _SEP_CACHE_RIGHT=$(_get_separator_glyph "$(get_separator_style)" "right")
    fi
    printf '%s' "$_SEP_CACHE_RIGHT"
}

# Get FINAL separator character (end of window list, uses edge style) (cached per-cycle)
# Usage: get_final_separator
get_final_separator() {
    if [[ -z "$_SEP_CACHE_FINAL" ]]; then
        _SEP_CACHE_FINAL=$(_get_separator_glyph "$(get_edge_separator_style)" "right")
    fi
    printf '%s' "$_SEP_CACHE_FINAL"
}

# Get INITIAL separator character (first plugin in status-right, can have different style) (cached per-cycle)
# Usage: get_initial_separator
get_initial_separator() {
    if [[ -z "$_SEP_CACHE_INITIAL" ]]; then
        _SEP_CACHE_INITIAL=$(_get_separator_glyph "$(get_initial_separator_style)" "left")
    fi
    printf '%s' "$_SEP_CACHE_INITIAL"
}

# =============================================================================
# Spacing Configuration
# =============================================================================

# Get spacing mode (cached per-cycle)
# Usage: get_spacing_mode
# Returns: "false", "true" (both), "windows", or "plugins"
get_spacing_mode() {
    if [[ -z "$_SEP_CACHE_SPACING_MODE" ]]; then
        _SEP_CACHE_SPACING_MODE=$(get_tmux_option "@powerkit_elements_spacing" "${POWERKIT_DEFAULT_ELEMENTS_SPACING}")
    fi
    printf '%s' "$_SEP_CACHE_SPACING_MODE"
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
# Apply All Edges Configuration
# =============================================================================
# When edge_separator_style has :all suffix (e.g., "rounded:all"), ALL external
# edges use the edge style:
# - Session segment start/end
# - First and last window edges
# This creates a fully styled appearance at all bar boundaries.

# Check if edge style should apply to ALL external edges (cached per-cycle)
# Returns true when @powerkit_edge_separator_style has :all suffix
# Usage: should_apply_all_edges
should_apply_all_edges() {
    # Ensure edge style is parsed (which also sets _SEP_CACHE_EDGE_APPLY_ALL)
    [[ -z "$_SEP_CACHE_EDGE_APPLY_ALL" ]] && get_edge_separator_style >/dev/null
    [[ "$_SEP_CACHE_EDGE_APPLY_ALL" == "true" ]]
}

# Get edge-style RIGHT separator (cached per-cycle)
# Usage: get_edge_right_separator
get_edge_right_separator() {
    if [[ -z "$_SEP_CACHE_EDGE_RIGHT" ]]; then
        _SEP_CACHE_EDGE_RIGHT=$(_get_separator_glyph "$(get_edge_separator_style)" "right")
    fi
    printf '%s' "$_SEP_CACHE_EDGE_RIGHT"
}

# Get edge-style LEFT separator (cached per-cycle)
# Usage: get_edge_left_separator
get_edge_left_separator() {
    if [[ -z "$_SEP_CACHE_EDGE_LEFT" ]]; then
        _SEP_CACHE_EDGE_LEFT=$(_get_separator_glyph "$(get_edge_separator_style)" "left")
    fi
    printf '%s' "$_SEP_CACHE_EDGE_LEFT"
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
# Side-Aware Separator Functions
# =============================================================================
# When elements are positioned on different sides of the status bar,
# separators need to point in different directions:
# - Elements on LEFT side use RIGHT-pointing separators (▶)
# - Elements on RIGHT side use LEFT-pointing separators (◀)

# Get opening separator for a given side
# Usage: get_opening_separator_for_side "left|right" ["is_first"]
# - left side: returns RIGHT separator (▶)
# - right side: returns LEFT separator (◀) or initial separator if is_first=1
get_opening_separator_for_side() {
    local side="${1:-right}"
    local is_first="${2:-0}"

    if [[ "$side" == "left" ]]; then
        # Left side of bar → RIGHT-pointing separators
        if [[ "$is_first" -eq 1 ]]; then
            _get_separator_glyph "$(get_edge_separator_style)" "right"
        else
            get_right_separator
        fi
    else
        # Right side of bar → LEFT-pointing separators
        if [[ "$is_first" -eq 1 ]]; then
            get_initial_separator
        else
            get_left_separator
        fi
    fi
}

# Get internal separator for a given side (between icon and content)
# Usage: get_internal_separator_for_side "left|right"
get_internal_separator_for_side() {
    local side="${1:-right}"

    if [[ "$side" == "left" ]]; then
        get_right_separator
    else
        get_left_separator
    fi
}

# Get closing separator for a given side
# Usage: get_closing_separator_for_side "left|right"
get_closing_separator_for_side() {
    local side="${1:-right}"

    if [[ "$side" == "left" ]]; then
        get_right_separator
    else
        get_left_separator
    fi
}

# Build opening separator with colors for a given side
# Usage: build_opening_separator_for_side "side" "prev_bg" "next_bg" ["is_first"]
build_opening_separator_for_side() {
    local side="${1:-right}"
    local prev_bg="$2"
    local next_bg="$3"
    local is_first="${4:-0}"

    local sep
    sep=$(get_opening_separator_for_side "$side" "$is_first")

    [[ -z "$sep" ]] && return

    if [[ "$side" == "left" ]]; then
        # Right-pointing (▶): fg=source (prev), bg=destination (next)
        printf '#[fg=%s,bg=%s]%s' "$prev_bg" "$next_bg" "$sep"
    else
        # Left-pointing (◀): fg=destination (next), bg=source (prev)
        printf '#[fg=%s,bg=%s]%s' "$next_bg" "$prev_bg" "$sep"
    fi
}

# Build internal separator with colors for a given side
# Usage: build_internal_separator_for_side "side" "from_bg" "to_bg"
build_internal_separator_for_side() {
    local side="${1:-right}"
    local from_bg="$2"
    local to_bg="$3"

    local sep
    sep=$(get_internal_separator_for_side "$side")

    [[ -z "$sep" ]] && return

    if [[ "$side" == "left" ]]; then
        # Right-pointing (▶): fg=source (from), bg=destination (to)
        printf '#[fg=%s,bg=%s]%s' "$from_bg" "$to_bg" "$sep"
    else
        # Left-pointing (◀): fg=destination (to), bg=source (from)
        printf '#[fg=%s,bg=%s]%s' "$to_bg" "$from_bg" "$sep"
    fi
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
    printf '%s\n' "$POWERKIT_SEPARATOR_STYLES"
}

# Check if separator style is valid
is_valid_separator_style() {
    local style="$1"
    case "$style" in
        normal|rounded|slant|slantup|slant-up|trapezoid|flame|pixel|honeycomb|none) return 0 ;;
        *) return 1 ;;
    esac
}
