#!/usr/bin/env bash
# =============================================================================
# PowerKit Source Guard Helper
# Prevents multiple sourcing of files for performance
# =============================================================================

# Source guard function - returns 0 if already loaded (should return), 1 if first load
# Usage: source_guard "module_name" && return 0
# Example: source_guard "cache" && return 0
source_guard() {
    local module_name="$1"
    local guard_var="_POWERKIT_${module_name^^}_LOADED"
    guard_var="${guard_var//-/_}"

    # Check if already loaded
    if [[ -n "${!guard_var:-}" ]]; then
        return 0  # Already loaded, caller should return
    fi

    # Mark as loaded using declare -g for global scope
    declare -g "$guard_var=1"
    return 1  # First load, caller should continue
}
