#!/usr/bin/env bash
# =============================================================================
# PowerKit Core: Options
# Description: Tmux options batch loader and plugin options API
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "options" && return 0

. "${POWERKIT_ROOT}/src/core/logger.sh"

# =============================================================================
# Options Storage
# =============================================================================

# Batch-loaded tmux options cache
declare -gA _TMUX_OPTIONS_CACHE=()
declare -g _TMUX_OPTIONS_LOADED=0


# Plugin declared options storage
# Format: _PLUGIN_OPTIONS[plugin] = "name\x1Ftype\x1Fdefault\x1Fdesc;name2\x1F..."
declare -gA _PLUGIN_OPTIONS=()


# Delimiter for option fields (ASCII Unit Separator)
declare -g _OPT_DELIM=$'\x1F'

# Plugin options value cache
declare -gA _PLUGIN_OPTIONS_CACHE=()

# Default options for all plugins (add here as needed)
_DEFAULT_PLUGIN_OPTIONS=(
    "show_only_on_threshold${_OPT_DELIM}bool${_OPT_DELIM}false${_OPT_DELIM}Only show when warning or critical threshold is exceeded"
)

# =============================================================================
# Tmux Options API
# =============================================================================

# Batch load all @powerkit_* options from tmux
# This reduces multiple tmux calls to a single one
_batch_load_tmux_options() {
    [[ "$_TMUX_OPTIONS_LOADED" -eq 1 ]] && return 0

    # Check if we're inside tmux
    if [[ -z "${TMUX:-}" ]]; then
        _TMUX_OPTIONS_LOADED=1
        return 0
    fi

    local output
    output=$(tmux show-options -g 2>/dev/null | grep '^@powerkit' || true)

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        # Parse: @powerkit_option "value" or @powerkit_option value
        if [[ "$line" =~ ^(@powerkit[a-zA-Z0-9_]+)[[:space:]]+\"?([^\"]*)\"?$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            _TMUX_OPTIONS_CACHE["$key"]="$value"
        fi
    done <<< "$output"

    _TMUX_OPTIONS_LOADED=1
}

# Inject default options for a plugin (call at start of plugin_declare_options)
_inject_default_plugin_options() {
    if [[ -z "$_CURRENT_PLUGIN" ]]; then
        log_error "options" "inject_default_plugin_options called without plugin context"
        return 1
    fi
    local opt
    for opt in "${_DEFAULT_PLUGIN_OPTIONS[@]}"; do
        # Só injeta se ainda não existir
        local name
        name="${opt%%${_OPT_DELIM}*}"
        local current_opts="${_PLUGIN_OPTIONS[$_CURRENT_PLUGIN]:-}"
        if [[ ",${current_opts}," != *,${name}${_OPT_DELIM}* ]]; then
            if [[ -n "$current_opts" ]]; then _PLUGIN_OPTIONS["$_CURRENT_PLUGIN"]+=";"; fi
            _PLUGIN_OPTIONS["$_CURRENT_PLUGIN"]+="$opt"
        fi
    done
}

# Get a tmux option with fallback default
# Usage: get_tmux_option "@powerkit_option" "default"
get_tmux_option() {
    local option="$1"
    local default="$2"

    _batch_load_tmux_options

    # Check cache first
    if [[ -n "${_TMUX_OPTIONS_CACHE[$option]+x}" ]]; then
        printf '%s' "${_TMUX_OPTIONS_CACHE[$option]}"
        return 0
    fi

    # Not in cache, try direct tmux call (for non-@powerkit options)
    if [[ -n "${TMUX:-}" ]]; then
        local value
        value=$(tmux show-option -gqv "$option" 2>/dev/null || true)
        if [[ -n "$value" ]]; then
            _TMUX_OPTIONS_CACHE["$option"]="$value"
            printf '%s' "$value"
            return 0
        fi
    fi

    printf '%s' "$default"
}

# Set a tmux option
# Usage: set_tmux_option "@powerkit_option" "value"
set_tmux_option() {
    local option="$1"
    local value="$2"

    if [[ -n "${TMUX:-}" ]]; then
        tmux set-option -g "$option" "$value" 2>/dev/null || true
        _TMUX_OPTIONS_CACHE["$option"]="$value"
    fi
}

# Clear tmux options cache (useful for reloading)
clear_tmux_options_cache() {
    _TMUX_OPTIONS_CACHE=()
    _TMUX_OPTIONS_LOADED=0
}

# =============================================================================
# Plugin Options Declaration API
# =============================================================================

# Declare a plugin option
# Usage: declare_option "name" "type" "default" "description"
# Types: string, number, bool, color, icon, key, path, enum
declare_option() {
    local name="$1"
    local type="$2"
    local default="$3"
    local description="$4"

    if [[ -z "$_CURRENT_PLUGIN" ]]; then
        log_error "options" "declare_option called without plugin context"
        return 1
    fi

    # Inject default plugin options automatically (only once per plugin)
    if [[ -z "${_PLUGIN_OPTIONS[$_CURRENT_PLUGIN]:-}" ]]; then
        _inject_default_plugin_options
    fi

    local entry="${name}${_OPT_DELIM}${type}${_OPT_DELIM}${default}${_OPT_DELIM}${description}"
    if [[ -n "${_PLUGIN_OPTIONS[$_CURRENT_PLUGIN]:-}" ]]; then
        _PLUGIN_OPTIONS["$_CURRENT_PLUGIN"]+=";"
    fi
    _PLUGIN_OPTIONS["$_CURRENT_PLUGIN"]+="$entry"
}


# Internal: shared logic for getting a plugin option value (with caching, validation)
# Usage: _get_option_value <plugin> <name>
_get_option_value() {
    local plugin="$1"
    local name="$2"

    if [[ -z "$plugin" ]]; then
        log_error "options" "_get_option_value called without plugin argument"
        return 1
    fi

    local cache_key="${plugin}:${name}"

    # Check value cache first
    if [[ -n "${_PLUGIN_OPTIONS_CACHE[$cache_key]+x}" ]]; then
        printf '%s' "${_PLUGIN_OPTIONS_CACHE[$cache_key]}"
        return 0
    fi

    # Find declared option to get type and default
    local opt_type="" opt_default=""
    _get_declared_option_info "$plugin" "$name" opt_type opt_default

    # Build tmux option name: @powerkit_plugin_<plugin>_<option>
    local tmux_opt="@powerkit_plugin_${plugin}_${name}"

    # Get value from tmux or use default
    local value
    value=$(get_tmux_option "$tmux_opt" "$opt_default")

    # Validate by type
    value=$(_validate_option_value "$value" "$opt_type" "$opt_default")

    # Cache and return
    _PLUGIN_OPTIONS_CACHE["$cache_key"]="$value"
    printf '%s' "$value"
}

# Get a declared option value with lazy loading and caching
# Usage: get_option "name"
get_option() {
    local name="$1"
    if [[ -z "$_CURRENT_PLUGIN" ]]; then
        log_error "options" "get_option called without plugin context"
        return 1
    fi
    _get_option_value "$_CURRENT_PLUGIN" "$name"
}

# Get a declared option value for a specific plugin (context-free)
# Usage: get_named_plugin_option "plugin" "name"
get_named_plugin_option() {
    local plugin="$1"
    local name="$2"
    if [[ -z "$plugin" ]]; then
        log_error "options" "get_named_plugin_option called without plugin argument"
        return 1
    fi
    _get_option_value "$plugin" "$name"
}

# Get declared option info (internal)
# Usage: _get_declared_option_info "plugin" "name" type_var default_var
_get_declared_option_info() {
    local _gdo_plugin="$1"
    local _gdo_name="$2"
    local -n _gdo_type_ref="$3"
    local -n _gdo_default_ref="$4"

    local _gdo_options="${_PLUGIN_OPTIONS[$_gdo_plugin]:-}"
    [[ -z "$_gdo_options" ]] && return 1

    local IFS=';'
    local _gdo_entry
    for _gdo_entry in $_gdo_options; do
        local _gdo_opt_name _gdo_opt_type _gdo_opt_default
        IFS="$_OPT_DELIM" read -r _gdo_opt_name _gdo_opt_type _gdo_opt_default _ <<< "$_gdo_entry"
        if [[ "$_gdo_opt_name" == "$_gdo_name" ]]; then
            _gdo_type_ref="$_gdo_opt_type"
            _gdo_default_ref="$_gdo_opt_default"
            return 0
        fi
    done

    return 1
}

# Validate option value by type
# Usage: _validate_option_value "value" "type" "default"
_validate_option_value() {
    local value="$1"
    local type="$2"
    local default="$3"

    case "$type" in
        number)
            if [[ ! "$value" =~ ^-?[0-9]+$ ]]; then
                printf '%s' "$default"
                return
            fi
            ;;
        bool)
            case "${value,,}" in
                true|yes|on|1) value="true" ;;
                false|no|off|0) value="false" ;;
                *) value="$default" ;;
            esac
            ;;
    esac

    printf '%s' "$value"
}

# Clear plugin options cache
# Usage: clear_options_cache [plugin_name]
clear_options_cache() {
    local plugin="${1:-}"

    if [[ -n "$plugin" ]]; then
        local key
        for key in "${!_PLUGIN_OPTIONS_CACHE[@]}"; do
            if [[ "$key" == "${plugin}:"* ]]; then
                unset "_PLUGIN_OPTIONS_CACHE[$key]"
            fi
        done
    else
        _PLUGIN_OPTIONS_CACHE=()
    fi
}

# Get all declared options for a plugin
# Usage: get_plugin_declared_options "plugin_name"
# Returns semicolon-separated list of options
get_plugin_declared_options() {
    local plugin="$1"
    printf '%s' "${_PLUGIN_OPTIONS[$plugin]:-}"
}

# Check if plugin has declared options
# Usage: has_declared_options "plugin_name"
has_declared_options() {
    local plugin="$1"
    [[ -n "${_PLUGIN_OPTIONS[$plugin]:-}" ]]
}

# Get all keybinding options for a plugin (options that start with "keybinding_")
# Usage: get_plugin_keybinding_options "plugin_name"
# Returns: One keybinding option name per line
get_plugin_keybinding_options() {
    local plugin="$1"
    local options="${_PLUGIN_OPTIONS[$plugin]:-}"
    [[ -z "$options" ]] && return 0

    local IFS=';'
    local entry
    for entry in $options; do
        local opt_name
        IFS="$_OPT_DELIM" read -r opt_name _ _ _ <<< "$entry"
        [[ "$opt_name" == keybinding_* ]] && printf '%s\n' "$opt_name"
    done
}

# =============================================================================
# Global Options Helpers
# =============================================================================

# Get global PowerKit option
# Usage: get_powerkit_option "option_name" "default"
get_powerkit_option() {
    local name="$1"
    local default="$2"
    get_tmux_option "@powerkit_${name}" "$default"
}

# Check if debug mode is enabled
is_debug_enabled() {
    local debug
    debug=$(get_powerkit_option "debug" "false")
    [[ "$debug" == "true" ]]
}

# Check if transparent mode is enabled
is_transparent_mode() {
    local transparent
    transparent=$(get_powerkit_option "transparent" "false")
    [[ "$transparent" == "true" ]]
}
