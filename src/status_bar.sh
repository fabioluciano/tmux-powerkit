#!/usr/bin/env bash
# =============================================================================
# PowerKit Status Bar
# Status bar formatting and layout management
# =============================================================================

# =============================================================================
# STATUS BAR SYSTEM
# Manages left side, right side, and overall status bar formatting  
# =============================================================================

# Create session segment (left side of status bar)
create_session_segment() {
    local session_icon=$(get_tmux_option "@powerkit_session_icon" "$POWERKIT_DEFAULT_SESSION_ICON")
    local separator_char=$(get_separator_char)
    local text_color=$(get_powerkit_color 'surface')
    local warning_bg=$(get_powerkit_color 'warning')
    local success_bg=$(get_powerkit_color 'success')
    local transparent=$(get_tmux_option "@powerkit_transparent_status_bar" "false")
    
    # Auto-detect OS icon if needed
    if [[ "$session_icon" == "auto" ]]; then
        session_icon=$(get_os_icon)
    fi
    
    # Handle transparency
    local separator_end
    if [[ "$transparent" == "true" ]]; then
        separator_end="#[bg=default]#{?client_prefix,#[fg=${warning_bg}],#[fg=${success_bg}]}${separator_char}#[none]"
    else
        separator_end="#{?client_prefix,#[fg=${warning_bg}],#[fg=${success_bg}]}${separator_char}#[none]"
    fi
    
    echo "#[fg=${text_color},bold]#{?client_prefix,#[bg=${warning_bg}],#[bg=${success_bg}]}${session_icon} #S${separator_end}"
}

# Build status left format
build_status_left_format() {
    printf '#[align=left range=left #{E:status-left-style}]#[push-default]#{T;=/#{status-left-length}:status-left}#[pop-default]#[norange default]'
}

# Build status right format  
build_status_right_format() {
    local resolved_accent_color="$1"
    printf '#[nolist align=right range=right #{E:status-right-style}]#[push-default]#{T;=/#{status-right-length}:status-right}#[pop-default]#[norange bg=%s]' "$resolved_accent_color"
}

# Build window list format
build_window_list_format() {
    printf '#[list=on align=#{status-justify}]#[list=left-marker]<#[list=right-marker]>#[list=on]'
}

# Build tmux native window format (using our custom formats)
build_tmux_window_format() {
    local window_conditions='#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}'
    window_conditions+='#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},'
    window_conditions+='#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}'
    
    printf '#{W:#[range=window|#{window_index} #{E:window-status-style}%s]#[push-default]#{T:window-status-format}#[pop-default]#[norange default]#{?window_end_flag,,#{window-status-separator}},#[range=window|#{window_index} list=focus #{?#{!=:#{E:window-status-current-style},default},#{E:window-status-current-style},#{E:window-status-style}}%s]#[push-default]#{T:window-status-current-format}#[pop-default]#[norange default]#{?window_end_flag,,#{window-status-separator}}}' "$window_conditions" "$window_conditions"
}

# =============================================================================
# STATUS FORMAT BUILDERS
# Assembles complete status bar format
# =============================================================================

# Build complete status format for single layout
build_single_layout_status_format() {
    local resolved_accent_color="$1"
    local left_format window_list_format inactive_window_format right_format final_separator
    
    left_format=$(build_status_left_format)
    window_list_format=$(build_window_list_format)
    inactive_window_format=$(build_tmux_window_format)
    right_format=$(build_status_right_format "$resolved_accent_color")
    
    # Create the final separator using proper architecture
    final_separator=$(create_final_separator)
    
    printf '%s%s%s%s%s' "$left_format" "$window_list_format" "$inactive_window_format" "$final_separator" "$right_format"
}

# Build complete status format for double layout (windows only)
build_double_layout_windows_format() {
    local left_format window_list_format inactive_window_format
    
    left_format=$(build_status_left_format)
    window_list_format=$(build_window_list_format)
    inactive_window_format=$(build_tmux_window_format)
    
    printf '%s%s%s#[nolist align=right range=right #{E:status-right-style}]#[push-default]#[pop-default]#[norange default]' "$left_format" "$window_list_format" "$inactive_window_format"
}
