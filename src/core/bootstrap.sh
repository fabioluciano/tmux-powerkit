#!/usr/bin/env bash
# =============================================================================
# PowerKit Core: Bootstrap
# Description: Main entry point for loading all core modules
# =============================================================================

# Determine POWERKIT_ROOT if not set
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export POWERKIT_ROOT

# Source guard (must be first)
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "bootstrap" && return 0

# =============================================================================
# Module Loading Order (critical)
# =============================================================================

# Load core modules in dependency order
_load_core_modules() {
    # 1. Defaults (no dependencies except guard) - MUST be first
    . "${POWERKIT_ROOT}/src/core/defaults.sh"

    # 2. Logger (no dependencies except guard)
    . "${POWERKIT_ROOT}/src/core/logger.sh"

    # 3. Datastore (depends on logger)
    . "${POWERKIT_ROOT}/src/core/datastore.sh"

    # 4. Options (depends on logger)
    . "${POWERKIT_ROOT}/src/core/options.sh"

    # 5. Cache (depends on logger)
    . "${POWERKIT_ROOT}/src/core/cache.sh"

    # 6. Keybindings (depends on logger, options, defaults)
    . "${POWERKIT_ROOT}/src/core/keybindings.sh"

    # 7. Registry (constants and enums - depends on guard only)
    . "${POWERKIT_ROOT}/src/core/registry.sh"

    # 8. Color Generator (depends on logger)
    . "${POWERKIT_ROOT}/src/core/color_generator.sh"

    # 9. Color Palette (depends on color_generator)
    . "${POWERKIT_ROOT}/src/core/color_palette.sh"

    # 10. Theme Loader (depends on color_generator, options, cache)
    . "${POWERKIT_ROOT}/src/core/theme_loader.sh"

    # 11. Binary Manager (depends on cache, logger, platform)
    . "${POWERKIT_ROOT}/src/core/binary_manager.sh"

    # 12. Lifecycle (depends on all above)
    . "${POWERKIT_ROOT}/src/core/lifecycle.sh"

    log_debug "bootstrap" "Core modules loaded"
}

# Load utility modules
_load_utils_modules() {
    local utils_dir="${POWERKIT_ROOT}/src/utils"

    [[ -d "$utils_dir" ]] || return 0

    local file
    for file in "$utils_dir"/*.sh; do
        [[ -f "$file" ]] || continue
        # shellcheck disable=SC1090
        . "$file"
    done

    log_debug "bootstrap" "Utility modules loaded"
}

# Load contract modules
_load_contract_modules() {
    local contract_dir="${POWERKIT_ROOT}/src/contract"

    [[ -d "$contract_dir" ]] || return 0

    local file
    for file in "$contract_dir"/*.sh; do
        [[ -f "$file" ]] || continue
        # shellcheck disable=SC1090
        . "$file"
    done

    log_debug "bootstrap" "Contract modules loaded"
}

# Load renderer modules
_load_renderer_modules() {
    local renderer_dir="${POWERKIT_ROOT}/src/renderer"

    [[ -d "$renderer_dir" ]] || return 0

    local file
    for file in "$renderer_dir"/*.sh; do
        [[ -f "$file" ]] || continue
        # shellcheck disable=SC1090
        . "$file"
    done

    log_debug "bootstrap" "Renderer modules loaded"
}

# =============================================================================
# Bootstrap Functions
# =============================================================================

# Full PowerKit bootstrap
# Usage: powerkit_bootstrap
powerkit_bootstrap() {
    log_info "bootstrap" "PowerKit starting..."

    # Load all modules
    _load_core_modules
    _load_utils_modules
    _load_contract_modules
    _load_renderer_modules

    # Initialize debug mode from options
    local debug
    debug=$(get_tmux_option "@powerkit_debug" "false")
    set_debug "$debug"

    # Load theme
    load_powerkit_theme

    # Setup pane flash effect (if enabled)
    if declare -F pane_flash_setup &>/dev/null; then
        pane_flash_setup
    fi

    # Get plugins list for keybinding conflict detection
    local plugins_str
    plugins_str=$(get_tmux_option "@powerkit_plugins" "${POWERKIT_DEFAULT_PLUGINS}")

    # FIRST: Check for keybinding conflicts BEFORE registering any bindings
    check_keybinding_conflicts "$plugins_str"

    # THEN: Setup global keybindings
    setup_powerkit_keybindings "$plugins_str"

    # Initialize plugin keybindings
    # (Plugins are fully initialized lazily during render, but keybindings must be set at startup)
    _setup_plugin_keybindings "$plugins_str"

    log_info "bootstrap" "PowerKit bootstrap complete"
}

# Extract plugin names from a plugins string that may contain group() syntax
# Usage: _extract_plugin_names "plugin1,group(p2,p3),plugin4" -> "plugin1 p2 p3 plugin4"
_extract_plugin_names() {
    local input="$1"
    local result=""
    local len=${#input}
    local pos=0
    local current_plugin=""

    while [[ $pos -lt $len ]]; do
        local char="${input:$pos:1}"

        # Skip whitespace
        if [[ "$char" =~ [[:space:]] ]]; then
            ((pos++))
            continue
        fi

        # Check for group(...) syntax
        if [[ "${input:$pos:6}" == "group(" ]]; then
            pos=$((pos + 6))
            # Find matching closing parenthesis
            local paren_depth=1
            while [[ $pos -lt $len && $paren_depth -gt 0 ]]; do
                char="${input:$pos:1}"
                if [[ "$char" == "(" ]]; then
                    ((paren_depth++))
                elif [[ "$char" == ")" ]]; then
                    ((paren_depth--))
                elif [[ "$char" == "," && $paren_depth -eq 1 ]]; then
                    # Separator inside group - output current plugin
                    [[ -n "$current_plugin" ]] && result+="$current_plugin "
                    current_plugin=""
                    ((pos++))
                    continue
                elif [[ $paren_depth -gt 0 ]]; then
                    current_plugin+="$char"
                fi
                ((pos++))
            done
            # Output last plugin from group
            [[ -n "$current_plugin" ]] && result+="$current_plugin "
            current_plugin=""
            continue
        fi

        # Check for comma (separator between top-level items)
        if [[ "$char" == "," ]]; then
            [[ -n "$current_plugin" ]] && result+="$current_plugin "
            current_plugin=""
            ((pos++))
            continue
        fi

        # Regular character - add to current plugin name
        current_plugin+="$char"
        ((pos++))
    done

    # Output any remaining plugin
    [[ -n "$current_plugin" ]] && result+="$current_plugin "

    printf '%s' "$result"
}

# Setup keybindings for all plugins
# Usage: _setup_plugin_keybindings "plugin1,plugin2,..."
_setup_plugin_keybindings() {
    local plugins_str="$1"
    [[ -z "$plugins_str" ]] && return 0

    # NOTE: Core modules and utilities are already loaded by _load_core_modules() and _load_utils_modules()
    # No need to re-source them here

    # Extract plugin names (handles group() syntax)
    local plugin_names
    plugin_names=$(_extract_plugin_names "$plugins_str")

    # Get conflict action setting
    local conflict_action
    conflict_action=$(get_tmux_option "@powerkit_keybinding_conflict_action" "${POWERKIT_DEFAULT_KEYBINDING_CONFLICT_ACTION}")

    local plugin_name plugin_file
    for plugin_name in $plugin_names; do
        # Trim whitespace (uses nameref - zero subshells)
        trim_inplace plugin_name

        [[ -z "$plugin_name" ]] && continue
        # Skip external plugins (format: external("..."))
        [[ "$plugin_name" == external\(* ]] && continue

        plugin_file="${POWERKIT_ROOT}/src/plugins/${plugin_name}.sh"
        [[ ! -f "$plugin_file" ]] && continue

        # Set context and source plugin
        _set_plugin_context "$plugin_name"
        # shellcheck disable=SC1090
        . "$plugin_file"

        # Declare options first (needed for get_option)
        if declare -F plugin_declare_options &>/dev/null; then
            plugin_declare_options
        fi

        # Setup keybindings if function exists
        if declare -F plugin_setup_keybindings &>/dev/null; then
            # Check if we should skip due to conflicts (dynamic check)
            local should_setup=true

            if [[ "$conflict_action" == "skip" ]]; then
                # Check for conflicts with actual tmux bindings
                local _conflict_check_keys=()

                # Auto-discover keybinding options using data-driven approach
                # All keybinding options follow the pattern keybinding_*
                local keybinding_opts
                keybinding_opts=$(get_plugin_keybinding_options "$plugin_name")

                local kb_opt kb_value
                while IFS= read -r kb_opt; do
                    [[ -z "$kb_opt" ]] && continue
                    kb_value=$(get_option "$kb_opt" 2>/dev/null) || true
                    if [[ -n "$kb_value" ]]; then _conflict_check_keys+=("$kb_value"); fi
                done <<< "$keybinding_opts"

                # Check if any key conflicts with existing non-PowerKit binding
                local key
                for key in "${_conflict_check_keys[@]}"; do
                    local existing_cmd
                    existing_cmd=$(tmux list-keys -T prefix 2>/dev/null | grep -E "^bind-key[[:space:]]+-T[[:space:]]+prefix[[:space:]]+${key//[\/\\]/\\\\}" | grep -v "powerkit" | head -1 | awk '{$1=$2=$3=$4=""; print $0}' | sed 's/^ *//')

                    if [[ -n "$existing_cmd" ]]; then
                        log_info "bootstrap" "Skipping keybindings for $plugin_name: key '$key' already bound (action=skip)"
                        should_setup=false
                        break
                    fi
                done
            fi

            if [[ "$should_setup" == true ]]; then
                plugin_setup_keybindings
                log_debug "bootstrap" "Plugin keybindings setup: $plugin_name"
            fi
        fi

        # Unset plugin functions to avoid conflicts with next plugin
        unset -f plugin_get_metadata plugin_check_dependencies plugin_declare_options \
            plugin_get_content_type plugin_get_presence plugin_get_state plugin_get_health \
            plugin_get_context plugin_get_icon plugin_collect plugin_render plugin_setup_keybindings \
            2>/dev/null || true
    done
}

# Minimal bootstrap (just core, no plugins)
# Usage: powerkit_bootstrap_minimal
powerkit_bootstrap_minimal() {
    _load_core_modules
    _load_utils_modules
    # Load theme (cached, ~18ms) - needed for colors, toasts, etc.
    load_powerkit_theme
}

# Bootstrap and run full lifecycle
# Usage: powerkit_run
powerkit_run() {
    powerkit_bootstrap
    run_plugin_lifecycle
}

# =============================================================================
# Initialization
# =============================================================================

# Auto-load core and utils modules when this file is sourced
_load_core_modules
_load_utils_modules

log_debug "bootstrap" "Bootstrap module loaded"
