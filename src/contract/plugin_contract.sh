#!/usr/bin/env bash
# =============================================================================
#  PLUGIN CONTRACT
#  Plugin contract interface and initialization
# =============================================================================
#
# TABLE OF CONTENTS
# =================
#   1. Overview
#   2. Contract Concepts (STATE, HEALTH, CONTEXT)
#   3. API Reference (Mandatory & Optional Functions)
#   4. Dependency Checking Helpers
#   5. Threshold Health Evaluation Helpers
#   6. Platform-Specific Execution Helpers
#   7. Common Plugin Data Helpers
#   8. Constants (from registry.sh)
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
#
# STALE INDICATOR (Lifecycle-managed)
# -----------------------------------
# The lifecycle automatically tracks data freshness. When plugin_collect()
# fails (returns non-zero), the lifecycle preserves previous cache and marks
# the output as "stale". This triggers visual indication (darker colors).
#
# How it works:
#   1. plugin_collect() returns 1 on failure (e.g., API timeout)
#   2. Lifecycle preserves existing cached data
#   3. Output is marked with stale=1 (5th field in lifecycle output)
#   4. Renderer applies -darker color variant for visual feedback
#
# Plugin implementation for stale-while-revalidate:
#   plugin_collect() {
#       local result
#       result=$(fetch_api_data) || return 1  # Return 1 on failure
#       plugin_data_set "value" "$result"
#   }
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
#   plugin_get_state()         - Return "inactive", "active", "degraded", "failed"
#   plugin_get_health()        - Return "ok", "good", "info", "warning", "error"
#
# FUNCTIONS WITH DEFAULTS (override only if needed):
#
#   plugin_get_content_type()  - Default: "dynamic" (most plugins)
#   plugin_get_presence()      - Default: "conditional" (hide when inactive)
#   plugin_get_context()       - Default: no-op (empty context)
#   plugin_check_dependencies()- Default: return 0 (no dependencies)
#   plugin_get_metadata()      - Default: no-op (id from filename)
#
# OPTIONAL FUNCTIONS (no default, implement if needed):
#
#   plugin_declare_options()     - Declare configurable options
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
#
# FROM REGISTRY.SH:
#   get_health_level HEALTH      - Get numeric level for health comparison
#   health_max HEALTH1 HEALTH2   - Get the more severe health level
#
# =============================================================================
# END OF DOCUMENTATION
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "contract_plugin" && return 0

# Note: All core and utils modules are loaded by bootstrap.sh
# This contract only defines the plugin interface specification

# Load binary manager for macOS native binaries (optional, only used by macOS plugins)
# Provides: require_macos_binary()
. "${POWERKIT_ROOT}/src/core/binary_manager.sh"

# =============================================================================
# State and Health Constants
# =============================================================================

# Note: All constants and validation functions are defined in registry.sh
# Available from registry.sh:
#   - PLUGIN_STATES: inactive, active, degraded, failed
#   - PLUGIN_CONTENT_TYPES: static, dynamic
#   - PLUGIN_PRESENCE_MODES: always, conditional (alias: PLUGIN_PRESENCE)
#   - HEALTH_LEVELS: ok, good, info, warning, error (alias: PLUGIN_HEALTH)
#   - HEALTH_PRECEDENCE: associative array with numeric levels
#   - is_valid_state(), is_valid_health(), is_valid_content_type(), is_valid_presence()
#   - get_health_level(), health_max(), health_is_worse()

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
# NOTE: Plugin Output colors are determined by the RENDERER based on state/health
# Plugins should NOT decide colors - use plugin_get_state() and plugin_get_health()
# The renderer uses color_resolver.sh to map state/health → colors
#
# Validation and health functions are available from registry.sh:
#   - is_valid_state(), is_valid_health(), is_valid_content_type(), is_valid_presence()
#   - get_health_level(), health_max(), health_is_worse()
# =============================================================================

# =============================================================================
# Threshold Health Evaluation Helpers
# =============================================================================
# These helpers reduce code duplication across plugins that use threshold-based
# health determination (cpu, memory, disk, battery, temperature, etc.)

# Evaluate health based on value and thresholds
# Usage: evaluate_threshold_health value warn_threshold crit_threshold [invert]
# Arguments:
#   value           - Current numeric value to evaluate
#   warn_threshold  - Threshold for warning state
#   crit_threshold  - Threshold for error/critical state
#   invert          - Optional: 1 = lower values are worse (e.g., battery)
#                              0 = higher values are worse (default, e.g., CPU)
# Returns: "ok", "warning", or "error"
#
# Examples:
#   # CPU at 85% with warn=70, crit=90 → "warning"
#   evaluate_threshold_health 85 70 90
#
#   # Battery at 15% with warn=30, crit=15, inverted → "error"
#   evaluate_threshold_health 15 30 15 1
#
evaluate_threshold_health() {
    local value="$1"
    local warn="$2"
    local crit="$3"
    local invert="${4:-0}"

    # Handle non-numeric values
    [[ ! "$value" =~ ^[0-9]+$ ]] && { printf 'ok'; return; }

    if [[ "$invert" -eq 1 ]]; then
        # Lower values are worse (battery, signal strength)
        if (( value <= crit )); then
            printf 'error'
        elif (( value <= warn )); then
            printf 'warning'
        else
            printf 'ok'
        fi
    else
        # Higher values are worse (CPU, memory, temperature)
        if (( value >= crit )); then
            printf 'error'
        elif (( value >= warn )); then
            printf 'warning'
        else
            printf 'ok'
        fi
    fi
}

# Evaluate health with decimal/float support
# Usage: evaluate_threshold_health_float value warn_threshold crit_threshold [invert]
# Same as evaluate_threshold_health but supports decimal values
evaluate_threshold_health_float() {
    local value="$1"
    local warn="$2"
    local crit="$3"
    local invert="${4:-0}"

    # Handle non-numeric values
    [[ ! "$value" =~ ^[0-9]+\.?[0-9]*$ ]] && { printf 'ok'; return; }

    if [[ "$invert" -eq 1 ]]; then
        if (( $(echo "$value <= $crit" | bc -l 2>/dev/null || echo 0) )); then
            printf 'error'
        elif (( $(echo "$value <= $warn" | bc -l 2>/dev/null || echo 0) )); then
            printf 'warning'
        else
            printf 'ok'
        fi
    else
        if (( $(echo "$value >= $crit" | bc -l 2>/dev/null || echo 0) )); then
            printf 'error'
        elif (( $(echo "$value >= $warn" | bc -l 2>/dev/null || echo 0) )); then
            printf 'warning'
        else
            printf 'ok'
        fi
    fi
}

# =============================================================================
# Platform-Specific Execution Helpers
# =============================================================================
# These helpers reduce platform detection boilerplate across plugins

# Get platform-specific value
# Usage: get_platform_value "macos_value" "linux_value" ["freebsd_value"]
# Returns the appropriate value based on current platform
#
# Example:
#   cmd=$(get_platform_value "pmset -g batt" "upower -i /org/freedesktop/UPower/devices/battery_BAT0")
#
get_platform_value() {
    local macos_val="$1"
    local linux_val="$2"
    local freebsd_val="${3:-$2}"

    if is_macos; then
        printf '%s' "$macos_val"
    elif is_freebsd; then
        printf '%s' "$freebsd_val"
    else
        printf '%s' "$linux_val"
    fi
}

# Execute platform-specific function
# Usage: run_platform_func "macos_func" "linux_func" ["freebsd_func"]
# Calls the appropriate function based on current platform
#
# Example:
#   run_platform_func "_collect_macos" "_collect_linux"
#
run_platform_func() {
    local macos_func="$1"
    local linux_func="$2"
    local freebsd_func="${3:-$2}"

    if is_macos; then
        "$macos_func"
    elif is_freebsd; then
        "$freebsd_func"
    else
        "$linux_func"
    fi
}

# Check if current platform is supported
# Usage: require_platform "macos" "linux"
# Returns 0 if current platform is in the list, 1 otherwise
#
# Example:
#   require_platform "macos" || return 1  # macOS only plugin
#   require_platform "linux" "freebsd" || return 1  # Linux/BSD only
#
require_platform() {
    local platform
    local current
    current=$(get_os)

    for platform in "$@"; do
        [[ "$current" == "$platform" ]] && return 0
    done

    log_debug "plugin_contract" "Platform not supported: $current (requires: $*)"
    return 1
}

# =============================================================================
# Common Plugin Data Helpers
# =============================================================================

# Set plugin data with validation
# Usage: plugin_data_set_validated "key" "value" "validator_func"
# Only sets the data if validator_func returns 0
plugin_data_set_validated() {
    local key="$1"
    local value="$2"
    local validator="$3"

    if [[ -n "$validator" ]] && type -t "$validator" &>/dev/null; then
        if "$validator" "$value"; then
            plugin_data_set "$key" "$value"
            return 0
        fi
        return 1
    fi

    plugin_data_set "$key" "$value"
}

# Set multiple plugin data at once
# Usage: plugin_data_set_multi "key1" "val1" "key2" "val2" ...
plugin_data_set_multi() {
    while [[ $# -ge 2 ]]; do
        plugin_data_set "$1" "$2"
        shift 2
    done
}

# =============================================================================
# Default Implementations (ISP - Interface Segregation Principle)
# =============================================================================
# These defaults reduce boilerplate in simple plugins. Plugins can override
# any of these functions by defining their own implementation.

# Default content type: dynamic (most plugins fetch real-time data)
plugin_get_content_type() { printf 'dynamic'; }

# Default presence: conditional (hide when inactive)
plugin_get_presence() { printf 'conditional'; }

# Default context: empty (no additional context)
plugin_get_context() { :; }

# Default dependency check: no dependencies required
plugin_check_dependencies() { return 0; }

# Default metadata: empty (id is derived from filename by lifecycle)
plugin_get_metadata() { :; }
