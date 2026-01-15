#!/usr/bin/env bash
# =============================================================================
#  PANE CONTRACT
#  Pane contract interface for visual effects, styling, and state management
# =============================================================================
#
# TABLE OF CONTENTS
# =================
#   1. Overview
#   2. Pane States
#   3. Flash Effect
#   4. Pane Information
#   5. Border Styling
#   6. Border Format
#   7. Synchronized Panes
#   8. Scrollbars
#   9. Configuration
#   10. API Reference
#
# =============================================================================
#
# 1. OVERVIEW
# ===========
#
# The Pane Contract defines the interface for ALL pane-related functionality
# in tmux, including visual effects, styling, and state management.
#
# Key Features:
#   - Pane flash effect on selection (visual feedback)
#   - Pane state detection (active, inactive, zoomed)
#   - Pane border styling (colors, lines, status)
#   - Pane border format with placeholders
#   - Synchronized panes indicator
#   - Scrollbars with theme colors (tmux 3.4+)
#   - Complete pane configuration
#
# Configuration (in tmux.conf):
#   # Flash effect
#   set -g @powerkit_pane_flash_enabled "true"
#   set -g @powerkit_pane_flash_color "info-base"
#   set -g @powerkit_pane_flash_duration "100"
#
#   # Border styling
#   set -g @powerkit_pane_border_lines "single"
#   set -g @powerkit_pane_border_unified "false"
#   set -g @powerkit_active_pane_border_color "pane-border-active"
#   set -g @powerkit_inactive_pane_border_color "pane-border-inactive"
#
#   # Border status
#   set -g @powerkit_pane_border_status "off"
#   set -g @powerkit_pane_border_format "{active} {command}"
#
#   # Scrollbars (tmux 3.4+)
#   set -g @powerkit_pane_scrollbars "modal"
#   set -g @powerkit_pane_scrollbars_position "right"
#   set -g @powerkit_pane_scrollbars_style_fg "pane-border-active"
#   set -g @powerkit_pane_scrollbars_style_bg "pane-border-inactive"
#
# =============================================================================
#
# 2. API REFERENCE
# ================
#
#   Flash Effect:
#     pane_flash_enable()           - Enable pane flash on selection
#     pane_flash_disable()          - Disable pane flash
#     pane_flash_is_enabled()       - Check if flash is enabled
#     pane_flash_trigger()          - Manually trigger flash effect
#     pane_flash_setup()            - Setup flash hook (called by bootstrap)
#
#   Pane State:
#     pane_get_state()              - Get current pane state
#     pane_is_active()              - Check if pane is active
#     pane_is_zoomed()              - Check if pane is zoomed
#
#   Pane Information:
#     pane_get_id()                 - Get current pane ID
#     pane_get_index()              - Get pane index
#     pane_get_title()              - Get pane title
#     pane_get_command()            - Get current command
#     pane_get_path()               - Get current path
#     pane_get_all()                - Get all pane info (batch)
#
#   Border Styling:
#     pane_border_color(type)       - Get border color for active/inactive
#     pane_border_style(type)       - Get border style string "fg=COLOR"
#
#   Border Format:
#     pane_resolve_format_placeholders(format) - Resolve {index}, {title}, etc.
#     pane_build_border_format()    - Build complete border format with colors
#
#   Synchronized Panes:
#     pane_get_sync_icon()          - Get synchronized pane icon
#     pane_sync_format()            - Get tmux format "#{?pane_synchronized,...}"
#
#   Scrollbars:
#     pane_scrollbars_style()       - Build scrollbar style string "fg=...,bg=..."
#
#   Configuration:
#     pane_configure()              - Apply all pane settings to tmux
#
# =============================================================================
# END OF DOCUMENTATION
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "contract_pane" && return 0

# Note: All core and utils modules are loaded by bootstrap.sh

# =============================================================================
# Pane States
# =============================================================================

# Valid pane states
declare -gra PANE_STATES=("active" "inactive" "zoomed")

# =============================================================================
# Flash Effect - Core Functions
# =============================================================================

# Trigger the flash effect on the current pane
# Usage: pane_flash_trigger [color] [duration_ms]
pane_flash_trigger() {
    local color="${1:-}"
    local duration_ms="${2:-}"

    # Get options if not provided
    [[ -z "$color" ]] && color=$(get_tmux_option "@powerkit_pane_flash_color" "${POWERKIT_DEFAULT_PANE_FLASH_COLOR:-info-base}")
    [[ -z "$duration_ms" ]] && duration_ms=$(get_tmux_option "@powerkit_pane_flash_duration" "${POWERKIT_DEFAULT_PANE_FLASH_DURATION:-100}")

    # Resolve color from theme if it's a theme color name
    local resolved_color
    resolved_color=$(_pane_resolve_color "$color")

    # Calculate delay in seconds
    local delay_s
    delay_s=$(echo "scale=3; $duration_ms / 1000" | bc 2>/dev/null || echo "0.1")

    # Apply flash effect
    tmux set -w window-active-style "bg=$resolved_color"

    # Schedule reset
    (sleep "$delay_s" && tmux set -w window-active-style '') &
    disown 2>/dev/null || true
}

# Check if pane flash is enabled
# Usage: pane_flash_is_enabled
pane_flash_is_enabled() {
    local enabled
    enabled=$(get_tmux_option "@powerkit_pane_flash_enabled" "${POWERKIT_DEFAULT_PANE_FLASH_ENABLED:-false}")
    [[ "$enabled" == "true" ]]
}

# Enable pane flash effect
# Usage: pane_flash_enable
pane_flash_enable() {
    set_tmux_option "@powerkit_pane_flash_enabled" "true"
    pane_flash_setup
    log_info "pane" "Pane flash enabled"
}

# Disable pane flash effect
# Usage: pane_flash_disable
pane_flash_disable() {
    set_tmux_option "@powerkit_pane_flash_enabled" "false"
    _pane_flash_teardown
    log_info "pane" "Pane flash disabled"
}

# Setup the flash hook (called during bootstrap)
# Usage: pane_flash_setup
pane_flash_setup() {
    pane_flash_is_enabled || return 0

    local color duration_ms
    color=$(get_tmux_option "@powerkit_pane_flash_color" "${POWERKIT_DEFAULT_PANE_FLASH_COLOR:-info-base}")
    duration_ms=$(get_tmux_option "@powerkit_pane_flash_duration" "${POWERKIT_DEFAULT_PANE_FLASH_DURATION:-100}")

    # Resolve color
    local resolved_color
    resolved_color=$(_pane_resolve_color "$color")

    # Calculate delay
    local delay_s
    delay_s=$(echo "scale=3; $duration_ms / 1000" | bc 2>/dev/null || echo "0.1")

    # Build the hook command
    # The hook sets the background, then resets it after the delay
    local hook_cmd
    hook_cmd="run-shell 'tmux set -w window-active-style \"bg=$resolved_color\"; sleep $delay_s; tmux set -w window-active-style \"\"'"

    # Register the hook
    tmux set-hook -g after-select-pane "$hook_cmd" 2>/dev/null || {
        log_error "pane" "Failed to setup pane flash hook"
        return 1
    }

    log_debug "pane" "Pane flash hook registered (color=$resolved_color, duration=${duration_ms}ms)"
    return 0
}

# Internal: Teardown the flash hook
# Usage: _pane_flash_teardown
_pane_flash_teardown() {
    tmux set-hook -gu after-select-pane 2>/dev/null || true
    # Reset any lingering style
    tmux set -w window-active-style '' 2>/dev/null || true
    log_debug "pane" "Pane flash hook removed"
}

# Internal: Resolve color from theme or return as-is
# Usage: _pane_resolve_color "info-base"
_pane_resolve_color() {
    local color="$1"

    # If it's already a hex color, return as-is
    [[ "$color" =~ ^#[0-9A-Fa-f]{6}$ ]] && { printf '%s' "$color"; return; }

    # Try to resolve from theme
    if declare -F resolve_color &>/dev/null; then
        local resolved
        resolved=$(resolve_color "$color" 2>/dev/null)
        [[ -n "$resolved" ]] && { printf '%s' "$resolved"; return; }
    fi

    # Fallback: return as-is (might be a tmux color name)
    printf '%s' "$color"
}

# =============================================================================
# Pane State Detection
# =============================================================================

# Get current pane state
# Returns: "active", "inactive", or "zoomed"
pane_get_state() {
    if [[ -z "${TMUX:-}" ]]; then
        printf 'inactive'
        return
    fi

    local vars active zoomed
    vars=$(tmux display-message -p '#{pane_active}:#{window_zoomed_flag}' 2>/dev/null)
    IFS=':' read -r active zoomed <<< "$vars"

    [[ "$zoomed" == "1" ]] && { printf 'zoomed'; return; }
    [[ "$active" == "1" ]] && { printf 'active'; return; }
    printf 'inactive'
}

# Check if current pane is active
# Usage: pane_is_active
pane_is_active() {
    [[ -z "${TMUX:-}" ]] && return 1

    local active
    active=$(tmux display-message -p '#{pane_active}' 2>/dev/null)
    [[ "$active" == "1" ]]
}

# Check if current pane is zoomed
# Usage: pane_is_zoomed
pane_is_zoomed() {
    [[ -z "${TMUX:-}" ]] && return 1

    local zoomed
    zoomed=$(tmux display-message -p '#{window_zoomed_flag}' 2>/dev/null)
    [[ "$zoomed" == "1" ]]
}

# =============================================================================
# Pane Information
# =============================================================================

# Get current pane ID
# Usage: pane_get_id
pane_get_id() {
    [[ -z "${TMUX:-}" ]] && { printf ''; return; }
    tmux display-message -p '#{pane_id}' 2>/dev/null
}

# Get current pane index
# Usage: pane_get_index
pane_get_index() {
    [[ -z "${TMUX:-}" ]] && { printf '0'; return; }
    tmux display-message -p '#{pane_index}' 2>/dev/null
}

# Get current pane title
# Usage: pane_get_title
pane_get_title() {
    [[ -z "${TMUX:-}" ]] && { printf ''; return; }
    tmux display-message -p '#{pane_title}' 2>/dev/null
}

# Get current command running in pane
# Usage: pane_get_command
pane_get_command() {
    [[ -z "${TMUX:-}" ]] && { printf ''; return; }
    tmux display-message -p '#{pane_current_command}' 2>/dev/null
}

# Get current path of pane
# Usage: pane_get_path
pane_get_path() {
    [[ -z "${TMUX:-}" ]] && { printf ''; return; }
    tmux display-message -p '#{pane_current_path}' 2>/dev/null
}

# Get all pane info at once (efficient: single tmux call)
# Usage: eval "$(pane_get_all)"
pane_get_all() {
    if [[ -z "${TMUX:-}" ]]; then
        printf 'PANE_ID=""\n'
        printf 'PANE_INDEX="0"\n'
        printf 'PANE_TITLE=""\n'
        printf 'PANE_COMMAND=""\n'
        printf 'PANE_PATH=""\n'
        printf 'PANE_STATE="inactive"\n'
        return
    fi

    local vars id index title command path active zoomed
    vars=$(tmux display-message -p '#{pane_id}:#{pane_index}:#{pane_title}:#{pane_current_command}:#{pane_current_path}:#{pane_active}:#{window_zoomed_flag}' 2>/dev/null)
    IFS=':' read -r id index title command path active zoomed <<< "$vars"

    # Determine state
    local state="inactive"
    [[ "$zoomed" == "1" ]] && state="zoomed"
    [[ "$active" == "1" && "$zoomed" != "1" ]] && state="active"

    printf 'PANE_ID="%s"\n' "$id"
    printf 'PANE_INDEX="%s"\n' "$index"
    printf 'PANE_TITLE="%s"\n' "$title"
    printf 'PANE_COMMAND="%s"\n' "$command"
    printf 'PANE_PATH="%s"\n' "$path"
    printf 'PANE_STATE="%s"\n' "$state"
}

# =============================================================================
# Pane Border Styling
# =============================================================================

# Build pane border color
# Usage: pane_border_color "active|inactive"
pane_border_color() {
    local type="${1:-inactive}"
    local unified
    unified=$(get_tmux_option '@powerkit_pane_border_unified' "${POWERKIT_DEFAULT_PANE_BORDER_UNIFIED}")

    if [[ "$unified" == "true" ]]; then
        resolve_color "$(get_tmux_option '@powerkit_pane_border_color' "${POWERKIT_DEFAULT_PANE_BORDER_COLOR}")"
    elif [[ "$type" == "active" ]]; then
        resolve_color "$(get_tmux_option '@powerkit_active_pane_border_color' "${POWERKIT_DEFAULT_ACTIVE_PANE_BORDER_COLOR}")"
    else
        resolve_color "$(get_tmux_option '@powerkit_inactive_pane_border_color' "${POWERKIT_DEFAULT_INACTIVE_PANE_BORDER_COLOR}")"
    fi
}

# Build pane border style string
# Usage: pane_border_style "active|inactive"
# Returns: "fg=COLOR"
pane_border_style() {
    local type="${1:-inactive}"
    if [[ "$type" == "active" ]]; then
        printf 'fg=%s' "$(pane_border_color "$type")"
    elif [[ "$type" == "inactive" ]]; then
        printf '#{?pane_synchronized,fg=%s,fg=%s}' "$(pane_border_color "active")" "$(pane_border_color "inactive")"
    fi
}

# =============================================================================
# Pane Border Format
# =============================================================================

# Resolve border format placeholders
# Usage: pane_resolve_format_placeholders "format_string"
# Converts: {index}, {title}, {command}, {path}, {basename}, {active}
pane_resolve_format_placeholders() {
    local format="$1"
    printf '%s' "$format" | sed \
        -e 's/{index}/#{pane_index}/g' \
        -e 's/{title}/#{pane_title}/g' \
        -e 's/{command}/#{pane_current_command}/g' \
        -e 's/{path}/#{pane_current_path}/g' \
        -e 's/{basename}/#{b:pane_current_path}/g' \
        -e 's/{active}/#{?pane_active,▶,}/g'
}

# Build complete pane border format with colors
# Usage: pane_build_border_format
pane_build_border_format() {
    local border_format active_fg inactive_fg status_bg
    border_format=$(get_tmux_option "@powerkit_pane_border_format" "${POWERKIT_DEFAULT_PANE_BORDER_FORMAT}")

    active_fg=$(resolve_color "pane-border-active")
    inactive_fg=$(resolve_color "pane-border-inactive")
    status_bg=$(get_tmux_option "@powerkit_pane_border_status_bg" "${POWERKIT_DEFAULT_PANE_BORDER_STATUS_BG}")

    # Resolve placeholders
    border_format=$(pane_resolve_format_placeholders "$border_format")

    # Build background style
    local bg_style=""
    if [[ -n "$status_bg" && "$status_bg" != "none" ]]; then
        local resolved_bg
        resolved_bg=$(resolve_color "$status_bg")
        bg_style="#[bg=${resolved_bg}]"
    fi

    # Return format with conditional colors
    printf '%s#{?pane_active,#[fg=%s]#[bold],#[fg=%s]} %s #[default]' \
        "$bg_style" "$active_fg" "$inactive_fg" "$border_format"
}

# =============================================================================
# Synchronized Panes
# =============================================================================

# Get synchronized pane icon
# Usage: pane_get_sync_icon
pane_get_sync_icon() {
    get_tmux_option "@powerkit_pane_synchronized_icon" "${POWERKIT_DEFAULT_PANE_SYNCHRONIZED_ICON}"
}

# Get tmux format string for synchronized panes indicator
# Usage: pane_sync_format
# Returns: "#{?pane_synchronized,ICON,}"
pane_sync_format() {
    local icon
    icon=$(pane_get_sync_icon)
    printf '#{?pane_synchronized,%s,}' "$icon"
}

# =============================================================================
# Pane Scrollbars
# =============================================================================

# Build pane scrollbars style string
# Usage: pane_scrollbars_style
# Returns: "fg=COLOR,bg=COLOR,width=N,pad=N"
pane_scrollbars_style() {
    local fg_color bg_color width pad

    fg_color=$(get_tmux_option "@powerkit_pane_scrollbars_style_fg" "${POWERKIT_DEFAULT_PANE_SCROLLBARS_STYLE_FG}")
    bg_color=$(get_tmux_option "@powerkit_pane_scrollbars_style_bg" "${POWERKIT_DEFAULT_PANE_SCROLLBARS_STYLE_BG}")
    width=$(get_tmux_option "@powerkit_pane_scrollbars_width" "${POWERKIT_DEFAULT_PANE_SCROLLBARS_WIDTH}")
    pad=$(get_tmux_option "@powerkit_pane_scrollbars_pad" "${POWERKIT_DEFAULT_PANE_SCROLLBARS_PAD}")

    # Resolve colors from theme
    local resolved_fg resolved_bg
    resolved_fg=$(_pane_resolve_color "$fg_color")
    resolved_bg=$(_pane_resolve_color "$bg_color")

    printf 'fg=%s,bg=%s,width=%s,pad=%s' "$resolved_fg" "$resolved_bg" "$width" "$pad"
}

# =============================================================================
# Pane Configuration
# =============================================================================

# Configure all pane settings in tmux
# Usage: pane_configure
pane_configure() {
    log_debug "pane" "Configuring panes"

    # Border styles
    tmux set-option -g pane-border-style "$(pane_border_style "inactive")"
    tmux set-option -g pane-active-border-style "$(pane_border_style "active")"

    # Border lines (tmux 3.2+)
    local border_lines
    border_lines=$(get_tmux_option "@powerkit_pane_border_lines" "${POWERKIT_DEFAULT_PANE_BORDER_LINES}")
    tmux set-option -g pane-border-lines "$border_lines" 2>/dev/null || true

    # Border status (off, top, bottom)
    local border_status
    border_status=$(get_tmux_option "@powerkit_pane_border_status" "${POWERKIT_DEFAULT_PANE_BORDER_STATUS}")
    tmux set-option -g pane-border-status "$border_status" 2>/dev/null || true

    # Border format (when status is enabled)
    if [[ "$border_status" != "off" ]]; then
        tmux set-option -g pane-border-format "$(pane_build_border_format)"
    fi

    # Scrollbars (tmux 3.4+)
    local scrollbars
    scrollbars=$(get_tmux_option "@powerkit_pane_scrollbars" "${POWERKIT_DEFAULT_PANE_SCROLLBARS}")
    if [[ "$scrollbars" != "off" ]]; then
        tmux set-option -g pane-scrollbars "$scrollbars" 2>/dev/null || true

        local scrollbars_position
        scrollbars_position=$(get_tmux_option "@powerkit_pane_scrollbars_position" "${POWERKIT_DEFAULT_PANE_SCROLLBARS_POSITION}")
        tmux set-option -g pane-scrollbars-position "$scrollbars_position" 2>/dev/null || true

        tmux set-option -g pane-scrollbars-style "$(pane_scrollbars_style)" 2>/dev/null || true
    else
        tmux set-option -g pane-scrollbars "off" 2>/dev/null || true
    fi

    log_debug "pane" "Panes configured"
}

# =============================================================================
# Utility Functions
# =============================================================================

# Check if state is valid
# Usage: is_valid_pane_state "active"
is_valid_pane_state() {
    local state="$1"
    local s
    for s in "${PANE_STATES[@]}"; do
        [[ "$s" == "$state" ]] && return 0
    done
    return 1
}
