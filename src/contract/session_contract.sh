#!/usr/bin/env bash
# =============================================================================
#  SESSION CONTRACT
#  Session contract interface for status-left rendering
# =============================================================================
#
# TABLE OF CONTENTS
# =================
#   1. Overview
#   2. Session Modes
#   3. State Detection
#   4. Rendering Functions
#   5. Icon Resolution
#   6. Format Strings
#   7. API Reference
#
# =============================================================================
#
# 1. OVERVIEW
# ===========
#
# The Session Contract defines the interface for rendering session information
# in the tmux status bar (typically status-left).
#
# Key Concepts:
#   - Session state: attached or detached
#   - Session mode: normal, prefix, copy, command, search
#   - Context: additional flags like alerts, grouped sessions
#   - Icons: mode-aware icons for visual feedback
#
# Performance:
#   - Uses batch tmux calls to minimize subprocess overhead
#   - Single tmux display-message call fetches multiple variables
#   - session_get_all() provides efficient bulk data retrieval
#
# =============================================================================
#
# 2. API REFERENCE
# ================
#
#   State Detection:
#     session_get_state()    - Returns "attached" or "detached"
#     session_get_mode()     - Returns current mode (normal, prefix, copy, etc.)
#     session_get_context()  - Returns context flags (alerts, grouped)
#
#   Rendering:
#     session_get_name()     - Returns session name
#     session_render()       - Returns session display text
#
#   Icons:
#     session_get_icon()     - Returns mode-appropriate icon
#
#   Format Strings:
#     session_get_mode_format()    - tmux format for mode-aware display
#     session_get_color_format()   - tmux conditional color format
#
#   Batch Operations:
#     session_get_all()      - Returns all session info in one call
#
#   Validation:
#     is_valid_mode(mode)    - Check if mode is valid
#
# =============================================================================
# END OF DOCUMENTATION
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "contract_session" && return 0

# Note: All core and utils modules are loaded by bootstrap.sh

# =============================================================================
# Session Modes
# =============================================================================

# Note: SESSION_MODES is now defined in registry.sh for centralization
# This alias is kept for backward compatibility
# shellcheck disable=SC2034
declare -gra _SESSION_MODES=("${SESSION_MODES[@]}")

# =============================================================================
# Internal: Batch Fetch tmux Variables
# =============================================================================

# Fetch all session-related tmux variables in a single call
# Returns: colon-separated values
# Format: session_name:client_prefix:pane_in_mode:search_present:pane_mode:client_session:session_grouped
_session_fetch_vars() {
    if [[ -z "${TMUX:-}" ]]; then
        printf ':0:0:0:::'
        return
    fi

    tmux display-message -p '#S:#{client_prefix}:#{pane_in_mode}:#{search_present}:#{pane_mode}:#{client_session}:#{session_grouped}' 2>/dev/null || printf ':0:0:0:::'
}

# Parse batch vars into individual variables
# Usage: _session_parse_vars "name:0:1:0:copy-mode:session:0"
# Sets: _SESSION_NAME, _SESSION_PREFIX, _SESSION_IN_MODE, _SESSION_SEARCH, _SESSION_PANE_MODE, _SESSION_CLIENT, _SESSION_GROUPED
_session_parse_vars() {
    local vars="$1"
    IFS=':' read -r _SESSION_NAME _SESSION_PREFIX _SESSION_IN_MODE _SESSION_SEARCH _SESSION_PANE_MODE _SESSION_CLIENT _SESSION_GROUPED <<< "$vars"

    # Default empty values to sensible defaults
    _SESSION_PREFIX="${_SESSION_PREFIX:-0}"
    _SESSION_IN_MODE="${_SESSION_IN_MODE:-0}"
    _SESSION_SEARCH="${_SESSION_SEARCH:-0}"
    _SESSION_GROUPED="${_SESSION_GROUPED:-0}"
}

# =============================================================================
# Session State Detection
# =============================================================================

# Get current session state
# Usage: session_get_state
session_get_state() {
    if [[ -z "${TMUX:-}" ]]; then
        printf 'detached'
        return
    fi

    local attached
    attached=$(tmux display-message -p '#{client_session}' 2>/dev/null)

    if [[ -n "$attached" ]]; then
        printf 'attached'
    else
        printf 'detached'
    fi
}

# Get current tmux mode (optimized: single tmux call)
# Usage: session_get_mode
session_get_mode() {
    if [[ -z "${TMUX:-}" ]]; then
        printf 'normal'
        return
    fi

    # Single batch call for all mode-related variables
    local vars prefix in_mode search pane_mode
    vars=$(tmux display-message -p '#{client_prefix}:#{pane_in_mode}:#{search_present}:#{pane_mode}' 2>/dev/null)
    IFS=':' read -r prefix in_mode search pane_mode <<< "$vars"

    # Default values
    prefix="${prefix:-0}"
    in_mode="${in_mode:-0}"
    search="${search:-0}"

    # Determine mode based on flags
    [[ "$prefix" == "1" ]] && { printf 'prefix'; return; }

    if [[ "$in_mode" == "1" ]]; then
        [[ "$search" == "1" ]] && { printf 'search'; return; }
        printf 'copy'
        return
    fi

    [[ "$pane_mode" == "command-mode" ]] && { printf 'command'; return; }

    printf 'normal'
}

# Get session context
# Usage: session_get_context
session_get_context() {
    local context=""

    if [[ -z "${TMUX:-}" ]]; then
        printf ''
        return
    fi

    # Check for window alerts (activity/bell)
    local alerts
    alerts=$(tmux list-windows -F '#{window_flags}' 2>/dev/null | grep -E '[#!~]' || true)
    [[ -n "$alerts" ]] && context+="alerts "

    # Check if session is part of a group
    local grouped
    grouped=$(tmux display-message -p '#{session_grouped}' 2>/dev/null || echo "0")
    [[ "$grouped" == "1" ]] && context+="grouped "

    printf '%s' "${context% }"  # Trim trailing space
}

# =============================================================================
# Session Rendering
# =============================================================================

# Get session name
# Usage: session_get_name
session_get_name() {
    if [[ -z "${TMUX:-}" ]]; then
        printf 'tmux'
        return
    fi

    tmux display-message -p '#S' 2>/dev/null || printf 'tmux'
}

# Render session indicator
# Usage: session_render
# Returns plain text - renderer adds colors/formatting
session_render() {
    session_get_name
}

# =============================================================================
# Session Format Strings (for tmux)
# =============================================================================

# Get tmux format string for mode-aware session display
# Returns tmux format string that can be used in status-left
session_get_mode_format() {
    cat << 'EOF'
#{?client_prefix,PREFIX,#{?pane_in_mode,#{?search_present,SEARCH,COPY},#S}}
EOF
}

# Get tmux conditional format for mode colors
# Usage: session_get_color_format "normal_color" "prefix_color" "copy_color"
session_get_color_format() {
    local normal="$1"
    local prefix="$2"
    local copy="$3"

    printf '#{?client_prefix,%s,#{?pane_in_mode,%s,%s}}' "$prefix" "$copy" "$normal"
}

# =============================================================================
# Session Icon Resolution
# =============================================================================

# Get appropriate icon for current mode
# Usage: session_get_icon
session_get_icon() {
    local mode
    mode=$(session_get_mode)

    # Default icons (can be overridden by options)
    local icon_normal icon_prefix icon_copy icon_command icon_search
    icon_normal=$(get_tmux_option "@powerkit_session_icon" $'\ue795')
    icon_prefix=$(get_tmux_option "@powerkit_session_prefix_icon" $'\uf11c')
    icon_copy=$(get_tmux_option "@powerkit_session_copy_icon" $'\uf0c5')
    icon_command=$(get_tmux_option "@powerkit_session_command_icon" $'\uf120')
    icon_search=$(get_tmux_option "@powerkit_session_search_icon" $'\uf002')

    case "$mode" in
        prefix)  printf '%s' "$icon_prefix" ;;
        copy)    printf '%s' "$icon_copy" ;;
        command) printf '%s' "$icon_command" ;;
        search)  printf '%s' "$icon_search" ;;
        *)       printf '%s' "$icon_normal" ;;
    esac
}

# Get icon based on already-computed mode (avoids duplicate tmux call)
# Usage: session_get_icon_for_mode "copy"
session_get_icon_for_mode() {
    local mode="$1"

    local icon_normal icon_prefix icon_copy icon_command icon_search
    icon_normal=$(get_tmux_option "@powerkit_session_icon" $'\ue795')
    icon_prefix=$(get_tmux_option "@powerkit_session_prefix_icon" $'\uf11c')
    icon_copy=$(get_tmux_option "@powerkit_session_copy_icon" $'\uf0c5')
    icon_command=$(get_tmux_option "@powerkit_session_command_icon" $'\uf120')
    icon_search=$(get_tmux_option "@powerkit_session_search_icon" $'\uf002')

    case "$mode" in
        prefix)  printf '%s' "$icon_prefix" ;;
        copy)    printf '%s' "$icon_copy" ;;
        command) printf '%s' "$icon_command" ;;
        search)  printf '%s' "$icon_search" ;;
        *)       printf '%s' "$icon_normal" ;;
    esac
}

# =============================================================================
# Batch Operations (Optimized)
# =============================================================================

# Get all session info at once (efficient: minimal tmux calls)
# Usage: eval "$(session_get_all)"
session_get_all() {
    if [[ -z "${TMUX:-}" ]]; then
        printf 'SESSION_STATE="detached"\n'
        printf 'SESSION_MODE="normal"\n'
        printf 'SESSION_CONTEXT=""\n'
        printf 'SESSION_NAME="tmux"\n'
        printf 'SESSION_ICON="%s"\n' $'\ue795'
        return
    fi

    # Single batch call for main variables
    local vars name prefix in_mode search pane_mode client grouped
    vars=$(tmux display-message -p '#S:#{client_prefix}:#{pane_in_mode}:#{search_present}:#{pane_mode}:#{client_session}:#{session_grouped}' 2>/dev/null)
    IFS=':' read -r name prefix in_mode search pane_mode client grouped <<< "$vars"

    # Default values
    prefix="${prefix:-0}"
    in_mode="${in_mode:-0}"
    search="${search:-0}"
    grouped="${grouped:-0}"
    name="${name:-tmux}"

    # Determine state
    local state="detached"
    [[ -n "$client" ]] && state="attached"

    # Determine mode (same logic as session_get_mode but without extra call)
    local mode="normal"
    if [[ "$prefix" == "1" ]]; then
        mode="prefix"
    elif [[ "$in_mode" == "1" ]]; then
        [[ "$search" == "1" ]] && mode="search" || mode="copy"
    elif [[ "$pane_mode" == "command-mode" ]]; then
        mode="command"
    fi

    # Build context (alerts still needs list-windows)
    local context=""
    local alerts
    alerts=$(tmux list-windows -F '#{window_flags}' 2>/dev/null | grep -E '[#!~]' || true)
    [[ -n "$alerts" ]] && context+="alerts "
    [[ "$grouped" == "1" ]] && context+="grouped "
    context="${context% }"

    # Get icon for mode
    local icon
    icon=$(session_get_icon_for_mode "$mode")

    # Output all variables
    printf 'SESSION_STATE="%s"\n' "$state"
    printf 'SESSION_MODE="%s"\n' "$mode"
    printf 'SESSION_CONTEXT="%s"\n' "$context"
    printf 'SESSION_NAME="%s"\n' "$name"
    printf 'SESSION_ICON="%s"\n' "$icon"
}

# =============================================================================
# Utility Functions
# =============================================================================

# Check if mode is valid
# Uses validate_against_enum from validation.sh
is_valid_mode() {
    local mode="$1"
    validate_against_enum "$mode" SESSION_MODES
}
