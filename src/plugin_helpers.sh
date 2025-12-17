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
#   - plugin_init(), get_plugin_option(), get_cached_option()
#   - require_cmd(), require_any_cmd(), check_dependencies(), get_missing_deps()
#   - run_with_timeout(), safe_curl()
#   - validate_range(), validate_option(), validate_bool()
#   - apply_threshold_colors()
#   - make_api_call(), detect_audio_backend()
#   - join_with_separator(), format_issue_pr_counts()
#   - should_load_plugin(), precheck_plugin(), get_plugin_priority()
#   - defer_plugin_load()
#
# DEPENDENCIES: source_guard.sh, utils.sh
# =============================================================================

# Source guard
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=src/source_guard.sh
. "$ROOT_DIR/source_guard.sh"
source_guard "plugin_helpers" && return 0

# shellcheck source=src/utils.sh
. "$ROOT_DIR/utils.sh"

# =============================================================================
# Dependency Checking System
# =============================================================================

# Global array for missing dependencies
declare -ga PLUGIN_DEPS_MISSING=()

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

    PLUGIN_DEPS_MISSING+=("$cmd")
    # Log missing dependency if we have a plugin context
    [[ -n "${CACHE_KEY:-}" ]] && log_missing_dep "${CACHE_KEY}" "$cmd"
    [[ "$optional" == "1" ]] && return 0
    return 1
}

# Check if ANY of the commands exists
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
# Plugin Initialization Helpers (DRY)
# =============================================================================

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

# Initialize plugin cache settings
# Usage: plugin_init <plugin_name>
# Sets: CACHE_KEY, CACHE_TTL
# Example: plugin_init "cpu" -> CACHE_KEY="cpu", CACHE_TTL from config
plugin_init() {
    local plugin_name="$1"
    local plugin_upper="${plugin_name^^}"
    plugin_upper="${plugin_upper//-/_}"  # replace - with _
    
    # Set cache key
    CACHE_KEY="$plugin_name"
    
    # Get cache TTL from config or defaults
    local ttl_var="POWERKIT_PLUGIN_${plugin_upper}_CACHE_TTL"
    local default_ttl="${!ttl_var:-5}"
    CACHE_TTL=$(get_tmux_option "@powerkit_plugin_${plugin_name}_cache_ttl" "$default_ttl")
    
    export CACHE_KEY CACHE_TTL
}

# =============================================================================
# Helper Functions for Plugins
# =============================================================================

# Helper function for getting tmux options in plugins (alias)
get_cached_option() {
    get_tmux_option "$@"
}

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
# API Call Helper (DRY - used by github, gitlab, bitbucket)
# =============================================================================

# Make authenticated API call with proper headers
# Usage: make_api_call <url> <auth_type> <token>
# auth_type: "bearer" (GitHub), "private-token" (GitLab), "basic" (Bitbucket)
make_api_call() {
    local url="$1"
    local auth_type="$2"
    local token="$3"
    local timeout="${4:-5}"

    local auth_args=()
    if [[ -n "$token" ]]; then
        case "$auth_type" in
            bearer)
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

# Format parts with icons for issue/PR counts (DRY - github/gitlab/bitbucket)
# Usage: format_issue_pr_counts <issues> <prs> <issue_icon> <pr_icon> <separator> <show_issues> <show_prs>
format_issue_pr_counts() {
    local issues="$1"
    local prs="$2"
    local issue_icon="$3"
    local pr_icon="$4"
    local separator="$5"
    local show_issues="$6"
    local show_prs="$7"

    local parts=()

    [[ "$show_issues" == "on" ]] && parts+=("${issue_icon} ${issues}")
    [[ "$show_prs" == "on" ]] && parts+=("${pr_icon} ${prs}")

    join_with_separator "$separator" "${parts[@]}"
}

# =============================================================================
# Lazy Loading System
# =============================================================================

# Check if plugin should be loaded (lazy loading support)
# Usage: should_load_plugin <plugin_name>
# Returns: 0 if should load, 1 if should skip
should_load_plugin() {
    local plugin_name="$1"

    # Check if plugin is disabled via tmux option
    local show_opt
    show_opt=$(get_tmux_option "@powerkit_plugin_${plugin_name}_show" "on")
    [[ "$show_opt" == "off" ]] && return 1

    # Check if lazy loading is enabled
    local lazy_enabled
    lazy_enabled=$(get_tmux_option "@powerkit_lazy_loading" "off")
    [[ "$lazy_enabled" != "on" ]] && return 0

    # Plugin-specific lazy loading check
    local plugin_lazy
    plugin_lazy=$(get_tmux_option "@powerkit_plugin_${plugin_name}_lazy" "on")
    [[ "$plugin_lazy" == "off" ]] && return 0

    # For lazy mode, check if plugin has recent cache
    local cache_file="${CACHE_DIR:-$HOME/.cache/tmux-powerkit}/${plugin_name}.cache"
    [[ -f "$cache_file" ]] && return 0

    # No cache - defer loading (return stale indicator)
    return 0
}

# Precheck plugin requirements before full load
# Usage: precheck_plugin <plugin_name>
# Returns: 0 if ready, 1 if not ready (missing deps, etc.)
precheck_plugin() {
    local plugin_name="$1"

    # Check show option
    local show_opt
    show_opt=$(get_tmux_option "@powerkit_plugin_${plugin_name}_show" "on")
    [[ "$show_opt" == "off" ]] && return 1

    return 0
}

# Get plugin load priority
# Usage: get_plugin_priority <plugin_name>
# Returns: priority number (lower = load first)
get_plugin_priority() {
    local plugin_name="$1"

    # Get custom priority from config
    local priority
    priority=$(get_tmux_option "@powerkit_plugin_${plugin_name}_priority" "")
    [[ -n "$priority" ]] && { printf '%s' "$priority"; return; }

    # Default priorities by plugin type
    case "$plugin_name" in
        # Critical system info - high priority
        datetime|hostname|session) printf '10' ;;
        # Fast local data
        cpu|memory|disk|loadavg) printf '20' ;;
        # Network-dependent - lower priority
        weather|external_ip|git*|cloud) printf '50' ;;
        # Default
        *) printf '30' ;;
    esac
}

# Deferred plugin execution wrapper
# Usage: defer_plugin_load <plugin_name> <callback>
# Executes callback in background if lazy loading is enabled
defer_plugin_load() {
    local plugin_name="$1"
    shift
    local callback=("$@")

    local lazy_enabled
    lazy_enabled=$(get_tmux_option "@powerkit_lazy_loading" "off")

    if [[ "$lazy_enabled" == "on" ]]; then
        # Execute in background and cache result
        (
            local result
            result=$("${callback[@]}" 2>/dev/null)
            [[ -n "$result" ]] && cache_set "$plugin_name" "$result"
        ) &

        # Return cached value or loading indicator
        local cached
        if cached=$(cache_get "$plugin_name" 86400); then
            printf '%s' "$cached"
        else
            printf '...'
        fi
    else
        # Direct execution
        "${callback[@]}"
    fi
}