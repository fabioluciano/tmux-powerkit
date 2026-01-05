#!/usr/bin/env bash
# =============================================================================
# PowerKit Renderer: Main Orchestrator
# Description: Orchestrates the rendering of all tmux visual elements
# =============================================================================
# The renderer is the high-level orchestrator. It:
# - Configures global status bar settings
# - Delegates layout composition to compositor.sh
# - Configures non-status-bar elements (panes, messages, clock, modes)
#
# The renderer does NOT build status formats directly - that's the compositor's job.
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "renderer_main" && return 0

. "${POWERKIT_ROOT}/src/core/logger.sh"
. "${POWERKIT_ROOT}/src/core/options.sh"
. "${POWERKIT_ROOT}/src/core/lifecycle.sh"
. "${POWERKIT_ROOT}/src/renderer/color_resolver.sh"
. "${POWERKIT_ROOT}/src/renderer/separator.sh"
. "${POWERKIT_ROOT}/src/renderer/styles.sh"
. "${POWERKIT_ROOT}/src/renderer/compositor.sh"

# =============================================================================
# Status Bar Configuration
# =============================================================================

# Configure global status bar settings
# These are settings that apply regardless of layout
configure_status_bar() {
    log_debug "renderer" "Configuring status bar"

    # Status bar position
    local position
    position=$(get_tmux_option "@powerkit_status_position" "${POWERKIT_DEFAULT_STATUS_POSITION}")
    tmux set-option -g status-position "$position"

    # Status bar style
    local status_style
    status_style=$(build_status_style)
    tmux set-option -g status-style "$status_style"

    # Refresh interval
    local interval
    interval=$(get_tmux_option "@powerkit_status_interval" "${POWERKIT_DEFAULT_STATUS_INTERVAL}")
    tmux set-option -g status-interval "$interval"

    # Status bar lengths - ensure enough space for plugins and session
    # These are critical for proper display of all elements
    tmux set-option -g status-left-length "${POWERKIT_DEFAULT_STATUS_LEFT_LENGTH}"
    tmux set-option -g status-right-length "${POWERKIT_DEFAULT_STATUS_RIGHT_LENGTH}"

    log_debug "renderer" "Status bar configured"
}

# =============================================================================
# Pane Configuration
# =============================================================================

# Configure pane borders
configure_panes() {
    log_debug "renderer" "Configuring panes"

    # Pane border style
    local border_style
    border_style=$(build_pane_border_style "inactive")
    tmux set-option -g pane-border-style "$border_style"

    # Active pane border style
    local active_style
    active_style=$(build_pane_border_style "active")
    tmux set-option -g pane-active-border-style "$active_style"

    # Pane border lines (tmux 3.2+)
    local border_lines
    border_lines=$(get_tmux_option "@powerkit_pane_border_lines" "${POWERKIT_DEFAULT_PANE_BORDER_LINES}")
    tmux set-option -g pane-border-lines "$border_lines" 2>/dev/null || true

    # Pane border status (off, top, bottom)
    local border_status
    border_status=$(get_tmux_option "@powerkit_pane_border_status" "${POWERKIT_DEFAULT_PANE_BORDER_STATUS}")
    tmux set-option -g pane-border-status "$border_status" 2>/dev/null || true

    # Pane border format (when status is enabled)
    if [[ "$border_status" != "off" ]]; then
        local border_format active_fg inactive_fg status_bg
        border_format=$(get_tmux_option "@powerkit_pane_border_format" "${POWERKIT_DEFAULT_PANE_BORDER_FORMAT}")

        # Get theme colors
        active_fg=$(resolve_color "pane-border-active")
        inactive_fg=$(resolve_color "pane-border-inactive")
        status_bg=$(get_tmux_option "@powerkit_pane_border_status_bg" "${POWERKIT_DEFAULT_PANE_BORDER_STATUS_BG}")

        # Replace placeholders with tmux variables using sed for reliable substitution
        # Basic placeholders
        border_format=$(printf '%s' "$border_format" | sed \
            -e 's/{index}/#{pane_index}/g' \
            -e 's/{title}/#{pane_title}/g' \
            -e 's/{command}/#{pane_current_command}/g' \
            -e 's/{path}/#{pane_current_path}/g' \
            -e 's/{basename}/#{b:pane_current_path}/g' \
            -e 's/{active}/#{?pane_active,▶,}/g')

        # Build format with conditional colors and styles
        # Active pane: bold text, active color
        # Inactive pane: normal text, inactive color
        local final_format bg_style=""

        # Apply background if specified and not "none"
        if [[ -n "$status_bg" && "$status_bg" != "none" ]]; then
            local resolved_bg
            resolved_bg=$(resolve_color "$status_bg")
            bg_style="#[bg=${resolved_bg}]"
        fi

        final_format="${bg_style}#{?pane_active,#[fg=${active_fg}]#[bold],#[fg=${inactive_fg}]} ${border_format} #[default]"

        tmux set-option -g pane-border-format "$final_format"
    fi

    log_debug "renderer" "Panes configured"
}

# =============================================================================
# Message Configuration
# =============================================================================

# Configure message style
configure_messages() {
    log_debug "renderer" "Configuring messages"

    # Message style
    local msg_style
    msg_style=$(build_message_style)
    tmux set-option -g message-style "$msg_style"

    # Command message style
    local cmd_style
    cmd_style=$(build_message_command_style)
    tmux set-option -g message-command-style "$cmd_style"

    log_debug "renderer" "Messages configured"
}

# =============================================================================
# Clock Configuration
# =============================================================================

# Configure clock mode
configure_clock() {
    log_debug "renderer" "Configuring clock"

    local clock_color
    clock_color=$(build_clock_format)
    tmux set-option -g clock-mode-colour "$clock_color"

    local clock_style
    clock_style=$(get_tmux_option "@powerkit_clock_style" "${POWERKIT_DEFAULT_CLOCK_STYLE}")
    tmux set-option -g clock-mode-style "$clock_style"

    log_debug "renderer" "Clock configured"
}

# =============================================================================
# Mode Configuration
# =============================================================================

# Configure copy mode and other modes
configure_modes() {
    log_debug "renderer" "Configuring modes"

    # Mode style (copy mode highlight)
    local mode_style
    mode_style=$(build_mode_style)
    tmux set-option -g mode-style "$mode_style"

    log_debug "renderer" "Modes configured"
}

# =============================================================================
# Popup and Menu Configuration
# =============================================================================

# Configure popup and menu styles
configure_popups_and_menus() {
    log_debug "renderer" "Configuring popups and menus"

    # Popup style
    local popup_style
    popup_style=$(build_popup_style)
    tmux set-option -g popup-style "$popup_style"

    # Popup border style
    local popup_border_style
    popup_border_style=$(build_popup_border_style)
    tmux set-option -g popup-border-style "$popup_border_style"

    # Popup border lines
    local popup_border_lines
    popup_border_lines=$(get_tmux_option "@powerkit_popup_border_lines" "${POWERKIT_DEFAULT_POPUP_BORDER_LINES}")
    tmux set-option -g popup-border-lines "$popup_border_lines" 2>/dev/null || true

    # Menu style
    local menu_style
    menu_style=$(build_menu_style)
    tmux set-option -g menu-style "$menu_style"

    # Menu selected style
    local menu_selected_style
    menu_selected_style=$(build_menu_selected_style)
    tmux set-option -g menu-selected-style "$menu_selected_style"

    # Menu border style
    local menu_border_style
    menu_border_style=$(build_menu_border_style)
    tmux set-option -g menu-border-style "$menu_border_style"

    # Menu border lines
    local menu_border_lines
    menu_border_lines=$(get_tmux_option "@powerkit_menu_border_lines" "${POWERKIT_DEFAULT_MENU_BORDER_LINES}")
    tmux set-option -g menu-border-lines "$menu_border_lines" 2>/dev/null || true

    log_debug "renderer" "Popups and menus configured"
}

# =============================================================================
# Full Render
# =============================================================================

# Run full render - applies all configurations
render_all() {
    log_info "renderer" "Starting full render"

    # Global status bar settings
    configure_status_bar

    # Layout composition (handles status-left, status-right, status-format, windows)
    compose_layout

    # Non-status-bar elements
    configure_panes
    configure_messages
    configure_clock
    configure_modes
    configure_popups_and_menus

    log_info "renderer" "Full render complete"
}

# Render only status bar (for updates)
render_status() {
    log_debug "renderer" "Rendering status bar"

    compose_layout

    log_debug "renderer" "Status bar rendered"
}

# Render with theme reload
render_with_theme() {
    log_info "renderer" "Rendering with theme reload"

    # Reload theme
    reload_theme

    # Render all
    render_all

    log_info "renderer" "Render with theme complete"
}

# =============================================================================
# Refresh Functions
# =============================================================================

# Refresh status bar (minimal update)
refresh_status() {
    tmux refresh-client -S 2>/dev/null || true
}

# Force full refresh
refresh_all() {
    render_all
    refresh_status
}

# =============================================================================
# Entry Points
# =============================================================================

# Initialize and render
init_renderer() {
    log_info "renderer" "Initializing renderer"

    # Make sure theme is loaded
    is_theme_loaded || load_powerkit_theme

    # Run full render
    render_all

    log_info "renderer" "Renderer initialized"
}

# Called by tmux-powerkit.tmux
run_powerkit() {
    init_renderer
}
