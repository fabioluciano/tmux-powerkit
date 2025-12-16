#!/usr/bin/env bash
# =============================================================================
# PowerKit Separators
# Manages transitions between window segments and status areas
# =============================================================================

# =============================================================================
# SEPARATOR SYSTEM
# =============================================================================

# Get separator character
get_separator_char() {
    echo "$(get_tmux_option "@powerkit_left_separator" "$POWERKIT_DEFAULT_LEFT_SEPARATOR")"
}

# Calculate previous window background for separator transition
get_previous_window_background() {
    local current_window_state="$1"  # "active" or "inactive"
    local separator_color
    
    # Session colors (for first window)
    local session_success=$(get_powerkit_color 'success')
    local session_warning=$(get_powerkit_color 'warning')
    
    # Window content colors
    local active_content_bg_option=$(get_tmux_option "@powerkit_active_window_content_bg" "$POWERKIT_DEFAULT_ACTIVE_WINDOW_CONTENT_BG")
    local active_content_bg=$(get_powerkit_color "$active_content_bg_option")
    local inactive_content_bg=$(get_powerkit_color 'border')
    
    if [[ "$current_window_state" == "active" ]]; then
        # For active window: previous window is always inactive (or session for first)
        separator_color="#{?#{==:#{window_index},1},#{?client_prefix,$session_warning,$session_success},$inactive_content_bg}"
    else
        # For inactive window: check if previous window is active
        separator_color="#{?#{==:#{e|-:#{window_index},1},0},#{?client_prefix,$session_warning,$session_success},#{?#{==:#{e|-:#{window_index},1},#{active_window_index}},$active_content_bg,$inactive_content_bg}}"
    fi
    
    echo "$separator_color"
}

# Create index-to-content separator (between window number and content)
# Right-facing separator (→): fg=previous (index), bg=next (content)
create_index_content_separator() {
    local window_state="$1"  # "active" or "inactive"
    local separator_char=$(get_separator_char)
    local index_colors=$(get_window_index_colors "$window_state")
    local content_colors=$(get_window_content_colors "$window_state")
    
    # Extract background colors for transition
    local index_bg=$(echo "$index_colors" | sed 's/bg=//')
    local content_bg=$(echo "$content_colors" | sed 's/bg=//')
    
    # Right-facing: fg=previous (index), bg=next (content)
    echo "#[fg=${index_bg},bg=${content_bg}]${separator_char}"
}

# Create window-to-window separator (between different windows)
# Right-facing separator (→): fg=previous, bg=next
create_window_separator() {
    local current_window_state="$1"  # "active" or "inactive"
    local separator_char=$(get_separator_char)
    local previous_bg=$(get_previous_window_background "$current_window_state")
    local current_index_colors=$(get_window_index_colors "$current_window_state")
    local current_index_bg=$(echo "$current_index_colors" | sed 's/bg=//')
    
    # Right-facing: fg=previous, bg=next (current index)
    echo "#[fg=${previous_bg},bg=${current_index_bg}]${separator_char}"
}

# Create final separator (end of window list to status bar)
# Style "rounded": pill effect with rounded separator
# Style "normal": uses standard left separator
create_final_separator() {
    local separator_style=$(get_tmux_option "@powerkit_separator_style" "$POWERKIT_DEFAULT_SEPARATOR_STYLE")
    local separator_char
    local status_bg=$(get_powerkit_color 'surface')
    
    # Get window content background colors for last window detection
    local active_content_bg_option=$(get_tmux_option "@powerkit_active_window_content_bg" "$POWERKIT_DEFAULT_ACTIVE_WINDOW_CONTENT_BG")
    local active_content_bg=$(get_powerkit_color "$active_content_bg_option")
    local inactive_content_bg=$(get_powerkit_color 'border')
    
    if [[ "$separator_style" == "rounded" ]]; then
        separator_char=$(get_tmux_option "@powerkit_right_separator_rounded" "$POWERKIT_DEFAULT_RIGHT_SEPARATOR_ROUNDED")
        # Pill effect: fg=window_color, bg=status_bg
        echo "#{?#{==:#{session_windows},#{active_window_index}},#[fg=${active_content_bg}],#[fg=${inactive_content_bg}]}#[bg=${status_bg}]${separator_char}"
    else
        separator_char=$(get_tmux_option "@powerkit_left_separator" "$POWERKIT_DEFAULT_LEFT_SEPARATOR")
        # Normal powerline: right-facing, fg=window_color, bg=status_bg
        echo "#{?#{==:#{session_windows},#{active_window_index}},#[fg=${active_content_bg}],#[fg=${inactive_content_bg}]}#[bg=${status_bg}]${separator_char}"
    fi
}
