#!/usr/bin/env bash
# =============================================================================
#
#  ██████╗  ██████╗ ██╗    ██╗███████╗██████╗ ██╗  ██╗██╗████████╗
#  ██╔══██╗██╔═══██╗██║    ██║██╔════╝██╔══██╗██║ ██╔╝██║╚══██╔══╝
#  ██████╔╝██║   ██║██║ █╗ ██║█████╗  ██████╔╝█████╔╝ ██║   ██║
#  ██╔═══╝ ██║   ██║██║███╗██║██╔══╝  ██╔══██╗██╔═██╗ ██║   ██║
#  ██║     ╚██████╔╝╚███╔███╔╝███████╗██║  ██║██║  ██╗██║   ██║
#  ╚═╝      ╚═════╝  ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝   ╚═╝
#
#  PLUGIN VALIDATOR - Version 1.0.0
#  Contract compliance checker for PowerKit plugins
#
# =============================================================================
#
# TABLE OF CONTENTS
# =================
#   1. Overview
#   2. Contract Requirements
#   3. API Reference
#   4. Usage Examples
#
# =============================================================================
#
# 1. OVERVIEW
# ===========
#
# The Plugin Validator ensures that plugins comply with the plugin contract.
# It checks for mandatory functions, validates syntax, and provides helpful
# feedback for developers.
#
# =============================================================================
#
# 2. CONTRACT REQUIREMENTS
# ========================
#
# MANDATORY FUNCTIONS (every plugin must implement):
#
#   plugin_collect()           - Collect data using plugin_data_set() only
#   plugin_render()            - Return TEXT ONLY (no colors, no icons)
#   plugin_get_icon()          - Return the icon to display
#   plugin_get_content_type()  - Return "static" or "dynamic"
#   plugin_get_presence()      - Return "always" or "conditional"
#   plugin_get_state()         - Return "inactive", "active", "degraded", or "failed"
#   plugin_get_health()        - Return "ok", "good", "info", "warning", or "error"
#
# OPTIONAL FUNCTIONS:
#
#   plugin_check_dependencies()  - Check required commands/files exist
#   plugin_declare_options()     - Declare configurable options
#   plugin_get_context()         - Return context flags (e.g., "charging")
#   plugin_get_metadata()        - Set metadata using metadata_set()
#   plugin_setup_keybindings()   - Setup tmux keybindings
#
# =============================================================================
#
# 3. API REFERENCE
# ================
#
#   validate_plugin FILE
#       Validate a single plugin file for contract compliance.
#       Returns: 0 if valid, 1 if invalid
#       Output: Validation result with errors and warnings
#
#   validate_all_plugins DIRECTORY
#       Validate all plugins in a directory.
#       Returns: 0 if all valid, 1 if any invalid
#       Output: Summary of validation results
#
#   list_mandatory_plugin_functions
#       List all mandatory plugin functions.
#       Output: One function name per line
#
#   list_optional_plugin_functions
#       List all optional plugin functions.
#       Output: One function name per line
#
# =============================================================================
#
# 4. USAGE EXAMPLES
# =================
#
#   # Validate a single plugin
#   validate_plugin "src/plugins/battery.sh"
#
#   # Validate all plugins
#   validate_all_plugins "src/plugins"
#
#   # Check what functions are required
#   list_mandatory_plugin_functions
#
# =============================================================================
# END OF DOCUMENTATION
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "contract_plugin_validator" && return 0

# Note: All core and utils modules are loaded by bootstrap.sh

# =============================================================================
# Contract Function Lists
# =============================================================================

# Mandatory plugin functions
declare -gra PLUGIN_MANDATORY_FUNCTIONS=(
    "plugin_collect"
    "plugin_get_content_type"
    "plugin_get_presence"
    "plugin_get_state"
    "plugin_get_health"
    "plugin_get_icon"
    "plugin_render"
)

# Optional plugin functions
declare -gra PLUGIN_OPTIONAL_FUNCTIONS=(
    "plugin_check_dependencies"
    "plugin_declare_options"
    "plugin_get_context"
    "plugin_get_metadata"
    "plugin_setup_keybindings"
)

# Deprecated functions (should not be present)
declare -gra PLUGIN_DEPRECATED_FUNCTIONS=(
    "plugin_get_display_info"
    "plugin_get_type"
    "load_plugin"
)

# =============================================================================
# Single Plugin Validation
# =============================================================================

# Validate a plugin file for contract compliance
# Usage: validate_plugin "/path/to/plugin.sh"
# Returns: 0 if valid, 1 if invalid
validate_plugin() {
    local plugin_file="$1"
    local -a errors=()
    local -a warnings=()
    local -a info=()

    # Check file exists
    if [[ ! -f "$plugin_file" ]]; then
        echo "ERROR: Plugin file not found: $plugin_file"
        return 1
    fi

    # Check file is readable
    if [[ ! -r "$plugin_file" ]]; then
        echo "ERROR: Plugin file not readable: $plugin_file"
        return 1
    fi

    # Check syntax
    local syntax_errors
    syntax_errors=$(bash -n "$plugin_file" 2>&1)
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Plugin has syntax errors: $plugin_file"
        echo "$syntax_errors"
        return 1
    fi

    # Source plugin in subshell to check functions
    local missing_mandatory
    missing_mandatory=$(
        (
            # shellcheck disable=SC1090
            . "$plugin_file" 2>/dev/null

            for func in "${PLUGIN_MANDATORY_FUNCTIONS[@]}"; do
                if ! declare -F "$func" &>/dev/null; then
                    echo "$func"
                fi
            done
        )
    )

    if [[ -n "$missing_mandatory" ]]; then
        while IFS= read -r func; do
            [[ -n "$func" ]] && errors+=("Missing mandatory function: $func")
        done <<< "$missing_mandatory"
    fi

    # Check for deprecated functions
    local deprecated_found
    deprecated_found=$(
        (
            # shellcheck disable=SC1090
            . "$plugin_file" 2>/dev/null

            for func in "${PLUGIN_DEPRECATED_FUNCTIONS[@]}"; do
                declare -F "$func" &>/dev/null && echo "$func"
            done
        )
    )

    if [[ -n "$deprecated_found" ]]; then
        while IFS= read -r func; do
            [[ -n "$func" ]] && warnings+=("Deprecated function found: $func (should be removed)")
        done <<< "$deprecated_found"
    fi

    # Check for optional functions and provide suggestions
    local optional_present
    optional_present=$(
        (
            # shellcheck disable=SC1090
            . "$plugin_file" 2>/dev/null

            for func in "${PLUGIN_OPTIONAL_FUNCTIONS[@]}"; do
                declare -F "$func" &>/dev/null && echo "$func"
            done
        )
    )

    # Suggest implementing options if not present
    if ! echo "$optional_present" | grep -q "plugin_declare_options"; then
        info+=("Consider implementing plugin_declare_options() for better configurability")
    fi

    # Suggest implementing metadata
    if ! echo "$optional_present" | grep -q "plugin_get_metadata"; then
        info+=("Consider implementing plugin_get_metadata() for plugin discovery")
    fi

    # Check for common anti-patterns
    if grep -q "accent_color" "$plugin_file" 2>/dev/null; then
        warnings+=("Found 'accent_color' option - colors should be determined by renderer based on state/health")
    fi

    if grep -q '#\[fg=' "$plugin_file" 2>/dev/null; then
        warnings+=("Found tmux color codes in plugin - plugin_render() should return TEXT ONLY")
    fi

    # Output results
    local plugin_name
    plugin_name=$(basename "$plugin_file" .sh)

    if [[ ${#errors[@]} -eq 0 ]]; then
        echo "Plugin '$plugin_name': VALID"

        if [[ ${#warnings[@]} -gt 0 ]]; then
            for warn in "${warnings[@]}"; do
                echo "  WARNING: $warn"
            done
        fi

        if [[ ${#info[@]} -gt 0 ]]; then
            for inf in "${info[@]}"; do
                echo "  INFO: $inf"
            done
        fi

        return 0
    else
        echo "Plugin '$plugin_name': INVALID"

        for err in "${errors[@]}"; do
            echo "  ERROR: $err"
        done

        for warn in "${warnings[@]}"; do
            echo "  WARNING: $warn"
        done

        return 1
    fi
}

# =============================================================================
# Batch Validation
# =============================================================================

# Validate all plugins in a directory
# Usage: validate_all_plugins "/path/to/plugins"
validate_all_plugins() {
    local plugins_dir="$1"
    local total=0
    local valid=0
    local invalid=0

    echo "Validating plugins in: $plugins_dir"
    echo "---"

    local plugin_file
    for plugin_file in "$plugins_dir"/*.sh; do
        [[ -f "$plugin_file" ]] || continue
        ((total++))

        if validate_plugin "$plugin_file"; then
            ((valid++))
        else
            ((invalid++))
        fi
        echo ""
    done

    echo "---"
    echo "Total: $total, Valid: $valid, Invalid: $invalid"

    [[ $invalid -eq 0 ]]
}

# =============================================================================
# Utility Functions
# =============================================================================

# Get list of mandatory plugin functions
list_mandatory_plugin_functions() {
    printf '%s\n' "${PLUGIN_MANDATORY_FUNCTIONS[@]}"
}

# Get list of optional plugin functions
list_optional_plugin_functions() {
    printf '%s\n' "${PLUGIN_OPTIONAL_FUNCTIONS[@]}"
}

# Get list of deprecated plugin functions
list_deprecated_plugin_functions() {
    printf '%s\n' "${PLUGIN_DEPRECATED_FUNCTIONS[@]}"
}

# Check if a function is mandatory
is_mandatory_plugin_function() {
    local func="$1"
    local mandatory
    for mandatory in "${PLUGIN_MANDATORY_FUNCTIONS[@]}"; do
        [[ "$func" == "$mandatory" ]] && return 0
    done
    return 1
}

# Check if a function is optional
is_optional_plugin_function() {
    local func="$1"
    local optional
    for optional in "${PLUGIN_OPTIONAL_FUNCTIONS[@]}"; do
        [[ "$func" == "$optional" ]] && return 0
    done
    return 1
}

# Check if a function is deprecated
is_deprecated_plugin_function() {
    local func="$1"
    local deprecated
    for deprecated in "${PLUGIN_DEPRECATED_FUNCTIONS[@]}"; do
        [[ "$func" == "$deprecated" ]] && return 0
    done
    return 1
}
