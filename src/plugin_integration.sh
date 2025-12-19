#!/usr/bin/env bash
# =============================================================================
# PowerKit Plugin Integration
# Plugin loading, parsing, and status bar integration
# =============================================================================

# =============================================================================
# PLUGIN PARSING
# =============================================================================

# Parse external plugin: external(icon|content|accent|accent_icon|ttl)
# Example: external(⚡|#{cpu_percentage}) or external(󰍛|#{ram_percentage}|warning|warning-strong|30)
parse_external_plugin() {
    local inner="${1#external(}"
    inner="${inner%)}"
    inner="${inner//\"/}"  # Remove quotes if present
    
    IFS='|' read -r icon content accent accent_icon ttl <<< "$inner"
    printf '%s|%s|%s|%s|%s' "$icon" "$content" "${accent:-secondary}" "${accent_icon:-active}" "${ttl:-0}"
}

# =============================================================================
# PLUGIN LIST BUILDER
# =============================================================================

# Get plugins list for single layout
get_plugins_list() {
    local plugins=("$@")
    local plugin_configs=""
    
    # Build plugin config string for render_plugins.sh
    for plugin in "${plugins[@]}"; do
        [[ -z "$plugin" ]] && continue
        
        # Handle external plugins: external(icon|content|accent|accent_icon|ttl)
        # Convert to standard format: EXTERNAL|icon|content|accent|accent_icon|ttl
        if [[ "$plugin" == external\(*\) ]]; then
            IFS='|' read -r ext_icon ext_content ext_accent ext_accent_icon ext_ttl <<< "$(parse_external_plugin "$plugin")"
            # Use EXTERNAL prefix with | separator to pass to render_plugins.sh
            plugin_configs+="EXTERNAL|${ext_icon}|${ext_content}|${ext_accent}|${ext_accent_icon}|${ext_ttl:-0};"
            continue
        fi
        
        # Parse plugin format: name or name:accent:accent_icon:icon:type
        if [[ "$plugin" == *":"* ]]; then
            # Custom format - use as-is but still check for keybindings
            local plugin_name="${plugin%%:*}"
            local plugin_script="${CURRENT_DIR}/plugin/${plugin_name}.sh"
            if [[ -f "$plugin_script" ]]; then
                # shellcheck source=/dev/null
                if . "$plugin_script" 2>/dev/null && declare -f setup_keybindings &>/dev/null; then
                    setup_keybindings
                    unset -f setup_keybindings
                fi
            fi
            plugin_configs+="$plugin;"
        else
            # Simple plugin name - get type and defaults
            local plugin_script="${CURRENT_DIR}/plugin/${plugin}.sh"
            local plugin_type="static"
            
            if [[ -f "$plugin_script" ]]; then
                # Source plugin once for keybindings and type
                # shellcheck source=/dev/null
                if . "$plugin_script" 2>/dev/null; then
                    declare -f setup_keybindings &>/dev/null && { setup_keybindings; unset -f setup_keybindings; }
                    declare -f plugin_get_type &>/dev/null && { plugin_type=$(plugin_get_type); unset -f plugin_get_type; }
                fi
            fi
            
            # Get plugin colors from defaults
            local plugin_upper="${plugin^^}"
            plugin_upper="${plugin_upper//-/_}"
            
            local accent_var="POWERKIT_PLUGIN_${plugin_upper}_ACCENT_COLOR"
            local accent_icon_var="POWERKIT_PLUGIN_${plugin_upper}_ACCENT_COLOR_ICON"
            local icon_var="POWERKIT_PLUGIN_${plugin_upper}_ICON"
            
            local accent_color="${!accent_var:-accent}"
            local accent_icon_color="${!accent_icon_var:-accent}"
            local icon="${!icon_var:-}"
            
            # Use format: name:accent:accent_icon:icon:type
            plugin_configs+="$plugin:$accent_color:$accent_icon_color:$icon:$plugin_type;"
        fi
    done
    
    # Remove trailing semicolon
    plugin_configs="${plugin_configs%%;}"
    
    if [[ -n "$plugin_configs" ]]; then
        # Build tmux command string that will be executed periodically
        local text_color=$(get_powerkit_color 'text')
        local transparent=$(get_tmux_option "@powerkit_transparent" "false")
        local status_bg=$(get_powerkit_color 'surface')

        # Use default background when transparent mode is enabled
        [[ "$transparent" == "true" ]] && status_bg="default"

        local palette=$(serialize_powerkit_palette)
        local right_sep=$(get_tmux_option "@powerkit_right_separator" "$POWERKIT_DEFAULT_RIGHT_SEPARATOR")
        local right_sep_inv=$(get_tmux_option "@powerkit_right_separator_inverse" "$POWERKIT_DEFAULT_RIGHT_SEPARATOR_INVERSE")

        # Create command that tmux will execute with current pane path context
        printf "#(RENDER_TEXT_COLOR='%s' RENDER_STATUS_BG='%s' RENDER_TRANSPARENT='%s' RENDER_PALETTE='%s' POWERKIT_DEFAULT_RIGHT_SEPARATOR='%s' POWERKIT_DEFAULT_RIGHT_SEPARATOR_INVERSE='%s' %s/render_plugins.sh '%s' 2>/dev/null || true)" \
            "$text_color" "$status_bg" "$transparent" "$palette" "$right_sep" "$right_sep_inv" "$CURRENT_DIR" "$plugin_configs"
    fi
}

# =============================================================================
# PALETTE SERIALIZATION
# =============================================================================

# Serialize PowerKit palette for render_plugins.sh
serialize_powerkit_palette() {
    local palette=""
    
    # Ensure theme is loaded
    if [[ -z "${POWERKIT_THEME_COLORS+x}" ]] || [[ "${#POWERKIT_THEME_COLORS[@]}" -eq 0 ]]; then
        load_powerkit_theme
    fi
    
    # Iterate over all theme colors and serialize them
    # Sort keys to ensure consistent ordering (important for parsing)
    for color in $(printf '%s\n' "${!POWERKIT_THEME_COLORS[@]}" | sort); do
        local color_value="${POWERKIT_THEME_COLORS[$color]}"
        # Skip empty values
        [[ -n "$color_value" ]] && palette+="$color=$color_value;"
    done
    
    echo "${palette%%;}"
}

# =============================================================================
# PLUGIN INITIALIZATION
# =============================================================================

# Initialize plugin system
initialize_plugins() {
    local powerkit_disable_plugins=$(get_tmux_option "@powerkit_disable_plugins" "$POWERKIT_DEFAULT_DISABLE_PLUGINS")
    local plugins_string=$(get_tmux_option "@powerkit_plugins" "$POWERKIT_DEFAULT_PLUGINS")
    local plugins
    IFS=',' read -r -a plugins <<<"$plugins_string"
    
    local status_output=""
    if [[ -n "$plugins_string" && "$powerkit_disable_plugins" != "true" ]]; then
        export CURRENT_DIR
        local powerkit_bar_layout=$(get_tmux_option "@powerkit_bar_layout" "$POWERKIT_DEFAULT_BAR_LAYOUT")
        
        if [[ "$powerkit_bar_layout" == "double" ]]; then
            # Double layout - plugins on second line
            status_output=$(get_plugins_list "${plugins[@]}")
        else
            # Single layout - plugins on right side
            status_output=$(get_plugins_list "${plugins[@]}")
        fi
    fi
    
    echo "$status_output"
}
