#!/usr/bin/env bash
# =============================================================================
# PowerKit Core: Keybindings
# Description: Global keybindings configuration with data-driven approach
# =============================================================================
#
# This module uses a declarative configuration for keybindings, eliminating
# repetitive setup functions (DRY principle).
#
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "keybindings" && return 0

. "${POWERKIT_ROOT}/src/core/logger.sh"
. "${POWERKIT_ROOT}/src/core/options.sh"
. "${POWERKIT_ROOT}/src/core/defaults.sh"
. "${POWERKIT_ROOT}/src/utils/keybinding.sh"

# =============================================================================
# Core Keybindings Configuration (Data-Driven)
# =============================================================================
#
# Format: "type:key_option:key_default:width_option:width_default:height_option:height_default:helper:action"
#
# Types:
#   popup   - Opens display-popup -E with helper
#   shell   - Runs shell command (run-shell)
#   command - Custom tmux command
#
# Empty values use defaults or are skipped

declare -gA POWERKIT_CORE_KEYBINDINGS=(
    # Cache clear - special command (no helper file)
    [cache_clear]="command:@powerkit_cache_clear_key:C-d:::::"

    # Reload tmux config - special command (no helper file)
    [reload_config]="command:@powerkit_reload_config_key:r:::::"

    # Options viewer - popup
    [options_viewer]="popup:@powerkit_show_options_key:C-e:@powerkit_show_options_width:80%:@powerkit_show_options_height:60%:options_viewer.sh:"

    # Keybindings viewer - popup
    [keybindings_viewer]="popup:@powerkit_show_keybindings_key:C-y:@powerkit_show_keybindings_width:80%:@powerkit_show_keybindings_height:60%:keybindings_viewer.sh:"

    # Theme selector - shell (uses display-menu internally)
    [theme_selector]="shell:@powerkit_theme_selector_key:C-r:::::theme_selector.sh:select"

    # Log viewer - popup
    [log_viewer]="popup:@powerkit_log_viewer_key:M-l:@powerkit_log_viewer_width:80%:@powerkit_log_viewer_height:70%:log_viewer.sh:"
)

# =============================================================================
# Keybinding Conflict Detection
# =============================================================================

# Global storage for detected conflicts
declare -gA _KEYBINDING_CONFLICTS=()

# Check for keybinding conflicts and show notification if any
# Usage: check_keybinding_conflicts [plugins_string]
check_keybinding_conflicts() {
    local plugins_string="${1:-}"

    # Check conflict action setting
    local conflict_action
    conflict_action=$(get_tmux_option "@powerkit_keybinding_conflict_action" "${POWERKIT_DEFAULT_KEYBINDING_CONFLICT_ACTION}")

    # If ignore, skip all conflict detection
    if [[ "$conflict_action" == "ignore" ]]; then
        log_debug "keybindings" "Conflict detection disabled (action=ignore)"
        return 0
    fi

    local cache_dir
    cache_dir="$(dirname "$(get_cache_dir)")"
    local log_file="${cache_dir}/keybinding_conflicts.log"

    # Check if there's a conflict log from real-time detection
    if [[ -f "$log_file" && "$conflict_action" == "warn" ]]; then
        # Count conflicts
        local conflict_count
        conflict_count=$(grep -c "^  •" "$log_file" 2>/dev/null || echo "0")

        if [[ "$conflict_count" -gt 0 ]]; then
            # Add footer to log file if not already present
            if ! grep -q "Action:" "$log_file" 2>/dev/null; then
                {
                    echo ""
                    echo "Action: Conflicts logged but keybindings will still be registered."
                    echo "To skip registration, set: set -g @powerkit_keybinding_conflict_action skip"
                    echo ""
                    echo "To suppress this warning, set: set -g @powerkit_keybinding_conflict_action ignore"
                    echo ""
                    echo "To dismiss this warning permanently, delete this file:"
                    echo "  rm '$log_file'"
                } >> "$log_file"
            fi

            log_warn "keybindings" "Detected ${conflict_count} keybinding conflict(s). See $log_file"

            # Show popup notification with conflict details
            local helpers_dir="${POWERKIT_ROOT}/src/helpers"
            pk_popup_delayed 2 -w 80 -H 30 "bash '${helpers_dir}/keybinding_conflict_toast.sh'"
        fi
    else
        log_debug "keybindings" "No keybinding conflicts detected"
    fi
}

# =============================================================================
# Generic Keybinding Setup
# =============================================================================

# Setup a single keybinding from configuration
# Usage: _setup_keybinding NAME CONFIG_STRING
_setup_keybinding() {
    local name="$1"
    local config="$2"

    # Parse config: type:key_opt:key_def:width_opt:width_def:height_opt:height_def:helper:action
    IFS=':' read -r bind_type key_option key_default width_option width_default height_option height_default helper action <<< "$config"

    # Get key from tmux option or use default
    local key
    if [[ -n "$key_option" ]]; then
        key=$(get_tmux_option "$key_option" "$key_default")
    else
        key="$key_default"
    fi

    # Skip if key is empty (disabled)
    [[ -z "$key" ]] && {
        log_debug "keybindings" "Keybinding '$name' disabled (empty key)"
        return 0
    }

    # Get dimensions if applicable
    local width="" height=""
    if [[ -n "$width_option" ]]; then
        width=$(get_tmux_option "$width_option" "$width_default")
    elif [[ -n "$width_default" ]]; then
        width="$width_default"
    fi

    if [[ -n "$height_option" ]]; then
        height=$(get_tmux_option "$height_option" "$height_default")
    elif [[ -n "$height_default" ]]; then
        height="$height_default"
    fi

    # Build helper path if specified
    local helper_path=""
    if [[ -n "$helper" ]]; then
        helper_path="${POWERKIT_ROOT}/src/helpers/${helper}"
        if [[ ! -f "$helper_path" ]]; then
            log_warn "keybindings" "Helper not found for '$name': $helper_path"
            return 0
        fi
    fi

    # Setup based on type
    case "$bind_type" in
        popup)
            local cmd="bash '$helper_path'"
            if [[ -n "$action" ]]; then cmd="bash '$helper_path' $action"; fi
            pk_bind_popup "$key" "$cmd" "$width" "$height" "core:$name"
            ;;

        shell)
            local cmd="bash '$helper_path'"
            if [[ -n "$action" ]]; then cmd="bash '$helper_path' $action"; fi
            pk_bind_shell "$key" "$cmd" "core:$name"
            ;;

        command)
            # Special handling for built-in commands
            _setup_command_keybinding "$name" "$key"
            ;;

        *)
            log_warn "keybindings" "Unknown keybinding type '$bind_type' for '$name'"
            return 1
            ;;
    esac

    log_debug "keybindings" "Setup keybinding: $name -> $key ($bind_type)"
}

# Setup special command keybindings (not helper-based)
# Usage: _setup_command_keybinding NAME KEY
_setup_command_keybinding() {
    local name="$1"
    local key="$2"

    case "$name" in
        cache_clear)
            local cmd="POWERKIT_ROOT='${POWERKIT_ROOT}' bash -c '. \"\${POWERKIT_ROOT}/src/core/bootstrap.sh\" && powerkit_bootstrap_minimal && cache_clear_all && load_powerkit_theme && toast \"PowerKit cache cleared!\" \"info\"'; tmux refresh-client -S"
            pk_bind_smart "$key" "$cmd" -s "core:cache_clear"
            ;;
        reload_config)
            # Reload tmux config - tries common config paths, shows info-styled toast
            local cmd="if [ -f ~/.config/tmux/tmux.conf ]; then tmux source-file ~/.config/tmux/tmux.conf; elif [ -f ~/.tmux.conf ]; then tmux source-file ~/.tmux.conf; fi; POWERKIT_ROOT='${POWERKIT_ROOT}' bash -c '. \"\${POWERKIT_ROOT}/src/core/bootstrap.sh\" && load_powerkit_theme && toast \"TMUX configuration reloaded!\" \"info\"'"
            pk_bind_smart "$key" "$cmd" -s "core:reload_config"
            ;;
        *)
            log_warn "keybindings" "Unknown command keybinding: $name"
            return 1
            ;;
    esac
}

# =============================================================================
# Main Setup Function
# =============================================================================

# Setup all global PowerKit keybindings
# Usage: setup_powerkit_keybindings [plugins_string]
setup_powerkit_keybindings() {
    # shellcheck disable=SC2034 # Reserved for future use
    local plugins_string="${1:-}"

    log_debug "keybindings" "Setting up PowerKit global keybindings (data-driven)"

    # Iterate through all configured keybindings
    for name in "${!POWERKIT_CORE_KEYBINDINGS[@]}"; do
        _setup_keybinding "$name" "${POWERKIT_CORE_KEYBINDINGS[$name]}"
    done

    log_debug "keybindings" "Global keybindings setup complete (${#POWERKIT_CORE_KEYBINDINGS[@]} bindings)"
}

# =============================================================================
# Public API for Adding Keybindings
# =============================================================================

# Register a new core keybinding programmatically
# Usage: register_core_keybinding NAME TYPE KEY_OPT KEY_DEF [WIDTH_OPT WIDTH_DEF HEIGHT_OPT HEIGHT_DEF] HELPER [ACTION]
#
# Example:
#   register_core_keybinding "my_viewer" "popup" "@my_key" "C-m" "" "80%" "" "60%" "my_viewer.sh" ""
#
register_core_keybinding() {
    local name="$1"
    local bind_type="$2"
    local key_option="$3"
    local key_default="$4"
    local width_option="${5:-}"
    local width_default="${6:-}"
    local height_option="${7:-}"
    local height_default="${8:-}"
    local helper="${9:-}"
    local action="${10:-}"

    POWERKIT_CORE_KEYBINDINGS[$name]="${bind_type}:${key_option}:${key_default}:${width_option}:${width_default}:${height_option}:${height_default}:${helper}:${action}"

    log_debug "keybindings" "Registered core keybinding: $name"
}

# Get list of all registered core keybindings
# Usage: get_core_keybindings
get_core_keybindings() {
    for name in "${!POWERKIT_CORE_KEYBINDINGS[@]}"; do
        echo "$name"
    done | sort
}

# Get keybinding info by name
# Usage: get_core_keybinding_info NAME
get_core_keybinding_info() {
    local name="$1"
    echo "${POWERKIT_CORE_KEYBINDINGS[$name]:-}"
}

# =============================================================================
# Legacy Compatibility (deprecated - will be removed)
# =============================================================================

# These functions are kept for backwards compatibility but now delegate
# to the data-driven system

setup_cache_clear_keybinding() {
    _setup_keybinding "cache_clear" "${POWERKIT_CORE_KEYBINDINGS[cache_clear]}"
}

setup_options_viewer_keybinding() {
    _setup_keybinding "options_viewer" "${POWERKIT_CORE_KEYBINDINGS[options_viewer]}"
}

setup_keybindings_viewer_keybinding() {
    _setup_keybinding "keybindings_viewer" "${POWERKIT_CORE_KEYBINDINGS[keybindings_viewer]}"
}

setup_theme_selector_keybinding() {
    _setup_keybinding "theme_selector" "${POWERKIT_CORE_KEYBINDINGS[theme_selector]}"
}

setup_log_viewer_keybinding() {
    _setup_keybinding "log_viewer" "${POWERKIT_CORE_KEYBINDINGS[log_viewer]}"
}

log_debug "keybindings" "Keybindings module loaded (data-driven)"
