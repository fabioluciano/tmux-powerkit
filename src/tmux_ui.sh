#!/usr/bin/env bash
# =============================================================================
# PowerKit Tmux UI
# Consolidated UI module: separators, window formatting, status bar, tmux config
# =============================================================================
#
# This module combines previously separate UI concerns into a cohesive unit:
# - Separator System: Powerline transitions between elements
# - Window System: Index, content, and complete window formats
# - Status Bar: Session segment, layout builders
# - Tmux Config: Appearance settings application
#
# =============================================================================

# =============================================================================
# SEPARATOR SYSTEM
# Manages transitions between window segments and status areas
# =============================================================================

# Get separator character
get_separator_char() {
    echo "$(get_tmux_option "@powerkit_left_separator" "$POWERKIT_DEFAULT_LEFT_SEPARATOR")"
}

# Calculate previous window background for separator transition
get_previous_window_background() {
    local current_window_state="$1" # "active" or "inactive"
    local separator_color

    # Check if spacing is enabled
    local elements_spacing=$(get_tmux_option "@powerkit_elements_spacing" "$POWERKIT_DEFAULT_ELEMENTS_SPACING")

    # Determine spacing background color
    local transparent=$(get_tmux_option "@powerkit_transparent" "false")
    local spacing_bg
    if [[ "$transparent" == "true" ]]; then
        spacing_bg="default"
    else
        spacing_bg=$(get_powerkit_color 'surface')
    fi

    # Session colors (for first window) - now with copy mode support
    local prefix_color_name=$(get_tmux_option "@powerkit_session_prefix_color" "$POWERKIT_DEFAULT_SESSION_PREFIX_COLOR")
    local copy_color_name=$(get_tmux_option "@powerkit_session_copy_mode_color" "$POWERKIT_DEFAULT_SESSION_COPY_MODE_COLOR")
    local normal_color_name=$(get_tmux_option "@powerkit_session_normal_color" "$POWERKIT_DEFAULT_SESSION_NORMAL_COLOR")

    local session_prefix=$(get_powerkit_color "$prefix_color_name")
    local session_copy=$(get_powerkit_color "$copy_color_name")
    local session_normal=$(get_powerkit_color "$normal_color_name")

    # Build session color condition: prefix -> warning, copy_mode -> accent, else -> success
    local session_color="#{?client_prefix,$session_prefix,#{?pane_in_mode,$session_copy,$session_normal}}"

    # Window content colors
    local active_content_bg_option=$(get_tmux_option "@powerkit_active_window_content_bg" "$POWERKIT_DEFAULT_ACTIVE_WINDOW_CONTENT_BG")
    local active_content_bg=$(get_powerkit_color "$active_content_bg_option")
    local inactive_content_bg=$(get_powerkit_color 'border')

    if [[ "$elements_spacing" == "both" || "$elements_spacing" == "windows" ]]; then
        # Spacing is enabled: previous bg is always spacing color for window-to-window
        # But for first window (index 1), previous is session spacing
        # For other windows, previous is window spacing
        echo "$spacing_bg"
    elif [[ "$current_window_state" == "active" ]]; then
        # For active window: previous window is always inactive (or session for first)
        separator_color="#{?#{==:#{window_index},1},$session_color,$inactive_content_bg}"
        echo "$separator_color"
    else
        # For inactive window: check if previous window is active
        separator_color="#{?#{==:#{e|-:#{window_index},1},0},$session_color,#{?#{==:#{e|-:#{window_index},1},#{active_window_index}},$active_content_bg,$inactive_content_bg}}"
        echo "$separator_color"
    fi
}

# Create index-to-content separator (between window number and content)
# Right-facing separator (→): fg=previous (index), bg=next (content)
create_index_content_separator() {
    local window_state="$1" # "active" or "inactive"
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
    local current_window_state="$1" # "active" or "inactive"
    local separator_char=$(get_separator_char)
    local previous_bg=$(get_previous_window_background "$current_window_state")
    local current_index_colors=$(get_window_index_colors "$current_window_state")
    local current_index_bg=$(echo "$current_index_colors" | sed 's/bg=//')

    # Special handling for transparent mode with spacing
    # When transparent and spacing enabled, 'default' as fg makes separator invisible/white
    # Use theme background color instead for visible contrast
    local transparent=$(get_tmux_option "@powerkit_transparent" "false")
    local elements_spacing=$(get_tmux_option "@powerkit_elements_spacing" "$POWERKIT_DEFAULT_ELEMENTS_SPACING")

    if [[ "$transparent" == "true" && ("$elements_spacing" == "both" || "$elements_spacing" == "windows") && "$previous_bg" == "default" ]]; then
        # Use theme background color for fg to create visible separator on transparent background
        previous_bg=$(get_powerkit_color 'background')
    fi

    # Right-facing: fg=previous, bg=next (current index)
    echo "#[fg=${previous_bg},bg=${current_index_bg}]${separator_char}"
}

# Create spacing segment between elements (windows/plugins)
# Returns a small visual gap with appropriate background color
create_spacing_segment() {
    local current_bg="$1" # Background color of current element
    local transparent=$(get_tmux_option "@powerkit_transparent" "false")
    local spacing_bg

    # Determine spacing background based on transparency mode
    if [[ "$transparent" == "true" ]]; then
        spacing_bg="default"
    else
        spacing_bg=$(get_powerkit_color 'surface')
    fi

    local separator_char=$(get_separator_char)

    # Create spacing: close current element + small gap
    # The next element will add its own separator from spacing_bg
    echo "#[fg=${current_bg},bg=${spacing_bg}]${separator_char}#[bg=${spacing_bg}] #[none]"
}

# Create final separator (end of window list to status bar)
# Style "rounded": pill effect with rounded separator
# Style "normal": uses standard left separator
create_final_separator() {
    local separator_style=$(get_tmux_option "@powerkit_separator_style" "$POWERKIT_DEFAULT_SEPARATOR_STYLE")
    local separator_char
    local transparent=$(get_tmux_option "@powerkit_transparent" "false")
    local status_bg

    # Use 'default' for transparent mode, 'surface' otherwise
    if [[ "$transparent" == "true" ]]; then
        status_bg="default"
    else
        status_bg=$(get_powerkit_color 'surface')
    fi

    # Check if spacing is enabled for windows
    local elements_spacing=$(get_tmux_option "@powerkit_elements_spacing" "$POWERKIT_DEFAULT_ELEMENTS_SPACING")

    if [[ "$elements_spacing" == "both" || "$elements_spacing" == "windows" ]]; then
        # When spacing is enabled, each window already adds its own separator + spacing
        # The last window's separator IS the final separator, so we don't add another
        # Return empty string to avoid duplicate separators
        echo ""
        return
    fi

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

# =============================================================================
# WINDOW INDEX SYSTEM
# Manages window number display and styling
# =============================================================================

# Get window index colors based on window state
get_window_index_colors() {
    local window_state="$1" # "active" or "inactive"

    if [[ "$window_state" == "active" ]]; then
        local bg_color_option=$(get_tmux_option "@powerkit_active_window_number_bg" "$POWERKIT_DEFAULT_ACTIVE_WINDOW_NUMBER_BG")
        local bg_color=$(get_powerkit_color "$bg_color_option")
        echo "bg=$bg_color"
    else
        local bg_color_option=$(get_tmux_option "@powerkit_inactive_window_number_bg" "$POWERKIT_DEFAULT_INACTIVE_WINDOW_NUMBER_BG")
        local bg_color=$(get_powerkit_color "$bg_color_option")
        echo "bg=$bg_color"
    fi
}

# Create window index segment
create_window_index_segment() {
    local window_state="$1" # "active" or "inactive"
    local index_colors=$(get_window_index_colors "$window_state")
    local text_color=$(get_powerkit_color 'text')

    if [[ "$window_state" == "active" ]]; then
        echo "#[${index_colors},fg=${text_color},bold] #I "
    else
        echo "#[${index_colors},fg=${text_color}] #I "
    fi
}

# =============================================================================
# WINDOW CONTENT SYSTEM
# Manages window content area (icons + title)
# =============================================================================

# Get window content colors based on window state
get_window_content_colors() {
    local window_state="$1" # "active" or "inactive"

    if [[ "$window_state" == "active" ]]; then
        local bg_color_option=$(get_tmux_option "@powerkit_active_window_content_bg" "$POWERKIT_DEFAULT_ACTIVE_WINDOW_CONTENT_BG")
        local bg_color=$(get_powerkit_color "$bg_color_option")
        echo "bg=$bg_color"
    else
        local bg_color=$(get_powerkit_color 'border')
        echo "bg=$bg_color"
    fi
}

# Get window icon based on state
get_window_icon() {
    local window_state="$1" # "active" or "inactive"

    if [[ "$window_state" == "active" ]]; then
        echo "$(get_tmux_option "@powerkit_active_window_icon" "$POWERKIT_DEFAULT_ACTIVE_WINDOW_ICON")"
    else
        echo "$(get_tmux_option "@powerkit_inactive_window_icon" "$POWERKIT_DEFAULT_INACTIVE_WINDOW_ICON")"
    fi
}

# Get window title format
get_window_title() {
    local window_state="$1" # "active" or "inactive"

    if [[ "$window_state" == "active" ]]; then
        echo "$(get_tmux_option "@powerkit_active_window_title" "$POWERKIT_DEFAULT_ACTIVE_WINDOW_TITLE")"
    else
        echo "$(get_tmux_option "@powerkit_inactive_window_title" "$POWERKIT_DEFAULT_INACTIVE_WINDOW_TITLE")"
    fi
}

# Create window content segment
create_window_content_segment() {
    local window_state="$1" # "active" or "inactive"
    local content_colors=$(get_window_content_colors "$window_state")
    local text_color=$(get_powerkit_color 'text')
    local window_icon=$(get_window_icon "$window_state")
    local window_title=$(get_window_title "$window_state")
    local zoomed_icon=$(get_tmux_option "@powerkit_zoomed_window_icon" "$POWERKIT_DEFAULT_ZOOMED_WINDOW_ICON")

    if [[ "$window_state" == "active" ]]; then
        local pane_sync_icon=$(get_tmux_option "@powerkit_pane_synchronized_icon" "$POWERKIT_DEFAULT_PANE_SYNCHRONIZED_ICON")
        echo "#[${content_colors},fg=${text_color},bold] #{?window_zoomed_flag,$zoomed_icon,$window_icon} ${window_title}#{?pane_synchronized,$pane_sync_icon,}"
    else
        echo "#[${content_colors},fg=${text_color}] #{?window_zoomed_flag,$zoomed_icon,$window_icon} ${window_title}"
    fi
}

# =============================================================================
# WINDOW ASSEMBLY SYSTEM
# Combines all segments into complete window formats
# =============================================================================

# Helper: Add spacing segment to window format (DRY)
_add_window_spacing() {
    local window_state="$1"
    local content_bg="$2"
    local result=""

    local elements_spacing=$(get_tmux_option "@powerkit_elements_spacing" "$POWERKIT_DEFAULT_ELEMENTS_SPACING")
    [[ "$elements_spacing" != "both" && "$elements_spacing" != "windows" ]] && return

    local transparent=$(get_tmux_option "@powerkit_transparent" "false")
    local spacing_bg
    if [[ "$transparent" == "true" ]]; then
        spacing_bg="default"
    else
        spacing_bg=$(get_powerkit_color 'surface')
    fi

    local separator_style=$(get_tmux_option "@powerkit_separator_style" "$POWERKIT_DEFAULT_SEPARATOR_STYLE")
    local separator_normal=$(get_separator_char)
    local separator_rounded=$(get_tmux_option "@powerkit_right_separator_rounded" "$POWERKIT_DEFAULT_RIGHT_SEPARATOR_ROUNDED")

    if [[ "$separator_style" == "rounded" ]]; then
        echo "#[fg=${content_bg},bg=${spacing_bg}]#{?#{==:#{session_windows},#{window_index}},${separator_rounded},${separator_normal}}#[bg=${spacing_bg}]"
    else
        echo "#[fg=${content_bg},bg=${spacing_bg}]${separator_normal}#[bg=${spacing_bg}]"
    fi
}

# Create complete window format for active window
create_active_window_format() {
    local window_separator=$(create_window_separator "active")
    local index_segment=$(create_window_index_segment "active")
    local index_content_sep=$(create_index_content_separator "active")
    local content_segment=$(create_window_content_segment "active")

    local window_format="${window_separator}${index_segment}${index_content_sep}${content_segment}"

    # Add spacing if enabled
    local content_bg_option=$(get_tmux_option "@powerkit_active_window_content_bg" "$POWERKIT_DEFAULT_ACTIVE_WINDOW_CONTENT_BG")
    local content_bg=$(get_powerkit_color "$content_bg_option")
    window_format+=$(_add_window_spacing "active" "$content_bg")

    echo "${window_format}"
}

# Create complete window format for inactive window
create_inactive_window_format() {
    local window_separator=$(create_window_separator "inactive")
    local index_segment=$(create_window_index_segment "inactive")
    local index_content_sep=$(create_index_content_separator "inactive")
    local content_segment=$(create_window_content_segment "inactive")

    local window_format="${window_separator}${index_segment}${index_content_sep}${content_segment}"

    # Add spacing if enabled (inactive uses 'border' color)
    local content_bg=$(get_powerkit_color 'border')
    window_format+=$(_add_window_spacing "inactive" "$content_bg")

    echo "${window_format}"
}

# =============================================================================
# STATUS BAR SYSTEM
# Manages left side, right side, and overall status bar formatting
# =============================================================================

# Create session segment (left side of status bar)
create_session_segment() {
    local session_icon=$(get_tmux_option "@powerkit_session_icon" "$POWERKIT_DEFAULT_SESSION_ICON")
    local separator_char=$(get_separator_char)
    local text_color=$(get_powerkit_color 'surface')
    local transparent=$(get_tmux_option "@powerkit_transparent" "false")

    # Get colors for different states
    local prefix_color_name=$(get_tmux_option "@powerkit_session_prefix_color" "$POWERKIT_DEFAULT_SESSION_PREFIX_COLOR")
    local copy_color_name=$(get_tmux_option "@powerkit_session_copy_mode_color" "$POWERKIT_DEFAULT_SESSION_COPY_MODE_COLOR")
    local normal_color_name=$(get_tmux_option "@powerkit_session_normal_color" "$POWERKIT_DEFAULT_SESSION_NORMAL_COLOR")

    local prefix_bg=$(get_powerkit_color "$prefix_color_name")
    local copy_bg=$(get_powerkit_color "$copy_color_name")
    local normal_bg=$(get_powerkit_color "$normal_color_name")

    # Auto-detect OS icon if needed
    if [[ "$session_icon" == "auto" ]]; then
        session_icon=$(get_os_icon)
    fi

    # Build conditional background color: prefix -> warning, copy_mode -> accent, else -> success
    # Priority: prefix > copy_mode > normal
    local bg_condition="#{?client_prefix,${prefix_bg},#{?pane_in_mode,${copy_bg},${normal_bg}}}"

    # Check if spacing is enabled
    local elements_spacing=$(get_tmux_option "@powerkit_elements_spacing" "$POWERKIT_DEFAULT_ELEMENTS_SPACING")
    local session_output="#[fg=${text_color},bold,bg=${bg_condition}]${session_icon} #S "

    if [[ "$elements_spacing" == "both" || "$elements_spacing" == "windows" ]]; then
        # Spacing is enabled: add spacing segment after session
        local spacing_bg
        if [[ "$transparent" == "true" ]]; then
            spacing_bg="default"
        else
            spacing_bg=$(get_powerkit_color 'surface')
        fi

        # Close session + spacing gap
        # The first window will add its own separator from spacing_bg
        session_output+="#[fg=${bg_condition},bg=${spacing_bg}]${separator_char}#[bg=${spacing_bg}]"
    fi

    echo "$session_output"
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
