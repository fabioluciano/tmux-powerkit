#!/usr/bin/env bash
# =============================================================================
# PowerKit Renderer: Main Orchestrator
# Description: Main renderer that applies all formats to tmux
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
. "${POWERKIT_ROOT}/src/renderer/segment_builder.sh"
. "${POWERKIT_ROOT}/src/renderer/format_builder.sh"

# =============================================================================
# Status Bar Configuration
# =============================================================================

# Configure status bar settings
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

    # Status bar length
    local left_length right_length
    left_length=$(get_tmux_option "@powerkit_status_left_length" "${POWERKIT_DEFAULT_STATUS_LEFT_LENGTH}")
    right_length=$(get_tmux_option "@powerkit_status_right_length" "${POWERKIT_DEFAULT_STATUS_RIGHT_LENGTH}")
    tmux set-option -g status-left-length "$left_length"
    tmux set-option -g status-right-length "$right_length"

    # Refresh interval
    local interval
    interval=$(get_tmux_option "@powerkit_status_interval" "${POWERKIT_DEFAULT_STATUS_INTERVAL}")
    tmux set-option -g status-interval "$interval"

    # Justify (window list position)
    local justify
    justify=$(get_tmux_option "@powerkit_status_justify" "${POWERKIT_DEFAULT_STATUS_JUSTIFY}")
    tmux set-option -g status-justify "$justify"

    log_debug "renderer" "Status bar configured"
}

# =============================================================================
# Status Left/Right Configuration
# =============================================================================

# Configure status-left
configure_status_left() {
    log_debug "renderer" "Configuring status-left"

    local format
    format=$(build_status_left_format)

    tmux set-option -g status-left "$format"

    log_debug "renderer" "status-left configured"
}

# Configure status-right
configure_status_right() {
    log_debug "renderer" "Configuring status-right"

    # NOTE: Plugin lifecycle runs in powerkit-render, not here
    # This avoids slow initialization - plugins are rendered on-demand with caching

    # Build format (just sets up #(powerkit-render) call)
    local format
    format=$(build_status_right_format)

    tmux set-option -g status-right "$format"

    log_debug "renderer" "status-right configured"
}

# =============================================================================
# Window Configuration
# =============================================================================

# Configure window formats
configure_windows() {
    log_debug "renderer" "Configuring windows"

    # Window status format (inactive)
    local window_format
    window_format=$(build_window_format)
    tmux set-option -g window-status-format "$window_format"

    # Window status current format (active)
    local current_format
    current_format=$(build_window_current_format)
    tmux set-option -g window-status-current-format "$current_format"

    # Window separator
    local separator
    separator=$(build_window_separator_format)
    tmux set-option -g window-status-separator "$separator"

    # Window status style
    tmux set-option -g window-status-style "default"
    tmux set-option -g window-status-current-style "default"

    # Window activity/bell styles (applied automatically by tmux)
    local activity_style bell_style
    activity_style=$(resolve_color "window-activity-style")
    bell_style=$(resolve_color "window-bell-style")
    # Fallback to reasonable defaults if not defined in theme
    [[ -z "$activity_style" || "$activity_style" == "default" || "$activity_style" == "none" ]] && activity_style="italics"
    [[ -z "$bell_style" || "$bell_style" == "default" || "$bell_style" == "none" ]] && bell_style="bold"
    tmux set-window-option -g window-status-activity-style "$activity_style"
    tmux set-window-option -g window-status-bell-style "$bell_style"

    log_debug "renderer" "Windows configured"
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

    # Pane border lines
    local border_lines
    border_lines=$(get_tmux_option "@powerkit_pane_border_lines" "${POWERKIT_DEFAULT_PANE_BORDER_LINES}")
    # Note: pane-border-lines is tmux 3.2+
    tmux set-option -g pane-border-lines "$border_lines" 2>/dev/null || true

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
    local mode_bg mode_fg
    mode_bg=$(resolve_color "session-copy-bg")
    mode_fg=$(resolve_color "session-fg")
    tmux set-option -g mode-style "fg=${mode_fg},bg=${mode_bg}"

    log_debug "renderer" "Modes configured"
}

# =============================================================================
# Full Render
# =============================================================================

# Run full render - applies all configurations
render_all() {
    log_info "renderer" "Starting full render"

    configure_status_bar
    configure_status_left
    configure_status_right
    configure_windows
    configure_panes
    configure_messages
    configure_clock
    configure_modes

    log_info "renderer" "Full render complete"
}

# Render only status bar (for updates)
render_status() {
    log_debug "renderer" "Rendering status bar"

    configure_status_left
    configure_status_right

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
