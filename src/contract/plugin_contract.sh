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
#  PLUGIN CONTRACT - Version 2.0.0
#  Plugin contract interface and initialization
#
# =============================================================================
#
# TABLE OF CONTENTS
# =================
#   1. Overview
#   2. Contract Concepts (STATE, HEALTH, CONTEXT)
#   3. Mandatory Functions
#   4. Optional Functions
#   5. Initialization
#   6. Dependency Checking
#   7. State and Health Constants
#   8. Validation Helpers
#   9. API Reference
#
# =============================================================================
#
# 1. OVERVIEW
# ===========
#
# The Plugin Contract defines the interface that all PowerKit plugins must
# implement. Plugins provide data and semantics - NOT UI decisions.
#
# Key Principles:
#   - Plugins collect data and determine state/health
#   - Plugins NEVER decide colors (renderer handles that based on state/health)
#   - plugin_render() returns TEXT ONLY (no colors, no formatting)
#   - Icons can vary by context, but NOT by health
#
# =============================================================================
#
# 2. CONTRACT CONCEPTS
# ====================
#
# STATE (Required)
# ----------------
# The state describes the operational status of the plugin. It determines
# if the plugin should be shown.
#
# Valid values:
#   - "inactive" : Resource not present (e.g., no battery, VPN disconnected)
#   - "active"   : Working as expected
#   - "degraded" : Reduced functionality (e.g., API errors, partial data)
#   - "failed"   : Cannot function (e.g., missing auth, no connectivity)
#
#
# HEALTH (Required)
# -----------------
# The health describes the severity or quality of the plugin's current data.
# Used for coloring and alerts.
#
# Valid values:
#   - "ok"      : Normal operation
#   - "good"    : Better than ok (e.g., authenticated, unlocked)
#   - "info"    : Informational (e.g., charging, connected)
#   - "warning" : Needs attention (e.g., battery low, high CPU)
#   - "error"   : Critical (e.g., battery critical, auth failed)
#
#
# CONTEXT (Optional)
# ------------------
# Additional semantic information about the plugin's current situation.
#
# Examples by plugin:
#   - battery: "charging", "discharging", "full", "critical"
#   - cpu: "idle", "normal", "high_load"
#   - network: "wifi", "ethernet", "vpn"
#   - kubernetes: "production", "staging", "development"
#
# =============================================================================
#
# 3. API REFERENCE
# ================
#
# MANDATORY FUNCTIONS (every plugin must implement):
#
#   plugin_collect()           - Collect data using plugin_data_set()
#   plugin_render()            - Return TEXT ONLY (no colors, no icons)
#   plugin_get_icon()          - Return the icon to display
#   plugin_get_content_type()  - Return "static" or "dynamic"
#   plugin_get_presence()      - Return "always" or "conditional"
#   plugin_get_state()         - Return "inactive", "active", "degraded", "failed"
#   plugin_get_health()        - Return "ok", "good", "info", "warning", "error"
#
# OPTIONAL FUNCTIONS:
#
#   plugin_check_dependencies()  - Check required commands/files
#   plugin_declare_options()     - Declare configurable options
#   plugin_get_context()         - Return context flags
#   plugin_get_metadata()        - Set metadata using metadata_set()
#   plugin_setup_keybindings()   - Setup tmux keybindings
#
# DEPENDENCY HELPERS:
#
#   require_cmd CMD [optional]   - Require a command (optional=1 for soft req)
#   require_any_cmd CMD...       - Require at least one of these commands
#   check_dependencies CMD...    - Check multiple dependencies at once
#   get_missing_deps()           - Get list of missing required dependencies
#   get_missing_optional_deps()  - Get list of missing optional dependencies
#
# VALIDATION:
#
#   is_valid_state STATE         - Check if state is valid
#   is_valid_health HEALTH       - Check if health is valid
#   get_health_level HEALTH      - Get numeric precedence for health comparison
#   health_max HEALTH1 HEALTH2   - Get the more severe health level
#
# =============================================================================
# END OF DOCUMENTATION
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "contract_plugin" && return 0

. "${POWERKIT_ROOT}/src/core/logger.sh"
. "${POWERKIT_ROOT}/src/core/datastore.sh"
. "${POWERKIT_ROOT}/src/core/options.sh"
. "${POWERKIT_ROOT}/src/core/registry.sh"
. "${POWERKIT_ROOT}/src/utils/platform.sh"
. "${POWERKIT_ROOT}/src/utils/network.sh"
. "${POWERKIT_ROOT}/src/utils/strings.sh"
. "${POWERKIT_ROOT}/src/utils/keybinding.sh"
. "${POWERKIT_ROOT}/src/utils/validation.sh"

# =============================================================================
# State and Health Constants
# =============================================================================

# Note: These are now defined in registry.sh for centralization.
# These aliases are kept for backward compatibility.

# Valid plugin states
# shellcheck disable=SC2034
declare -gra PLUGIN_STATES=("${PLUGIN_STATES[@]:-inactive active degraded failed}")

# Valid plugin health levels
# shellcheck disable=SC2034
declare -gra PLUGIN_HEALTH=("${PLUGIN_HEALTH[@]:-ok good info warning error}")

# Valid content types
declare -gra PLUGIN_CONTENT_TYPES=(
    "static"   # Content doesn't change frequently
    "dynamic"  # Content changes frequently
)

# Valid presence modes
declare -gra PLUGIN_PRESENCE=(
    "always"       # Always show plugin
    "conditional"  # Show based on state
)

# =============================================================================
# Plugin Initialization
# =============================================================================

# Initialize a plugin with its name
# Usage: plugin_init "battery"
# This sets up the plugin context and calls optional contract functions
#
# NOTE: plugin_init() is called by the plugin LOADER, NOT by the plugin itself.
# Plugins should NOT call plugin_init() - it is an internal function.
plugin_init() {
    local plugin_name="$1"

    if [[ -z "$plugin_name" ]]; then
        log_error "plugin_contract" "plugin_init called without name"
        return 1
    fi

    # Set plugin context for datastore and options
    _set_plugin_context "$plugin_name"

    log_debug "plugin_contract" "Initializing plugin: $plugin_name"

    # Call optional contract functions if defined
    if declare -F plugin_check_dependencies &>/dev/null; then
        if ! plugin_check_dependencies; then
            log_warn "plugin_contract" "Dependencies not met for: $plugin_name"
        fi
    fi

    if declare -F plugin_declare_options &>/dev/null; then
        plugin_declare_options
    fi

    if declare -F plugin_get_metadata &>/dev/null; then
        plugin_get_metadata
    fi

    log_debug "plugin_contract" "Plugin initialized: $plugin_name"
}

# =============================================================================
# Dependency Checking Helpers
# =============================================================================

# Dependency tracking arrays
declare -ga _REQUIRED_DEPS=()
declare -ga _OPTIONAL_DEPS=()
declare -ga _MISSING_DEPS=()
declare -ga _MISSING_OPTIONAL_DEPS=()

# Reset dependency state
reset_dependency_check() {
    _REQUIRED_DEPS=()
    _OPTIONAL_DEPS=()
    _MISSING_DEPS=()
    _MISSING_OPTIONAL_DEPS=()
}

# Require a command (use in plugin_check_dependencies only)
# Usage: require_cmd "curl" || return 1
# Usage: require_cmd "jq" 1  # Optional (1 = optional)
require_cmd() {
    local cmd="$1"
    local optional="${2:-0}"

    if has_cmd "$cmd"; then
        return 0
    fi

    if [[ "$optional" == "1" ]]; then
        _OPTIONAL_DEPS+=("$cmd")
        _MISSING_OPTIONAL_DEPS+=("$cmd")
        log_debug "plugin_contract" "Optional dependency missing: $cmd"
        return 0  # Don't fail for optional
    else
        _REQUIRED_DEPS+=("$cmd")
        _MISSING_DEPS+=("$cmd")
        log_warn "plugin_contract" "Required dependency missing: $cmd"
        return 1
    fi
}

# Require at least one of the given commands
# Usage: require_any_cmd "nvidia-smi" "rocm-smi" || return 1
require_any_cmd() {
    local found=0
    local cmd

    for cmd in "$@"; do
        if has_cmd "$cmd"; then
            found=1
            break
        fi
    done

    if [[ "$found" -eq 0 ]]; then
        log_warn "plugin_contract" "None of the required commands found: $*"
        _MISSING_DEPS+=("one of: $*")
        return 1
    fi

    return 0
}

# Check multiple dependencies at once
# Usage: check_dependencies "curl" "jq" || return 1
check_dependencies() {
    local all_found=1
    local cmd

    for cmd in "$@"; do
        if ! has_cmd "$cmd"; then
            _MISSING_DEPS+=("$cmd")
            all_found=0
        fi
    done

    return $((1 - all_found))
}

# Get missing required dependencies
get_missing_deps() {
    printf '%s\n' "${_MISSING_DEPS[@]}"
}

# Get missing optional dependencies
get_missing_optional_deps() {
    printf '%s\n' "${_MISSING_OPTIONAL_DEPS[@]}"
}

# =============================================================================
# Option Declaration Helpers
# =============================================================================

# These are re-exported from options.sh for convenience:
# - declare_option "name" "type" "default" "description"
# - get_option "name"

# =============================================================================
# Health Precedence Helpers (use HEALTH_LEVELS from registry.sh)
# =============================================================================

# Get numeric precedence for health comparison
# Usage: get_health_level "warning"  # returns 2
# Uses HEALTH_LEVELS associative array from registry.sh
get_health_level() {
    local health="$1"
    echo "${HEALTH_LEVELS[$health]:-0}"
}

# Get the more severe health level between two
# Usage: health_max "warning" "error"  # returns "error"
# Delegates to registry.sh implementation
# This function is already available from registry.sh

# =============================================================================
# Contract Validation Helpers (use validate_against_enum from validation.sh)
# =============================================================================

# Check if a value is a valid state
# Usage: is_valid_state "active"
is_valid_state() {
    local state="$1"
    validate_against_enum "$state" PLUGIN_STATES
}

# Check if a value is a valid health
# Usage: is_valid_health "warning"
is_valid_health() {
    local health="$1"
    validate_against_enum "$health" PLUGIN_HEALTH
}

# Check if a value is a valid content type
# Usage: is_valid_content_type "dynamic"
is_valid_content_type() {
    local type="$1"
    validate_against_enum "$type" PLUGIN_CONTENT_TYPES
}

# Check if a value is a valid presence mode
# Usage: is_valid_presence "conditional"
is_valid_presence() {
    local presence="$1"
    validate_against_enum "$presence" PLUGIN_PRESENCE
}

# =============================================================================
# NOTE: Plugin Output colors are determined by the RENDERER based on state/health
# Plugins should NOT decide colors - use plugin_get_state() and plugin_get_health()
# The renderer uses color_resolver.sh to map state/health → colors
# =============================================================================
