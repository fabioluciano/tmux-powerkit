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
# Status Order Configuration
# =============================================================================

# Check if using custom status order (plugins first instead of session first)
_is_custom_order() {
    local order
    order=$(get_tmux_option "@powerkit_status_order" "${POWERKIT_DEFAULT_STATUS_ORDER}")
    # Custom order is when plugins come before session
    [[ "$order" == "plugins,session" ]]
}

# Build status format from order
# Builds a complete status-format string based on the specified element order
# Elements: session (includes windows), plugins
# Separator direction is determined by element position:
# - Elements on the LEFT side use RIGHT-pointing separators (▶)
# - Elements on the RIGHT side use LEFT-pointing separators (◀)
_build_ordered_status_format() {
    local order="$1"
    local status_bg
    status_bg=$(resolve_color "statusbar-bg")

    local result=""
    local elements
    IFS=',' read -ra elements <<< "$order"

    local element_count=${#elements[@]}
    local current_idx=0
    local is_last=0

    for element in "${elements[@]}"; do
        element=$(echo "$element" | tr -d ' ')  # trim whitespace
        is_last=$(( (current_idx + 1) == element_count ? 1 : 0 ))

        # Determine which side this element is on
        # First element = left side, last element = right side
        local element_side
        if [[ $is_last -eq 1 ]]; then
            element_side="right"
        else
            element_side="left"
        fi

        # Right-align the last element
        if [[ $is_last -eq 1 ]]; then
            result+="#[align=right]"
        fi

        case "$element" in
            session)
                # Session includes windows as a single entity
                # Pass the side to get correct separator direction
                local session_format
                session_format=$(build_status_left_format "$element_side")

                # Window list with proper list markers for click handling
                # list=on: marks start of window list (enables click detection)
                # list=focus: marks the focused window area
                # nolist: marks end of window list
                local windows_format="#[list=on]#{W:#[range=window|#{window_id}]#{T:window-status-format}#[norange],#[range=window|#{window_id} list=focus]#{T:window-status-current-format}#[norange]}#[nolist]"

                # Order depends on side:
                # - Left side: session → windows (session first, flowing right)
                # - Right side: windows → session (windows first, session at the end)
                if [[ "$element_side" == "right" ]]; then
                    result+="${windows_format}${session_format}"
                else
                    result+="${session_format}${windows_format}"
                fi
                ;;
            plugins)
                # Plugins use #() which calls powerkit-render
                # powerkit-render will detect the side from @powerkit_status_order
                local plugins_format
                plugins_format=$(build_status_right_format)
                result+="${plugins_format}"
                ;;
        esac

        ((current_idx++))
    done

    printf '%s' "$result"
}

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

    # Status bar layout (single or double)
    local bar_layout
    bar_layout=$(get_tmux_option "@powerkit_bar_layout" "${POWERKIT_DEFAULT_BAR_LAYOUT}")
    if [[ "$bar_layout" == "double" ]]; then
        tmux set-option -g status 2
    elif _is_custom_order; then
        # Custom order uses status-format[0] for single line
        tmux set-option -g status on
        # Clear status-format[1] in case we're switching from double
        tmux set-option -gu status-format[1] 2>/dev/null || true
    else
        tmux set-option -g status on
        # Reset status-format to tmux defaults when using standard layout
        tmux set-option -gu status-format 2>/dev/null || true
    fi

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
    # Skip if custom order - handled in configure_status_right()
    if ! _is_custom_order; then
        local justify
        justify=$(get_tmux_option "@powerkit_status_justify" "${POWERKIT_DEFAULT_STATUS_JUSTIFY}")
        tmux set-option -g status-justify "$justify"
    fi

    log_debug "renderer" "Status bar configured (layout: $bar_layout)"
}

# =============================================================================
# Status Left/Right Configuration
# =============================================================================

# Configure status-left
configure_status_left() {
    log_debug "renderer" "Configuring status-left"

    local bar_layout
    bar_layout=$(get_tmux_option "@powerkit_bar_layout" "${POWERKIT_DEFAULT_BAR_LAYOUT}")

    local format
    format=$(build_status_left_format)

    if [[ "$bar_layout" == "double" ]] || _is_custom_order; then
        # In double layout or custom order, status-left is handled via status-format
        tmux set-option -g status-left ""
    else
        tmux set-option -g status-left "$format"
    fi

    log_debug "renderer" "status-left configured"
}

# Configure status-right
configure_status_right() {
    log_debug "renderer" "Configuring status-right"

    local bar_layout status_order
    bar_layout=$(get_tmux_option "@powerkit_bar_layout" "${POWERKIT_DEFAULT_BAR_LAYOUT}")
    status_order=$(get_tmux_option "@powerkit_status_order" "${POWERKIT_DEFAULT_STATUS_ORDER}")

    # NOTE: Plugin lifecycle runs in powerkit-render, not here
    # This avoids slow initialization - plugins are rendered on-demand with caching

    local left_format right_format
    left_format=$(build_status_left_format)
    right_format=$(build_status_right_format)

    local status_bg
    status_bg=$(resolve_color "statusbar-bg")

    if [[ "$bar_layout" == "double" ]]; then
        # Double layout:
        # Line 0 (top): Session + Windows
        # Line 1 (bottom): Plugins only (right-aligned)
        # Window list with proper list markers for click handling
        local windows_format="#[list=on]#{W:#[range=window|#{window_id}]#{T:window-status-format}#[norange],#[range=window|#{window_id} list=focus]#{T:window-status-current-format}#[norange]}#[nolist]"

        local line0="${left_format}${windows_format}"
        tmux set-option -g status-format[0] "$line0"

        # Second line: plugins only (right-aligned)
        local line1="#[bg=${status_bg}]#[align=right]${right_format}"
        tmux set-option -g status-format[1] "$line1"

        # Clear standard status-left/right since we use status-format
        tmux set-option -g status-left ""
        tmux set-option -g status-right ""

    elif _is_custom_order; then
        # Custom order (plugins,session): use standard status-left/right mechanism
        # with status-justify right to push windows next to session
        # This maintains click functionality which breaks with #[align=right] in status-format

        # Plugins go in status-left
        tmux set-option -g status-left "$right_format"

        # Session goes in status-right (session only, no windows)
        local session_format
        session_format=$(build_status_left_format "right")
        tmux set-option -g status-right "$session_format"

        # Use status-justify right to push windows adjacent to status-right (session)
        tmux set-option -g status-justify "right"

        # Reset status-format to let tmux build it from status-left/right
        tmux set-option -gu status-format 2>/dev/null || true

    else
        # Standard single layout: session | windows | plugins
        tmux set-option -g status-right "$right_format"
    fi

    log_debug "renderer" "status-right configured"
}

# =============================================================================
# Window Configuration
# =============================================================================

# Configure window formats
configure_windows() {
    log_debug "renderer" "Configuring windows"

    # Determine which side windows are on based on status order
    # If using custom order (plugins,session), windows are on the right side
    local window_side="left"
    if _is_custom_order; then
        window_side="right"
    fi

    # Window status format (inactive)
    local window_format
    window_format=$(build_window_format "$window_side")
    tmux set-option -g window-status-format "$window_format"

    # Window status current format (active)
    local current_format
    current_format=$(build_window_current_format "$window_side")
    tmux set-option -g window-status-current-format "$current_format"

    # Window separator (not used in double layout since #{W:} handles it)
    local bar_layout
    bar_layout=$(get_tmux_option "@powerkit_bar_layout" "${POWERKIT_DEFAULT_BAR_LAYOUT}")
    if [[ "$bar_layout" != "double" ]]; then
        local separator
        separator=$(build_window_separator_format)
        tmux set-option -g window-status-separator "$separator"
    fi

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
