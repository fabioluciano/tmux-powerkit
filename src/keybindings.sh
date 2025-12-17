#!/usr/bin/env bash
# =============================================================================
# PowerKit Keybindings Management
# Conflict detection and helper keybindings registration
# =============================================================================

# =============================================================================
# KEYBINDING CONFLICT DETECTION
# Identifies duplicate keybindings at startup
# =============================================================================

check_keybinding_conflicts() {
    local plugins_string="$1"
    local -A existing_bindings=()
    local -A powerkit_bindings=()
    local -a conflicts=()
    local log_file="${CACHE_DIR}/keybinding_conflicts.log"
    
    # Get all existing tmux keybindings in prefix table
    # Format: bind-key -T prefix X command
    # NOTE: Keys are case-sensitive in tmux (M ≠ m, B ≠ b)
    local line key cmd
    while IFS= read -r line; do
        # Extract key and command from tmux list-keys output
        # Example: bind-key -T prefix d detach-client
        if [[ "$line" =~ bind-key[[:space:]]+-T[[:space:]]+prefix[[:space:]]+([^[:space:]]+)[[:space:]]+(.+) ]]; then
            key="${BASH_REMATCH[1]}"  # Preserves case (M vs m)
            cmd="${BASH_REMATCH[2]}"
            # Skip PowerKit bindings (case-insensitive check on command only, not key)
            if [[ "${cmd,,}" == *"powerkit"* ]]; then
                continue
            fi
            # Store existing binding with original key case (truncate cmd for display)
            existing_bindings["$key"]="${cmd:0:60}"
        fi
    done < <(tmux list-keys -T prefix 2>/dev/null || true)
    
    # Helper to check if PowerKit key conflicts with existing tmux bindings
    # Comparison is case-sensitive: 'M' and 'm' are different keys
    _check_key() {
        local key="$1" source="$2"
        [[ -z "$key" ]] && return
        
        # Check conflict with other PowerKit bindings
        if [[ -n "${powerkit_bindings[$key]:-}" ]]; then
            conflicts+=("PowerKit internal: '$key' used by ${powerkit_bindings[$key]} AND $source")
        else
            powerkit_bindings["$key"]="$source"
        fi
        
        # Check conflict with existing tmux bindings (PowerKit bindings already filtered out)
        if [[ -n "${existing_bindings[$key]:-}" ]]; then
            conflicts+=("Tmux conflict: '$key' wanted by PowerKit:$source, but already bound to: ${existing_bindings[$key]}")
        fi
    }
    
    # Core keybindings
    local options_key keybindings_key cache_clear_key theme_selector_key
    options_key=$(get_tmux_option "@powerkit_options_key" "$POWERKIT_DEFAULT_OPTIONS_KEY")
    keybindings_key=$(get_tmux_option "@powerkit_keybindings_key" "$POWERKIT_DEFAULT_KEYBINDINGS_KEY")
    cache_clear_key=$(get_tmux_option "@powerkit_plugin_cache_clear_key" "$POWERKIT_PLUGIN_CACHE_CLEAR_KEY")
    theme_selector_key=$(get_tmux_option "@powerkit_theme_selector_key" "$POWERKIT_DEFAULT_THEME_SELECTOR_KEY")

    _check_key "$options_key" "core:options_viewer"
    _check_key "$keybindings_key" "core:keybindings_viewer"
    _check_key "$cache_clear_key" "core:cache_clear"
    _check_key "$theme_selector_key" "core:theme_selector"
    
    # Plugin keybindings - only check if plugin is enabled
    local -a plugins=()
    IFS=',' read -ra plugins <<< "$plugins_string"
    
    local plugin
    for plugin in "${plugins[@]}"; do
        plugin="${plugin%%:*}"
        [[ -z "$plugin" ]] && continue
        
        case "$plugin" in
            audiodevices)
                local input_key output_key
                input_key=$(get_tmux_option "@powerkit_plugin_audiodevices_input_key" "$POWERKIT_PLUGIN_AUDIODEVICES_INPUT_KEY")
                output_key=$(get_tmux_option "@powerkit_plugin_audiodevices_output_key" "$POWERKIT_PLUGIN_AUDIODEVICES_OUTPUT_KEY")
                _check_key "$input_key" "audiodevices:input_selector"
                _check_key "$output_key" "audiodevices:output_selector"
                ;;
            kubernetes)
                local ctx_key ns_key
                ctx_key=$(get_tmux_option "@powerkit_plugin_kubernetes_context_selector_key" "$POWERKIT_PLUGIN_KUBERNETES_CONTEXT_SELECTOR_KEY")
                ns_key=$(get_tmux_option "@powerkit_plugin_kubernetes_namespace_selector_key" "$POWERKIT_PLUGIN_KUBERNETES_NAMESPACE_SELECTOR_KEY")
                _check_key "$ctx_key" "kubernetes:context_selector"
                _check_key "$ns_key" "kubernetes:namespace_selector"
                ;;
            terraform)
                local ws_key
                ws_key=$(get_tmux_option "@powerkit_plugin_terraform_workspace_key" "$POWERKIT_PLUGIN_TERRAFORM_WORKSPACE_KEY")
                _check_key "$ws_key" "terraform:workspace_selector"
                ;;
            bitwarden)
                local bw_key bw_unlock_key bw_lock_key
                bw_key=$(get_tmux_option "@powerkit_plugin_bitwarden_password_selector_key" "$POWERKIT_PLUGIN_BITWARDEN_PASSWORD_SELECTOR_KEY")
                bw_unlock_key=$(get_tmux_option "@powerkit_plugin_bitwarden_unlock_key" "$POWERKIT_PLUGIN_BITWARDEN_UNLOCK_KEY")
                bw_lock_key=$(get_tmux_option "@powerkit_plugin_bitwarden_lock_key" "$POWERKIT_PLUGIN_BITWARDEN_LOCK_KEY")
                _check_key "$bw_key" "bitwarden:password_selector"
                _check_key "$bw_unlock_key" "bitwarden:unlock_vault"
                _check_key "$bw_lock_key" "bitwarden:lock_vault"
                ;;
        esac
    done
    
    # Display conflicts if any
    if [[ ${#conflicts[@]} -gt 0 ]]; then
        local conflict_count=${#conflicts[@]}
        
        # Log to file for full details
        {
            echo "=== PowerKit Keybinding Conflicts ==="
            echo "Detected at: $(date)"
            echo ""
            local conflict
            for conflict in "${conflicts[@]}"; do
                echo "  • $conflict"
            done
            echo ""
            echo "Fix by changing keys in tmux.conf using @powerkit_* options."
        } > "$log_file"
        
        # Create formatted content file for toast
        local toast_content="${CACHE_DIR}/conflict_toast_display.txt"
        _format_conflict_toast "$conflict_count" "$log_file" > "$toast_content"
        
        # Calculate popup size based on conflicts
        local popup_height=$((conflict_count + 18))
        [[ $popup_height -lt 15 ]] && popup_height=15
        [[ $popup_height -gt 30 ]] && popup_height=30
        
        # Show toast notification (uses generic utility from utils.sh)
        show_toast_notification "⚠️  PowerKit Conflicts" "$toast_content" 70 "$popup_height"
    else
        # Remove old conflict log if no conflicts
        [[ -f "$log_file" ]] && rm -f "$log_file" || true
    fi
}

# =============================================================================
# CONFLICT TOAST FORMATTING
# Formats conflict data for toast display
# =============================================================================

_format_conflict_toast() {
    local conflict_count="$1"
    local log_file="$2"
    
    # Colors
    local RED='\033[0;31m'
    local YELLOW='\033[1;33m'
    local CYAN='\033[0;36m'
    local WHITE='\033[1;37m'
    local DIM='\033[2m'
    local NC='\033[0m'
    
    # Header
    echo ""
    echo -e "  ${RED}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${RED}║${NC}  ${YELLOW}⚠️  PowerKit: Keybinding Conflicts Detected!${NC}             ${RED}║${NC}"
    echo -e "  ${RED}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Read conflicts from log file
    if [[ -f "$log_file" ]]; then
        echo -e "  ${WHITE}Conflicts found:${NC}"
        echo ""
        while IFS= read -r line; do
            if [[ "$line" == *"•"* ]]; then
                # Color the conflict type
                if [[ "$line" == *"PowerKit internal"* ]]; then
                    echo -e "  ${YELLOW}$line${NC}"
                elif [[ "$line" == *"Tmux conflict"* ]]; then
                    echo -e "  ${RED}$line${NC}"
                else
                    echo -e "  $line"
                fi
            fi
        done < "$log_file"
    fi
    
    echo ""
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "  ${CYAN}💡 Fix:${NC} Change conflicting keys in ${WHITE}tmux.conf${NC} using:"
    echo -e "     ${DIM}set -g @powerkit_plugin_<plugin>_<key> \"<new_key>\"${NC}"
    echo ""
    echo -e "  ${DIM}📄 Full log: $log_file${NC}"
}

# =============================================================================
# HELPER KEYBINDINGS REGISTRATION
# Register keybindings for interactive helpers
# =============================================================================

register_helper_keybindings() {
    local helpers_dir="${CURRENT_DIR}/helpers"

    # Options viewer (prefix + ?) - display-popup with less for navigation
    local options_key=$(get_tmux_option "@powerkit_options_key" "$POWERKIT_DEFAULT_OPTIONS_KEY")
    local options_width=$(get_tmux_option "@powerkit_options_width" "$POWERKIT_DEFAULT_OPTIONS_WIDTH")
    local options_height=$(get_tmux_option "@powerkit_options_height" "$POWERKIT_DEFAULT_OPTIONS_HEIGHT")
    [[ -n "$options_key" ]] && tmux bind-key "$options_key" display-popup -E -w "$options_width" -h "$options_height" \
        "bash '$helpers_dir/options_viewer.sh'"

    # Keybindings viewer (prefix + B) - display-popup with less for navigation
    local keybindings_key=$(get_tmux_option "@powerkit_keybindings_key" "$POWERKIT_DEFAULT_KEYBINDINGS_KEY")
    local keybindings_width=$(get_tmux_option "@powerkit_keybindings_width" "$POWERKIT_DEFAULT_KEYBINDINGS_WIDTH")
    local keybindings_height=$(get_tmux_option "@powerkit_keybindings_height" "$POWERKIT_DEFAULT_KEYBINDINGS_HEIGHT")
    [[ -n "$keybindings_key" ]] && tmux bind-key "$keybindings_key" display-popup -E -w "$keybindings_width" -h "$keybindings_height" \
        "bash '$helpers_dir/keybindings_viewer.sh'"

    # Theme selector (prefix + T) - uses tmux display-menu
    local theme_key=$(get_tmux_option "@powerkit_theme_selector_key" "$POWERKIT_DEFAULT_THEME_SELECTOR_KEY")
    [[ -n "$theme_key" ]] && tmux bind-key "$theme_key" run-shell "bash '$helpers_dir/theme_selector.sh' select"
}
