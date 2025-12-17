#!/usr/bin/env bash
# =============================================================================
# PowerKit Initialization
# Main entry point - orchestrates all PowerKit modules
# =============================================================================
#
# DEPENDENCY LOADING ORDER (CRITICAL - DO NOT CHANGE):
# ┌─────────────────────────────────────────────────────────────────────────┐
# │ 1. source_guard.sh  - Base guard mechanism (no dependencies)            │
# │ 2. defaults.sh      - Configuration defaults (depends: source_guard)    │
# │ 3. utils.sh         - Utility functions (depends: source_guard,defaults)│
# │ 4. cache.sh         - Cache system (depends: source_guard, utils)       │
# │ 5. Module files     - Feature modules (depend on above)                 │
# └─────────────────────────────────────────────────────────────────────────┘
#
# GLOBAL VARIABLES SET:
#   - All from defaults.sh, utils.sh, cache.sh
#   - Module-specific variables
#
# =============================================================================
set -eu
# Note: pipefail removed - it causes issues with plugins using pipes (grep -q exits early)
export LC_ALL=en_US.UTF-8

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# Source Dependencies (ORDER MATTERS - see diagram above)
# =============================================================================

# Core dependencies (loaded in dependency order)
. "$CURRENT_DIR/defaults.sh"    # Configuration defaults
. "$CURRENT_DIR/utils.sh"       # Platform detection, tmux options, colors
. "$CURRENT_DIR/cache.sh"       # Caching system

# Feature modules (depend on core)
. "$CURRENT_DIR/keybindings.sh"       # Keybinding management
. "$CURRENT_DIR/separators.sh"        # Powerline separators
. "$CURRENT_DIR/window_format.sh"     # Window formatting
. "$CURRENT_DIR/status_bar.sh"        # Status bar generation
. "$CURRENT_DIR/plugin_integration.sh" # Plugin system
. "$CURRENT_DIR/tmux_config.sh"       # Tmux appearance configuration

# =============================================================================
# MAIN INITIALIZATION
# =============================================================================

# Main initialization function
initialize_powerkit() {
    # Configure tmux appearance
    configure_tmux_appearance
    
    # Set up window formats using modular system
    tmux set-window-option -g window-status-format "$(create_inactive_window_format)"
    tmux set-window-option -g window-status-current-format "$(create_active_window_format)"
    
    # Set up session segment (left side)
    tmux set-option -g status-left "$(create_session_segment)"
    
    # Initialize plugins and handle status bar layout
    local status_2=$(initialize_plugins)
    local powerkit_bar_layout=$(get_tmux_option "@powerkit_bar_layout" "$POWERKIT_DEFAULT_BAR_LAYOUT")
    
    if [[ "$powerkit_bar_layout" == "double" ]]; then
        # Double layout: plugins on second line (right-aligned)
        if [[ -n "$status_2" ]]; then
            # Format plugins for right alignment on second line
            local resolved_accent_color=$(get_powerkit_color 'surface')
            local plugins_format="#[nolist align=right range=right #{E:status-right-style}]#[push-default]${status_2}#[pop-default]#[norange bg=${resolved_accent_color}]"
            tmux set-option -g status-format[1] "$plugins_format"
        fi
        tmux set-option -g status-right ""
    else
        # Single layout: plugins on right side, with final separator
        if [[ -n "$status_2" ]]; then
            tmux set-option -g status-right "$status_2"
        else
            tmux set-option -g status-right ""
        fi
        
        # Apply complete status format with final separator
        local resolved_accent_color=$(get_powerkit_color 'surface')
        local complete_format=$(build_single_layout_status_format "$resolved_accent_color")
        tmux set-option -g status-format[0] "$complete_format"
    fi
    
    # Remove window separator for seamless powerline appearance
    tmux set-window-option -g window-status-separator ""
}

# =============================================================================
# EXECUTE INITIALIZATION 
# =============================================================================


# Ensure cache directory exists before checking keybinding conflicts
cache_init

# Check for keybinding conflicts before registering
plugins_string=$(get_tmux_option "@powerkit_plugins" "$POWERKIT_DEFAULT_PLUGINS")
check_keybinding_conflicts "$plugins_string"

# Initialize the complete PowerKit system
initialize_powerkit

# Register helper keybindings
register_helper_keybindings

# Register cache clear keybinding
setup_cache_keybinding
