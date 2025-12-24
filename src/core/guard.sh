#!/usr/bin/env bash
# =============================================================================
# PowerKit Core: Source Guard
# Description: Prevents multiple sourcing of modules for performance
# =============================================================================

# Guard this file itself
[[ -n "${_POWERKIT_GUARD_LOADED:-}" ]] && return 0
declare -g _POWERKIT_GUARD_LOADED=1

# =============================================================================
# Source Guard Function
# =============================================================================

# Prevents multiple sourcing of a module
# Usage: source_guard "module_name" && return 0
# Returns: 0 if already loaded (caller should return), 1 if first load
source_guard() {
    local module_name="$1"
    local guard_var="_POWERKIT_${module_name^^}_LOADED"
    guard_var="${guard_var//-/_}"  # Replace hyphens with underscores

    if [[ -n "${!guard_var:-}" ]]; then
        return 0  # Already loaded
    fi

    declare -g "$guard_var=1"
    return 1  # First load, continue sourcing
}

# Check if a module is loaded without setting the guard
# Usage: is_module_loaded "module_name" && echo "loaded"
is_module_loaded() {
    local module_name="$1"
    local guard_var="_POWERKIT_${module_name^^}_LOADED"
    guard_var="${guard_var//-/_}"

    [[ -n "${!guard_var:-}" ]]
}

# Reset a module guard (useful for testing)
# Usage: reset_guard "module_name"
reset_guard() {
    local module_name="$1"
    local guard_var="_POWERKIT_${module_name^^}_LOADED"
    guard_var="${guard_var//-/_}"

    unset "$guard_var"
}

# Reset all PowerKit guards (useful for testing)
reset_all_guards() {
    local var
    for var in "${!_POWERKIT_@}"; do
        if [[ "$var" == *_LOADED ]]; then
            unset "$var"
        fi
    done
}
