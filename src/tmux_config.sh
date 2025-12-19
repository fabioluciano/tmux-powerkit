#!/usr/bin/env bash
# =============================================================================
# PowerKit Tmux Configuration
# Applies all settings to tmux
# =============================================================================

# =============================================================================
# TMUX APPEARANCE CONFIGURATION
# =============================================================================

# Configure tmux appearance settings
configure_tmux_appearance() {
    # Load PowerKit theme
    load_powerkit_theme
    
    # Pane borders - get user config (semantic name) and resolve to actual color
    local border_style_active_pane_name=$(get_tmux_option "@powerkit_active_pane_border_style" "$POWERKIT_DEFAULT_ACTIVE_PANE_BORDER_STYLE")
    local border_style_inactive_pane_name=$(get_tmux_option "@powerkit_inactive_pane_border_style" "$POWERKIT_DEFAULT_INACTIVE_PANE_BORDER_STYLE")
    local border_style_active_pane=$(get_powerkit_color "$border_style_active_pane_name")
    local border_style_inactive_pane=$(get_powerkit_color "$border_style_inactive_pane_name")
    
    tmux set-option -g pane-active-border-style "fg=$border_style_active_pane"
    if ! tmux set-option -g pane-border-style "#{?pane_synchronized,fg=$border_style_active_pane,fg=$border_style_inactive_pane}" &>/dev/null; then
        tmux set-option -g pane-border-style "fg=$border_style_active_pane,fg=$border_style_inactive_pane"
    fi
    
    # Message styling
    local message_bg=$(get_powerkit_color "error")
    local message_fg=$(get_powerkit_color "background-alt")
    tmux set-option -g message-style "bg=${message_bg},fg=${message_fg}"
    
    # Status bar
    local transparent=$(get_tmux_option "@powerkit_transparent" "$POWERKIT_DEFAULT_TRANSPARENT")
    local status_bar_bg=$(get_powerkit_color "surface")
    local status_bar_fg=$(get_powerkit_color "text")
    if [[ "$transparent" == "true" ]]; then
        status_bar_bg="default"
    fi
    tmux set-option -g status-style "bg=${status_bar_bg},fg=${status_bar_fg}"
    
    # Status bar layout
    local powerkit_bar_layout=$(get_tmux_option "@powerkit_bar_layout" "$POWERKIT_DEFAULT_BAR_LAYOUT")
    if [[ "$powerkit_bar_layout" == "double" ]]; then
        tmux set-option -g status 2
    else
        tmux set-option -g status on
        tmux set-option -gu status-format[1] 2>/dev/null || true
    fi
    
    # Status bar lengths
    local status_left_length=$(get_tmux_option "@powerkit_status_left_length" "$POWERKIT_DEFAULT_STATUS_LEFT_LENGTH")
    local status_right_length=$(get_tmux_option "@powerkit_status_right_length" "$POWERKIT_DEFAULT_STATUS_RIGHT_LENGTH")
    tmux set-option -g status-left-length "$status_left_length"
    tmux set-option -g status-right-length "$status_right_length"
    
    # Window activity/bell styles
    local window_with_activity_style=$(get_tmux_option "@powerkit_window_with_activity_style" "$POWERKIT_DEFAULT_WINDOW_WITH_ACTIVITY_STYLE")
    local window_status_bell_style=$(get_tmux_option "@powerkit_status_bell_style" "$POWERKIT_DEFAULT_STATUS_BELL_STYLE")
    tmux set-window-option -g window-status-activity-style "$window_with_activity_style"
    tmux set-window-option -g window-status-bell-style "$window_status_bell_style"
}
