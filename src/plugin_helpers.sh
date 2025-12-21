#!/usr/bin/env bash
# =============================================================================
# Plugin Helper Functions
# Lightweight utilities for plugins - no rendering functionality
# =============================================================================
#
# GLOBAL VARIABLES SET:
#   - CACHE_KEY, CACHE_TTL (set by plugin_init)
#   - PLUGIN_DEPS_MISSING (array of missing dependencies)
#
# FUNCTIONS PROVIDED:
#   - plugin_init(), get_plugin_option(), get_cached_option(), normalize_plugin_name()
#   - require_cmd(), require_any_cmd(), check_dependencies(), get_missing_deps()
#   - default_plugin_display_info()
#   - run_with_timeout(), safe_curl()
#   - validate_range(), validate_option(), validate_bool()
#   - apply_threshold_colors()
#   - make_api_call(), detect_audio_backend()
#   - join_with_separator(), format_repo_metrics(), truncate_text()
#
# DEPENDENCIES: source_guard.sh, utils.sh
# =============================================================================

# Source guard - use local variable to avoid overwriting plugin's ROOT_DIR
_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=src/source_guard.sh
. "$_HELPERS_DIR/source_guard.sh"
source_guard "plugin_helpers" && return 0

# shellcheck source=src/utils.sh
. "$_HELPERS_DIR/utils.sh"

# =============================================================================
# Dependency Checking System
# =============================================================================
#
# Plugin Contract: plugin_check_dependencies()
# --------------------------------------------
# Every plugin SHOULD implement this function to declare its dependencies.
# This allows the system to:
#   1. Check dependencies before loading the plugin
#   2. Provide helpful error messages to users
#   3. Skip loading plugins with missing dependencies
#
# Function signature:
#   plugin_check_dependencies()
#
# Return value:
#   0 - All required dependencies are available
#   1 - One or more required dependencies are missing
#
# Usage in plugin:
#   plugin_check_dependencies() {
#       # Required dependencies (plugin won't work without these)
#       require_cmd "curl" || return 1
#       require_cmd "jq" || return 1
#
#       # Optional dependencies (plugin works but with reduced features)
#       require_cmd "fzf" 1  # 1 = optional
#
#       # Alternative dependencies (need at least one)
#       require_any_cmd "nvidia-smi" "rocm-smi" || return 1
#
#       return 0
#   }
#
# =============================================================================

# Global array for missing dependencies
declare -ga PLUGIN_DEPS_MISSING=()

# Global array for optional missing dependencies (warnings only)
declare -ga PLUGIN_DEPS_OPTIONAL_MISSING=()

# Check if a command exists
# Usage: require_cmd <command> [optional]
# Returns: 0 if exists, 1 if missing
# If optional=1, missing is logged but doesn't fail
require_cmd() {
    local cmd="$1"
    local optional="${2:-0}"

    if command -v "$cmd" &>/dev/null; then
        return 0
    fi

    if [[ "$optional" == "1" ]]; then
        PLUGIN_DEPS_OPTIONAL_MISSING+=("$cmd")
        return 0
    fi

    PLUGIN_DEPS_MISSING+=("$cmd")
    # Log missing dependency if we have a plugin context
    [[ -n "${CACHE_KEY:-}" ]] && log_missing_dep "${CACHE_KEY}" "$cmd"
    return 1
}

# Check if ANY of the commands exists (for dependency contract)
# Usage: require_any_cmd <cmd1> <cmd2> ...
# Returns: 0 if at least one exists, 1 if all missing
require_any_cmd() {
    local found=0
    for cmd in "$@"; do
        if command -v "$cmd" &>/dev/null; then
            found=1
            break
        fi
    done

    if [[ $found -eq 0 ]]; then
        PLUGIN_DEPS_MISSING+=("one of: $*")
        return 1
    fi
    return 0
}

# =============================================================================
# Command Existence Check (for plugin logic, NOT dependency contract)
# =============================================================================

# Simple command existence check - use this in plugin logic
# Usage: has_cmd <command>
# Returns: 0 if exists, 1 if not
# NOTE: This does NOT affect dependency arrays - use for runtime logic only
has_cmd() {
    command -v "$1" &>/dev/null
}

# Check multiple dependencies at once
# Usage: check_dependencies <cmd1> <cmd2> ...
# Returns: 0 if all exist, 1 if any missing
check_dependencies() {
    local all_found=1
    PLUGIN_DEPS_MISSING=()

    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            PLUGIN_DEPS_MISSING+=("$cmd")
            all_found=0
        fi
    done

    return $((1 - all_found))
}

# Get list of missing dependencies as string
# Usage: get_missing_deps
get_missing_deps() {
    [[ ${#PLUGIN_DEPS_MISSING[@]} -eq 0 ]] && return
    printf '%s' "${PLUGIN_DEPS_MISSING[*]}"
}

# Get list of optional missing dependencies as string
# Usage: get_missing_optional_deps
get_missing_optional_deps() {
    [[ ${#PLUGIN_DEPS_OPTIONAL_MISSING[@]} -eq 0 ]] && return
    printf '%s' "${PLUGIN_DEPS_OPTIONAL_MISSING[*]}"
}

# Reset dependency arrays (call before checking new plugin)
# Usage: reset_dependency_check
reset_dependency_check() {
    PLUGIN_DEPS_MISSING=()
    PLUGIN_DEPS_OPTIONAL_MISSING=()
}

# Check if plugin implements dependency check and run it
# Usage: run_plugin_dependency_check
# Returns: 0 if dependencies met (or no check defined), 1 if missing
run_plugin_dependency_check() {
    reset_dependency_check

    # Check if plugin implements the contract
    if declare -f plugin_check_dependencies &>/dev/null; then
        if ! plugin_check_dependencies; then
            local missing
            missing=$(get_missing_deps)
            [[ -n "$missing" ]] && log_error "${CACHE_KEY:-plugin}" "Missing dependencies: $missing"
            return 1
        fi

        # Log optional missing deps as warnings
        local optional_missing
        optional_missing=$(get_missing_optional_deps)
        [[ -n "$optional_missing" ]] && log_warn "${CACHE_KEY:-plugin}" "Optional dependencies not found: $optional_missing (some features may be unavailable)"
    fi

    return 0
}

# =============================================================================
# Plugin Display Info Helpers
# =============================================================================

# Default plugin_get_display_info implementation (DRY - reduces boilerplate)
# Handles common case: hide if content is empty/N/A, show otherwise
# Usage: default_plugin_display_info "<content>" [<hide_values>...]
#
# Parameters:
#   content: plugin content to check
#   hide_values: optional list of values that should hide the plugin (default: "" "N/A")
#
# Returns: formatted display info via build_display_info
#
# Example usage in plugin:
#   plugin_get_display_info() {
#       default_plugin_display_info "${1:-}"
#   }
#
# Example with custom hide values:
#   plugin_get_display_info() {
#       default_plugin_display_info "${1:-}" "" "N/A" "0" "0 updates"
#   }
default_plugin_display_info() {
    local content="$1"
    shift

    # Default hide values if none provided
    local hide_values=("$@")
    [[ ${#hide_values[@]} -eq 0 ]] && hide_values=("" "N/A")

    # Check if content matches any hide value
    for hide_val in "${hide_values[@]}"; do
        [[ "$content" == "$hide_val" ]] && { build_display_info "0" "" "" ""; return; }
    done

    # Show plugin with default colors
    build_display_info "1" "" "" ""
}

# =============================================================================
# Timeout and Safe Execution
# =============================================================================

# Run command with timeout
# Usage: run_with_timeout <seconds> <command> [args...]
# Returns: command exit code or 124 on timeout
run_with_timeout() {
    local timeout_sec="$1"
    shift

    # Use timeout command if available (Linux), gtimeout (macOS with coreutils)
    if command -v timeout &>/dev/null; then
        timeout "$timeout_sec" "$@"
    elif command -v gtimeout &>/dev/null; then
        gtimeout "$timeout_sec" "$@"
    else
        # Fallback: run without timeout
        "$@"
    fi
}

# Safe curl with timeout and error handling
# Usage: safe_curl <url> [timeout] [extra_args...]
# Returns: curl output or empty on error
safe_curl() {
    local url="$1"
    local timeout="${2:-5}"
    shift 2 2>/dev/null || shift 1
    local extra_args=("$@")

    curl -sf \
        --connect-timeout "$timeout" \
        --max-time "$((timeout * 2))" \
        "${extra_args[@]}" \
        "$url" 2>/dev/null
}

# =============================================================================
# Configuration Validation
# =============================================================================

# Validate numeric value within range
# Usage: validate_range <value> <min> <max> <default>
# Returns: value if valid, default otherwise
validate_range() {
    local value="$1"
    local min="$2"
    local max="$3"
    local default="$4"

    # Check if numeric
    if [[ ! "$value" =~ ^-?[0-9]+$ ]]; then
        printf '%s' "$default"
        return
    fi

    # Check range
    if [[ "$value" -lt "$min" || "$value" -gt "$max" ]]; then
        printf '%s' "$default"
        return
    fi

    printf '%s' "$value"
}

# Validate value is one of allowed options
# Usage: validate_option <value> <default> <option1> <option2> ...
# Returns: value if valid, default otherwise
validate_option() {
    local value="$1"
    local default="$2"
    shift 2
    local options=("$@")

    for opt in "${options[@]}"; do
        [[ "$value" == "$opt" ]] && { printf '%s' "$value"; return; }
    done

    printf '%s' "$default"
}

# Validate boolean value
# Usage: validate_bool <value> <default>
# Returns: "true" or "false"
validate_bool() {
    local value="$1"
    local default="${2:-false}"

    case "${value,,}" in
        true|1|yes|on)  printf 'true' ;;
        false|0|no|off) printf 'false' ;;
        *)              printf '%s' "$default" ;;
    esac
}

# =============================================================================
# Plugin Options Declaration System (Contract)
# =============================================================================
#
# Plugin Contract: plugin_declare_options()
# -----------------------------------------
# Plugins can implement this function to declare their configurable options.
# This enables:
#   1. Self-documenting plugins (options viewer shows descriptions)
#   2. Lazy loading of configuration (get_option called only when needed)
#   3. Type validation (number, bool, color, etc.)
#   4. Automatic wiki generation
#
# Usage in plugin:
#   plugin_declare_options() {
#       declare_option "repos" "string" "" "Comma-separated list of owner/repo"
#       declare_option "token" "string" "" "API authentication token"
#       declare_option "warning_threshold" "number" "10" "Warning threshold"
#       declare_option "show_issues" "bool" "on" "Show open issues count"
#       declare_option "icon" "icon" "" "Custom icon"
#       declare_option "accent_color" "color" "secondary" "Background color"
#   }
#
# =============================================================================

# Global storage for declared plugin options
# Format: _PLUGIN_OPTIONS[plugin_name]="name|type|default|description;name2|..."
declare -gA _PLUGIN_OPTIONS
declare -gA _PLUGIN_OPTIONS_CACHE  # Cached resolved values

# Current plugin context (set by plugin_init)
_CURRENT_PLUGIN_NAME=""

# Internal field separator for option storage (must not appear in option values)
_OPT_DELIM=$'\x1F'  # ASCII Unit Separator (0x1F) - safe delimiter

# Declare a plugin option
# Usage: declare_option <name> <type> <default> <description>
# Types: string, number, bool, color, icon, key, path, enum
# For enum: default format is "value1,value2,value3|default_value"
declare_option() {
    local name="$1"
    local type="$2"
    local default="$3"
    local description="$4"

    local plugin="${_CURRENT_PLUGIN_NAME:-unknown}"
    local entry="${name}${_OPT_DELIM}${type}${_OPT_DELIM}${default}${_OPT_DELIM}${description}"

    if [[ -z "${_PLUGIN_OPTIONS[$plugin]:-}" ]]; then
        _PLUGIN_OPTIONS[$plugin]="$entry"
    else
        _PLUGIN_OPTIONS[$plugin]+=";"
        _PLUGIN_OPTIONS[$plugin]+="$entry"
    fi
}

# =============================================================================
# Standard Framework Options (available to ALL plugins without declaration)
# =============================================================================
# These options work automatically for any plugin using threshold_plugin_display_info()
declare -gA _FRAMEWORK_STANDARD_OPTIONS=(
    ["display_condition"]="string|always"
    ["display_threshold"]="string|"
)

# Get plugin option value with lazy loading and validation
# Usage: get_option <name>
# Requires: _CURRENT_PLUGIN_NAME to be set (from plugin_init)
# Returns: option value (from tmux config or default)
get_option() {
    local name="$1"
    local plugin="${_CURRENT_PLUGIN_NAME:-${CACHE_KEY:-unknown}}"
    local cache_key="${plugin}_${name}"

    # Return cached value if available
    if [[ -n "${_PLUGIN_OPTIONS_CACHE[$cache_key]+x}" ]]; then
        printf '%s' "${_PLUGIN_OPTIONS_CACHE[$cache_key]}"
        return 0
    fi

    # Get default from declared options or from defaults.sh
    local default=""
    local opt_type="string"

    # Search in declared options
    if [[ -n "${_PLUGIN_OPTIONS[$plugin]:-}" ]]; then
        local entries entry
        IFS=';' read -ra entries <<< "${_PLUGIN_OPTIONS[$plugin]}"
        for entry in "${entries[@]}"; do
            # Parse entry: name<delim>type<delim>default<delim>description
            # Using ASCII Unit Separator (0x1F) as delimiter
            local opt_name="${entry%%$_OPT_DELIM*}"

            if [[ "$opt_name" == "$name" ]]; then
                local rest="${entry#*$_OPT_DELIM}"
                local opt_type_found="${rest%%$_OPT_DELIM*}"
                rest="${rest#*$_OPT_DELIM}"
                local opt_default="${rest%%$_OPT_DELIM*}"
                opt_type="$opt_type_found"
                default="$opt_default"
                break
            fi
        done
    fi

    # Check framework standard options (available to ALL plugins)
    if [[ -z "$default" && -n "${_FRAMEWORK_STANDARD_OPTIONS[$name]:-}" ]]; then
        local std_opt="${_FRAMEWORK_STANDARD_OPTIONS[$name]}"
        opt_type="${std_opt%%|*}"
        default="${std_opt#*|}"
    fi

    # Fallback to POWERKIT_PLUGIN_* variable if not found in declared options
    if [[ -z "$default" ]]; then
        local plugin_upper="${plugin^^}"
        plugin_upper="${plugin_upper//-/_}"
        local name_upper="${name^^}"
        name_upper="${name_upper//-/_}"
        local var_name="POWERKIT_PLUGIN_${plugin_upper}_${name_upper}"
        default="${!var_name:-}"
    fi

    # Get value from tmux option
    local value
    value=$(get_tmux_option "@powerkit_plugin_${plugin}_${name}" "$default")

    # Validate based on type
    case "$opt_type" in
        number)
            if [[ ! "$value" =~ ^-?[0-9]+$ ]]; then
                value="$default"
            fi
            ;;
        bool)
            value=$(validate_bool "$value" "$default")
            ;;
        # color, icon, string, key, path - no validation needed
    esac

    # Cache the resolved value
    _PLUGIN_OPTIONS_CACHE[$cache_key]="$value"

    printf '%s' "$value"
}

# Clear options cache (useful when tmux options change)
# Usage: clear_options_cache [plugin_name]
clear_options_cache() {
    local plugin="${1:-}"

    if [[ -n "$plugin" ]]; then
        # Clear only specific plugin's cache
        for key in "${!_PLUGIN_OPTIONS_CACHE[@]}"; do
            [[ "$key" == "${plugin}_"* ]] && unset "_PLUGIN_OPTIONS_CACHE[$key]"
        done
    else
        # Clear all
        _PLUGIN_OPTIONS_CACHE=()
    fi
}

# Get all declared options for a plugin (for options viewer)
# Usage: get_plugin_declared_options <plugin_name>
# Returns: multiline output with fields separated by $_OPT_DELIM (0x1F)
# Format: name<0x1F>type<0x1F>default<0x1F>description
get_plugin_declared_options() {
    local plugin="$1"
    [[ -z "${_PLUGIN_OPTIONS[$plugin]:-}" ]] && return 1

    local entries entry
    IFS=';' read -ra entries <<< "${_PLUGIN_OPTIONS[$plugin]}"
    for entry in "${entries[@]}"; do
        printf '%s\n' "$entry"
    done
}

# Check if plugin has declared options
# Usage: has_declared_options <plugin_name>
has_declared_options() {
    [[ -n "${_PLUGIN_OPTIONS[$1]:-}" ]]
}

# =============================================================================
# Plugin Initialization Helpers (DRY)
# =============================================================================

# Cache for normalized plugin names (performance: avoid repeated string ops)
declare -gA _PLUGIN_NAME_CACHE

# Normalize plugin name to uppercase with underscores (cached for performance)
# Usage: normalize_plugin_name <plugin_name>
# Returns: PLUGIN_NAME (uppercase, dashes->underscores)
# Example: normalize_plugin_name "my-plugin" -> "MY_PLUGIN"
normalize_plugin_name() {
    local plugin_name="$1"

    # Return cached value if exists
    [[ -n "${_PLUGIN_NAME_CACHE[$plugin_name]:-}" ]] && {
        printf '%s' "${_PLUGIN_NAME_CACHE[$plugin_name]}"
        return
    }

    # Compute and cache
    local normalized="${plugin_name^^}"
    normalized="${normalized//-/_}"
    _PLUGIN_NAME_CACHE[$plugin_name]="$normalized"

    printf '%s' "$normalized"
}

# Get plugin-specific option from tmux
# Usage: get_plugin_option <option_name> <default_value>
# Requires: CACHE_KEY to be set (from plugin_init)
# Example: get_plugin_option "icon" "󰌵" -> gets @powerkit_plugin_camera_icon
get_plugin_option() {
    local option_name="$1"
    local default_value="$2"
    local plugin_name="${CACHE_KEY:-unknown}"

    get_tmux_option "@powerkit_plugin_${plugin_name}_${option_name}" "$default_value"
}

# Initialize plugin cache settings and options context
# Usage: plugin_init <plugin_name>
# Sets: CACHE_KEY, CACHE_TTL, _CURRENT_PLUGIN_NAME
# Auto-calls contract functions if defined:
#   - plugin_check_dependencies()
#   - plugin_declare_options()
# Example: plugin_init "cpu" -> CACHE_KEY="cpu", CACHE_TTL from config
plugin_init() {
    local plugin_name="$1"
    local plugin_upper
    plugin_upper=$(normalize_plugin_name "$plugin_name")

    # Set plugin context for options system
    _CURRENT_PLUGIN_NAME="$plugin_name"

    # Set cache key
    CACHE_KEY="$plugin_name"

    # Auto-call plugin_check_dependencies() if defined (Plugin Contract)
    if declare -f plugin_check_dependencies &>/dev/null; then
        plugin_check_dependencies
    fi

    # Auto-call plugin_declare_options() if defined (Plugin Contract)
    # IMPORTANT: Must be called BEFORE getting CACHE_TTL so declared defaults are available
    if declare -f plugin_declare_options &>/dev/null; then
        plugin_declare_options
    fi

    # Get cache TTL from config or defaults
    # Now get_option can access declared cache_ttl default from plugin_declare_options
    CACHE_TTL=$(get_option "cache_ttl")
    # Fallback to 5 seconds if not declared
    [[ -z "$CACHE_TTL" || ! "$CACHE_TTL" =~ ^[0-9]+$ ]] && CACHE_TTL=5

    # Initialize plugin state to "normal"
    _PLUGIN_STATE="normal"

    export CACHE_KEY CACHE_TTL _CURRENT_PLUGIN_NAME _PLUGIN_STATE
}

# =============================================================================
# Plugin State Management
# =============================================================================
# These functions allow plugins to set and get their severity state.
# States: inactive, normal, info, warning, error
#
# Usage in plugin:
#   plugin_set_state "warning"   # Set state to warning
#   local state=$(plugin_get_state)  # Get current state
#
# The state is used by severity_plugin_display_info() to determine colors
# and by display_condition/display_threshold for visibility filtering.
# =============================================================================

# Set plugin severity state
# Usage: plugin_set_state <state>
# state: "inactive", "normal", "info", "warning", "error"
plugin_set_state() {
    local state="${1:-normal}"
    case "$state" in
        inactive|normal|info|warning|error)
            _PLUGIN_STATE="$state"
            ;;
        *)
            _PLUGIN_STATE="normal"
            ;;
    esac
    export _PLUGIN_STATE
}

# Get current plugin severity state
# Usage: state=$(plugin_get_state)
# Returns: current state (default: "normal")
plugin_get_state() {
    printf '%s' "${_PLUGIN_STATE:-normal}"
}

# =============================================================================
# Helper Functions for Plugins
# =============================================================================

# Note: The following functions are now in utils.sh (DRY):
# - extract_numeric()
# - evaluate_condition()
# - build_display_info()
# - get_color() (alias for get_powerkit_color)

# =============================================================================
# Threshold Color Helper (DRY - used by 8+ plugins)
# =============================================================================

# Apply warning/critical threshold colors based on value
# Usage: apply_threshold_colors <value> <plugin_name> [invert]
# Returns: "accent:accent_icon" or empty if no threshold triggered
# Set invert=1 for inverted thresholds (lower is worse, e.g., battery)
apply_threshold_colors() {
    local value="$1"
    local plugin_name="$2"
    local invert="${3:-0}"

    [[ -z "$value" || ! "$value" =~ ^[0-9]+$ ]] && return 1

    local plugin_upper="${plugin_name^^}"
    plugin_upper="${plugin_upper//-/_}"

    # Get threshold values from defaults
    local warn_var="POWERKIT_PLUGIN_${plugin_upper}_WARNING_THRESHOLD"
    local crit_var="POWERKIT_PLUGIN_${plugin_upper}_CRITICAL_THRESHOLD"
    local warn_t="${!warn_var:-70}"
    local crit_t="${!crit_var:-90}"

    # Override with tmux options if set
    warn_t=$(get_tmux_option "@powerkit_plugin_${plugin_name}_warning_threshold" "$warn_t")
    crit_t=$(get_tmux_option "@powerkit_plugin_${plugin_name}_critical_threshold" "$crit_t")

    local accent="" accent_icon=""
    local is_critical=0 is_warning=0

    if [[ "$invert" == "1" ]]; then
        # Inverted: lower value = worse (e.g., battery)
        [[ "$value" -le "$crit_t" ]] && is_critical=1
        [[ "$is_critical" -eq 0 && "$value" -le "$warn_t" ]] && is_warning=1
    else
        # Normal: higher value = worse (e.g., CPU, memory)
        [[ "$value" -ge "$crit_t" ]] && is_critical=1
        [[ "$is_critical" -eq 0 && "$value" -ge "$warn_t" ]] && is_warning=1
    fi

    if [[ "$is_critical" -eq 1 ]]; then
        local crit_accent_var="POWERKIT_PLUGIN_${plugin_upper}_CRITICAL_ACCENT_COLOR"
        local crit_icon_var="POWERKIT_PLUGIN_${plugin_upper}_CRITICAL_ACCENT_COLOR_ICON"
        accent="${!crit_accent_var:-error}"
        accent_icon="${!crit_icon_var:-error-strong}"
        accent=$(get_tmux_option "@powerkit_plugin_${plugin_name}_critical_accent_color" "$accent")
        accent_icon=$(get_tmux_option "@powerkit_plugin_${plugin_name}_critical_accent_color_icon" "$accent_icon")
    elif [[ "$is_warning" -eq 1 ]]; then
        local warn_accent_var="POWERKIT_PLUGIN_${plugin_upper}_WARNING_ACCENT_COLOR"
        local warn_icon_var="POWERKIT_PLUGIN_${plugin_upper}_WARNING_ACCENT_COLOR_ICON"
        accent="${!warn_accent_var:-warning}"
        accent_icon="${!warn_icon_var:-warning-strong}"
        accent=$(get_tmux_option "@powerkit_plugin_${plugin_name}_warning_accent_color" "$accent")
        accent_icon=$(get_tmux_option "@powerkit_plugin_${plugin_name}_warning_accent_color_icon" "$accent_icon")
    fi

    [[ -n "$accent" ]] && printf '%s:%s' "$accent" "$accent_icon"
}

# =============================================================================
# Unified Threshold Display Info (DRY - standardizes threshold-based plugins)
# =============================================================================
#
# Plugin Contract Extension: Threshold Options
# --------------------------------------------
# Plugins that want automatic threshold colors should declare these options:
#
#   # Thresholds
#   declare_option "threshold_mode" "string" "normal" "Threshold mode (none|normal|inverted)"
#   declare_option "warning_threshold" "number" "70" "Warning threshold percentage"
#   declare_option "critical_threshold" "number" "90" "Critical threshold percentage"
#   declare_option "show_only_warning" "bool" "false" "Only show when threshold exceeded"
#
# Modes:
#   - none: No automatic thresholds (plugin handles colors manually)
#   - normal: Higher value = worse (CPU, memory, disk)
#   - inverted: Lower value = worse (battery)
#
# Standard Visibility Options (work automatically for ALL conditional plugins):
# ----------------------------------------------------------------------------
#   declare_option "display_condition" "string" "always" "Display condition (always|eq|lt|lte|gt|gte)"
#   declare_option "display_threshold" "string" "" "Severity level to compare"
#
# The display_condition/display_threshold options compare against the current
# SEVERITY STATE, not numeric values. States (in order of severity):
#
#   - inactive: Resource exists but is disabled (bluetooth off, VPN disconnected)
#   - normal:   Default state, functioning normally (CPU 20%, battery 80%)
#   - info:     Important information to highlight (new messages, updates available)
#   - warning:  Attention needed (CPU 75%, battery 40%)
#   - error:    Critical, urgent action required (CPU 95%, battery 15%)
#
# Note: "inactive" is different from hiding the plugin:
#   - Hidden: Resource doesn't exist or isn't applicable (no bluetooth adapter)
#   - Inactive: Resource exists but is turned off (bluetooth adapter disabled)
#
# Examples:
#   display_condition="always", display_threshold=""       -> Always show (default)
#   display_condition="eq", display_threshold="error"      -> Show only when critical
#   display_condition="gt", display_threshold="normal"     -> Show when info, warning, or error
#   display_condition="gt", display_threshold="inactive"   -> Show when active (hide inactive)
#   display_condition="gte", display_threshold="warning"   -> Show when warning or error
#   display_condition="lt", display_threshold="error"      -> Show when inactive, normal, info, or warning
#
# Usage in plugin:
#   plugin_get_display_info() {
#       threshold_plugin_display_info "${1:-}" "<numeric_value>"
#   }
#
# For plugins that need to set state directly (e.g., bluetooth):
#   plugin_get_display_info() {
#       local state="inactive"  # or "normal", "info", "warning", "error"
#       severity_plugin_display_info "${1:-}" "$state"
#   }
#
# =============================================================================

# Map severity level to numeric value for comparison
# Hierarchy: inactive(0) < normal(1) < info(2) < warning(3) < error(4)
_severity_to_num() {
    case "$1" in
        inactive) printf '0' ;;
        normal)   printf '1' ;;
        info)     printf '2' ;;
        warning)  printf '3' ;;
        error)    printf '4' ;;
        *)        printf '1' ;;  # Default to normal
    esac
}

# Map severity level to color pair (accent:accent_icon)
# In render_plugins.sh (threshold mode, has_threshold=1):
#   - accent = content background (main color)
#   - accent-subtle = icon background (derived by renderer)
#   - accent-strong = text color (derived by renderer)
# Threshold mode is triggered when accent != default (secondary)
# Note: inactive/normal don't trigger threshold mode (accent=secondary)
_severity_to_colors() {
    case "$1" in
        inactive) printf 'disabled:disabled' ;;
        normal)   printf 'secondary:active' ;;
        info)     printf 'info:info-subtle' ;;
        warning)  printf 'warning:warning-subtle' ;;
        error)    printf 'error:error-subtle' ;;
        *)        printf 'secondary:active' ;;
    esac
}

# Check if plugin should be visible based on display_condition and display_threshold
# Usage: _check_display_visibility <current_severity>
# Returns: 0 if should display, 1 if should hide
_check_display_visibility() {
    local current_severity="$1"

    local display_condition display_threshold
    display_condition=$(get_option "display_condition" 2>/dev/null) || display_condition="always"
    display_threshold=$(get_option "display_threshold" 2>/dev/null) || display_threshold=""

    # If display_condition is "always" or display_threshold is empty, always show
    [[ "$display_condition" == "always" || -z "$display_threshold" ]] && return 0

    local current_num threshold_num
    current_num=$(_severity_to_num "$current_severity")
    threshold_num=$(_severity_to_num "$display_threshold")

    case "$display_condition" in
        eq)  [[ "$current_num" -eq "$threshold_num" ]] && return 0 ;;
        lt)  [[ "$current_num" -lt "$threshold_num" ]] && return 0 ;;
        lte) [[ "$current_num" -le "$threshold_num" ]] && return 0 ;;
        gt)  [[ "$current_num" -gt "$threshold_num" ]] && return 0 ;;
        gte) [[ "$current_num" -ge "$threshold_num" ]] && return 0 ;;
    esac

    return 1
}

# Get threshold-based display info for plugins
# Usage: threshold_plugin_display_info <content> <numeric_value>
# Returns: formatted display info via build_display_info
#
# This function:
#   1. Checks visibility (empty content, show_only_warning, display_condition)
#   2. Applies threshold colors based on threshold_mode
#   3. Returns proper display info
threshold_plugin_display_info() {
    local content="$1"
    local value="$2"
    local plugin_name="${_CURRENT_PLUGIN_NAME:-${CACHE_KEY:-unknown}}"

    # Get options
    local threshold_mode show_only_warning warning_threshold critical_threshold
    threshold_mode=$(get_option "threshold_mode" 2>/dev/null) || threshold_mode="none"
    show_only_warning=$(get_option "show_only_warning" 2>/dev/null) || show_only_warning="false"
    warning_threshold=$(get_option "warning_threshold" 2>/dev/null) || warning_threshold="70"
    critical_threshold=$(get_option "critical_threshold" 2>/dev/null) || critical_threshold="90"

    # Hide if content is empty or N/A
    [[ -z "$content" || "$content" == "N/A" ]] && { build_display_info "0" "" "" ""; return; }

    # Determine current severity level based on value and thresholds
    # Default state is "normal" (not "info" - info is for highlighting important data)
    local current_severity="normal"
    local exceeds_warning="false"
    local exceeds_critical="false"

    if [[ -n "$value" && "$value" =~ ^[0-9]+$ && "$threshold_mode" != "none" ]]; then
        if [[ "$threshold_mode" == "inverted" ]]; then
            # Inverted: lower value = worse (e.g., battery)
            [[ "$value" -le "$critical_threshold" ]] && exceeds_critical="true"
            [[ "$exceeds_critical" != "true" && "$value" -le "$warning_threshold" ]] && exceeds_warning="true"
        else
            # Normal: higher value = worse (e.g., CPU, memory)
            [[ "$value" -ge "$critical_threshold" ]] && exceeds_critical="true"
            [[ "$exceeds_critical" != "true" && "$value" -ge "$warning_threshold" ]] && exceeds_warning="true"
        fi

        # Set severity based on threshold state
        if [[ "$exceeds_critical" == "true" ]]; then
            current_severity="error"
        elif [[ "$exceeds_warning" == "true" ]]; then
            current_severity="warning"
        fi
    fi

    # Check display_condition/display_threshold visibility
    if ! _check_display_visibility "$current_severity"; then
        build_display_info "0" "" "" ""
        return
    fi

    # Legacy: Hide if show_only_warning and below threshold (backwards compatibility)
    local exceeds_threshold="false"
    [[ "$exceeds_warning" == "true" || "$exceeds_critical" == "true" ]] && exceeds_threshold="true"

    if [[ "$show_only_warning" == "true" && "$exceeds_threshold" == "false" ]]; then
        build_display_info "0" "" "" ""
        return
    fi

    # Get icon
    local icon
    icon=$(get_option "icon" 2>/dev/null) || icon=""

    # Apply colors based on severity using centralized mapping
    local accent accent_icon colors
    colors=$(_severity_to_colors "$current_severity")
    accent="${colors%%:*}"
    accent_icon="${colors#*:}"

    build_display_info "1" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Severity-based Display Info (for plugins that manage state directly)
# =============================================================================
# Usage: severity_plugin_display_info <content> [severity_state]
# severity_state: "inactive", "normal", "info", "warning", "error"
#
# If severity_state is not provided, uses plugin_get_state() to get the
# current state (set via plugin_set_state()).
#
# This is for plugins that don't use numeric thresholds but need to set
# their severity state directly (e.g., bluetooth on/off, VPN connected/disconnected)
#
# Example usage in plugin:
#   _compute_bluetooth() {
#       if bluetooth_is_off; then
#           plugin_set_state "inactive"
#           echo "OFF"
#       else
#           plugin_set_state "normal"
#           echo "ON"
#       fi
#   }
#
#   plugin_get_display_info() {
#       severity_plugin_display_info "${1:-}"  # Uses plugin_get_state() automatically
#   }
#
severity_plugin_display_info() {
    local content="$1"
    local severity="${2:-$(plugin_get_state)}"

    # Hide if content is empty or N/A
    [[ -z "$content" || "$content" == "N/A" ]] && { build_display_info "0" "" "" ""; return; }

    # Check display_condition/display_threshold visibility
    if ! _check_display_visibility "$severity"; then
        build_display_info "0" "" "" ""
        return
    fi

    # Get icon
    local icon
    icon=$(get_option "icon" 2>/dev/null) || icon=""

    # Apply colors based on severity
    local accent accent_icon colors
    colors=$(_severity_to_colors "$severity")
    accent="${colors%%:*}"
    accent_icon="${colors#*:}"

    build_display_info "1" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# API Call Helper (DRY - used by github, gitlab, bitbucket)
# =============================================================================

# Make authenticated API call with proper headers
# Usage: make_api_call <url> <auth_type> <token>
# auth_type: "bearer" (standard OAuth), "github" (GitHub), "private-token" (GitLab), "basic" (user:pass)
make_api_call() {
    local url="$1"
    local auth_type="$2"
    local token="$3"
    local timeout="${4:-5}"

    local auth_args=()
    if [[ -n "$token" ]]; then
        case "$auth_type" in
            bearer)
                # Standard OAuth Bearer token (Bitbucket, etc.)
                auth_args=(-H "Authorization: Bearer $token")
                ;;
            github)
                # GitHub uses "token" instead of "Bearer"
                auth_args=(-H "Authorization: token $token")
                ;;
            private-token)
                auth_args=(-H "PRIVATE-TOKEN: $token")
                ;;
            basic)
                auth_args=(-u "$token")
                ;;
        esac
    fi

    curl -sf --connect-timeout "$timeout" --max-time "$((timeout * 2))" \
        "${auth_args[@]}" "$url" 2>/dev/null
}

# =============================================================================
# Audio Backend Detection (DRY - used by volume, audiodevices, microphone)
# =============================================================================

# Cached audio backend detection
_AUDIO_BACKEND=""

# Detect available audio backend
# Returns: macos, pipewire, pulseaudio, alsa, or empty
detect_audio_backend() {
    # Return cached value if available
    [[ -n "$_AUDIO_BACKEND" ]] && { printf '%s' "$_AUDIO_BACKEND"; return 0; }

    if is_macos; then
        _AUDIO_BACKEND="macos"
    elif command -v wpctl &>/dev/null; then
        _AUDIO_BACKEND="pipewire"
    elif command -v pactl &>/dev/null; then
        _AUDIO_BACKEND="pulseaudio"
    elif command -v amixer &>/dev/null; then
        _AUDIO_BACKEND="alsa"
    else
        _AUDIO_BACKEND="none"
    fi

    printf '%s' "$_AUDIO_BACKEND"
}

# =============================================================================
# Format Helpers (DRY)
# =============================================================================

# Truncate text to max length with ellipsis
# Usage: truncate_text <text> <max_length> [preserve_words]
# Parameters:
#   text: The text to truncate
#   max_length: Maximum length (default: 30, 0 = no truncation)
#   preserve_words: If "true", truncate at word boundary (default: false)
# Returns: truncated text with "..." if longer than max_length
# Note: No ellipsis if truncation lands on a word boundary (space)
truncate_text() {
    local text="$1"
    local max="${2:-30}"
    local preserve_words="${3:-false}"

    # No truncation if max is 0 or negative
    if [[ $max -le 0 || ${#text} -le $max ]]; then
        printf '%s' "$text"
        return
    fi

    local ellipsis="..."
    local available=$((max - ${#ellipsis}))
    local truncated

    if [[ "$preserve_words" == "true" ]]; then
        # Truncate at word boundary
        truncated="${text:0:$available}"
        # Find last space to avoid cutting words
        if [[ "$truncated" == *" "* ]]; then
            truncated="${truncated% *}"
        fi
    else
        # Truncate by character
        truncated="${text:0:$available}"
    fi

    # Check if we landed on a word boundary (next char is space or we're at word end)
    local next_char="${text:${#truncated}:1}"
    if [[ "$next_char" == " " || -z "$next_char" ]]; then
        # Clean word boundary - no ellipsis needed
        printf '%s' "$truncated"
    else
        printf '%s%s' "$truncated" "$ellipsis"
    fi
}

# Join array elements with separator
# Usage: join_with_separator <separator> <element1> <element2> ...
join_with_separator() {
    local sep="$1"
    shift
    local result=""
    local first=1

    for item in "$@"; do
        [[ -z "$item" ]] && continue
        if [[ $first -eq 1 ]]; then
            result="$item"
            first=0
        else
            result+="${sep}${item}"
        fi
    done

    printf '%s' "$result"
}

# Format duration from HH:MM or seconds to human-readable format (Xh Ym)
# Usage: format_duration <time> [<format>]
#
# Parameters:
#   time: Time in HH:MM format or seconds
#   format: Input format - "hhmm" (default) or "seconds"
#
# Output: "Xh Ym" or "Ym" if hours is 0
#
# Examples:
#   format_duration "8:49"        -> "8h 49m"
#   format_duration "0:35"        -> "35m"
#   format_duration "3600" "seconds" -> "1h 0m"
format_duration() {
    local input="$1"
    local format="${2:-hhmm}"
    local hours mins

    if [[ "$format" == "seconds" ]]; then
        local total_secs="$input"
        hours=$((total_secs / 3600))
        mins=$(((total_secs % 3600) / 60))
    else
        # HH:MM format
        hours="${input%%:*}"
        mins="${input##*:}"
        # Remove leading zeros
        hours="${hours#0}"
        mins="${mins#0}"
    fi

    # Handle empty values
    [[ -z "$hours" ]] && hours=0
    [[ -z "$mins" ]] && mins=0

    if [[ "$hours" -gt 0 ]]; then
        printf '%sh %sm' "$hours" "$mins"
    else
        printf '%sm' "$mins"
    fi
}

# Format repository metrics (issues/PRs/MRs/comments) with icons
# Generic helper for github/gitlab/bitbucket plugins (DRY)
# Usage: format_repo_metrics <separator> <format_style> <show_issues> <issues> <issue_icon> <issue_label> \
#                             <show_prs> <prs> <pr_icon> <pr_label> \
#                             [<show_comments> <comments> <comment_label>]
#
# Parameters:
#   separator: string to separate parts (e.g., " | ")
#   format_style: "simple" or "detailed" (adds labels like "i", "p", "c")
#   show_issues: "on"/"off"
#   issues: number of issues
#   issue_icon: icon for issues
#   issue_label: label suffix for detailed mode (e.g., "i")
#   show_prs: "on"/"off"
#   prs: number of PRs/MRs
#   pr_icon: icon for PRs
#   pr_label: label suffix for detailed mode (e.g., "p", "mr")
#   show_comments: "on"/"off" (optional)
#   comments: number of comments (optional)
#   comment_label: label suffix for detailed mode (optional, e.g., "c")
format_repo_metrics() {
    local separator="$1"
    local format_style="$2"
    local show_issues="$3"
    local issues="$4"
    local issue_icon="$5"
    local issue_label="$6"
    local show_prs="$7"
    local prs="$8"
    local pr_icon="$9"
    local pr_label="${10}"
    local show_comments="${11:-off}"
    local comments="${12:-0}"
    local comment_label="${13:-c}"

    local parts=()

    # Issues
    if [[ "$show_issues" == "on" || "$show_issues" == "true" ]]; then
        if [[ "$format_style" == "detailed" ]]; then
            parts+=("${issue_icon} $(format_number "$issues")${issue_label}")
        else
            parts+=("${issue_icon} $(format_number "$issues")")
        fi
    fi

    # PRs/MRs
    if [[ "$show_prs" == "on" || "$show_prs" == "true" ]]; then
        if [[ "$format_style" == "detailed" ]]; then
            parts+=("${pr_icon} $(format_number "$prs")${pr_label}")
        else
            parts+=("${pr_icon} $(format_number "$prs")")
        fi
    fi

    # Comments (optional)
    if [[ "$show_comments" == "on" || "$show_comments" == "true" ]]; then
        if [[ "$format_style" == "detailed" ]]; then
            parts+=("$(format_number "$comments")${comment_label}")
        else
            parts+=("$(format_number "$comments")")
        fi
    fi

    join_with_separator "$separator" "${parts[@]}"
}