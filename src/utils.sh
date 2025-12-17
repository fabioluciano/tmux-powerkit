#!/usr/bin/env bash
# =============================================================================
# PowerKit Utility Functions - KISS/DRY Version
# =============================================================================
# shellcheck disable=SC2034
#
# GLOBAL VARIABLES EXPORTED:
#   - _PLATFORM_OS, _PLATFORM_DISTRO, _PLATFORM_ARCH, _PLATFORM_ICON
#   - POWERKIT_THEME_COLORS (associative array)
#
# FUNCTIONS PROVIDED:
#   - Platform: is_macos(), is_linux(), is_bsd(), get_os(), get_distro()
#   - Options: get_tmux_option()
#   - Colors: get_powerkit_color(), get_color(), load_powerkit_theme()
#   - Helpers: extract_numeric(), evaluate_condition(), build_display_info()
#   - Toast: show_toast_notification(), toast()
#   - Debug: is_debug_mode(), execute_plugin_safe()
#   - Logging: log_debug(), log_info(), log_warn(), log_error()
#   - Logging: log_plugin_error(), log_missing_dep(), get_log_file()
#
# DEPENDENCIES: source_guard.sh, defaults.sh
# =============================================================================

# Source guard
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=src/source_guard.sh
. "$CURRENT_DIR/source_guard.sh"
source_guard "utils" && return 0

# shellcheck source=src/defaults.sh
. "$CURRENT_DIR/defaults.sh"

# =============================================================================
# Platform Detection (cached, computed once)
# =============================================================================

declare -g _PLATFORM_OS=""
declare -g _PLATFORM_DISTRO=""
declare -g _PLATFORM_ARCH=""
declare -g _PLATFORM_ICON=""

_detect_platform() {
    [[ -n "$_PLATFORM_OS" ]] && return 0
    
    _PLATFORM_OS="$(uname -s)"
    _PLATFORM_ARCH="$(uname -m)"
    
    case "$_PLATFORM_OS" in
        Darwin)
            _PLATFORM_DISTRO="macos"
            _PLATFORM_ICON=$'\uf302'
            ;;
        Linux)
            # Detect distro from /etc/os-release
            if [[ -f /etc/os-release ]]; then
                _PLATFORM_DISTRO=$(awk -F'=' '/^ID=/ {gsub(/"/, "", $2); print tolower($2); exit}' /etc/os-release)
            elif [[ -f /etc/lsb-release ]]; then
                _PLATFORM_DISTRO=$(awk -F'=' '/^DISTRIB_ID=/ {print tolower($2); exit}' /etc/lsb-release)
            else
                _PLATFORM_DISTRO="linux"
            fi
            # Set icon based on distro
            case "$_PLATFORM_DISTRO" in
                ubuntu)         _PLATFORM_ICON=$'\uf31b' ;;
                debian)         _PLATFORM_ICON=$'\uf306' ;;
                fedora)         _PLATFORM_ICON=$'\uf30a' ;;
                arch|archarm)   _PLATFORM_ICON=$'\uf303' ;;
                manjaro)        _PLATFORM_ICON=$'\uf312' ;;
                centos)         _PLATFORM_ICON=$'\uf304' ;;
                rhel|redhat)    _PLATFORM_ICON=$'\uf304' ;;
                opensuse*)      _PLATFORM_ICON=$'\uf314' ;;
                alpine)         _PLATFORM_ICON=$'\uf300' ;;
                gentoo)         _PLATFORM_ICON=$'\uf30d' ;;
                linuxmint|mint) _PLATFORM_ICON=$'\uf30e' ;;
                elementary)     _PLATFORM_ICON=$'\uf309' ;;
                pop|pop_os)     _PLATFORM_ICON=$'\uf32a' ;;
                kali)           _PLATFORM_ICON=$'\uf327' ;;
                void)           _PLATFORM_ICON=$'\uf32e' ;;
                nixos|nix)      _PLATFORM_ICON=$'\uf313' ;;
                raspbian)       _PLATFORM_ICON=$'\uf315' ;;
                rocky)          _PLATFORM_ICON=$'\uf32b' ;;
                alma|almalinux) _PLATFORM_ICON=$'\uf31d' ;;
                endeavouros)    _PLATFORM_ICON=$'\uf322' ;;
                garuda)         _PLATFORM_ICON=$'\uf337' ;;
                artix)          _PLATFORM_ICON=$'\uf31f' ;;
                *)              _PLATFORM_ICON=$'\uf31a' ;;
            esac
            ;;
        FreeBSD)  _PLATFORM_DISTRO="freebsd"; _PLATFORM_ICON=$'\uf30c' ;;
        OpenBSD)  _PLATFORM_DISTRO="openbsd"; _PLATFORM_ICON=$'\uf328' ;;
        NetBSD)   _PLATFORM_DISTRO="netbsd";  _PLATFORM_ICON=$'\uf328' ;;
        CYGWIN*|MINGW*|MSYS*) _PLATFORM_OS="Windows"; _PLATFORM_DISTRO="windows"; _PLATFORM_ICON=$'\uf17a' ;;
        *)        _PLATFORM_DISTRO="unknown"; _PLATFORM_ICON=$'\uf11c' ;;
    esac
}

# Initialize on load
_detect_platform

# --- OS Detection ---
is_macos()  { [[ "$_PLATFORM_OS" == "Darwin" ]]; }
is_linux()  { [[ "$_PLATFORM_OS" == "Linux" ]]; }
is_bsd()    { [[ "$_PLATFORM_OS" == *"BSD" ]]; }
is_windows(){ [[ "$_PLATFORM_OS" == "Windows" ]] || [[ -n "${WSL_DISTRO_NAME:-}" ]]; }

# --- Distro Detection ---
is_distro()       { [[ "$_PLATFORM_DISTRO" == "$1" ]]; }
is_debian_based() { [[ "$_PLATFORM_DISTRO" =~ ^(debian|ubuntu|mint|pop|elementary|kali|raspbian)$ ]] || command -v apt &>/dev/null; }
is_redhat_based() { [[ "$_PLATFORM_DISTRO" =~ ^(rhel|fedora|centos|rocky|alma)$ ]] || command -v dnf &>/dev/null; }
is_arch_based()   { [[ "$_PLATFORM_DISTRO" =~ ^(arch|manjaro|endeavouros|garuda|artix)$ ]] || command -v pacman &>/dev/null; }

# --- Architecture Detection ---
is_arm()          { [[ "$_PLATFORM_ARCH" == arm* || "$_PLATFORM_ARCH" == "aarch64" ]]; }
is_apple_silicon(){ is_macos && is_arm; }

# --- Getters ---
get_os()     { printf '%s' "$_PLATFORM_OS"; }
get_distro() { printf '%s' "$_PLATFORM_DISTRO"; }
get_arch()   { printf '%s' "$_PLATFORM_ARCH"; }
get_os_icon(){ printf ' %s' "$_PLATFORM_ICON"; }

# =============================================================================
# Tmux Option Getter (with optional batch caching for performance)
# =============================================================================

# Associative array to cache tmux options (avoids repeated tmux calls)
declare -gA _TMUX_OPTIONS_CACHE

# Batch load all @powerkit options into cache (performance optimization)
# Call this once at startup to avoid multiple tmux show-option calls
_batch_load_tmux_options() {
    [[ -n "${_TMUX_OPTIONS_BATCH_LOADED:-}" ]] && return 0
    _TMUX_OPTIONS_BATCH_LOADED=1

    local line key value
    while IFS= read -r line; do
        # Parse: @powerkit_option "value" or @powerkit_option value
        if [[ "$line" =~ ^(@powerkit[^[:space:]]+)[[:space:]]+(.*) ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            # Remove surrounding quotes if present
            value="${value%\"}"
            value="${value#\"}"
            _TMUX_OPTIONS_CACHE["$key"]="$value"
        fi
    done < <(tmux show-options -g 2>/dev/null | grep '^@powerkit')
}

get_tmux_option() {
    local option="$1"
    local default_value="$2"

    # Check cache first (for @powerkit options)
    if [[ "$option" == @powerkit* && -n "${_TMUX_OPTIONS_CACHE[$option]+x}" ]]; then
        printf '%s' "${_TMUX_OPTIONS_CACHE[$option]}"
        return 0
    fi

    # Fallback to direct tmux call
    local value
    value=$(tmux show-option -gqv "$option" 2>/dev/null)
    printf '%s' "${value:-$default_value}"
}

# Initialize batch loading on first source
_batch_load_tmux_options

# =============================================================================
# Theme Color System
# =============================================================================

declare -A POWERKIT_THEME_COLORS

# Load theme and populate POWERKIT_THEME_COLORS
load_powerkit_theme() {
    local theme="" theme_variant="" theme_dir="" theme_file=""
    
    # Get theme name
    theme=$(get_tmux_option "@powerkit_theme" "$POWERKIT_DEFAULT_THEME")
    theme_variant=$(get_tmux_option "@powerkit_theme_variant" "")
    
    # Auto-detect variant if not specified
    if [[ -z "$theme_variant" ]]; then
        theme_dir="$CURRENT_DIR/themes/${theme}"
        if [[ -d "$theme_dir" ]]; then
            theme_variant=$(ls "$theme_dir"/*.sh 2>/dev/null | head -1 | xargs basename -s .sh 2>/dev/null || echo "")
        fi
    fi
    
    # Fallback to defaults
    [[ -z "$theme_variant" ]] && theme_variant="$POWERKIT_DEFAULT_THEME_VARIANT"
    
    # Final fallback
    [[ -z "$theme" ]] && theme="tokyo-night"
    [[ -z "$theme_variant" ]] && theme_variant="night"
    
    # Load theme file
    theme_file="$CURRENT_DIR/themes/${theme}/${theme_variant}.sh"
    if [[ -f "$theme_file" ]]; then
        . "$theme_file"
        # Copy THEME_COLORS to POWERKIT_THEME_COLORS
        if declare -p THEME_COLORS &>/dev/null; then
            for key in "${!THEME_COLORS[@]}"; do
                POWERKIT_THEME_COLORS["$key"]="${THEME_COLORS[$key]}"
            done
        fi
    fi
}

# Get semantic color from theme
# Usage: get_powerkit_color "accent" [fallback]
get_powerkit_color() {
    local color_name="$1"
    local fallback="${2:-$color_name}"
    
    # Load theme if not loaded (handle unset array safely)
    if [[ -z "${POWERKIT_THEME_COLORS[*]+x}" ]] || [[ ${#POWERKIT_THEME_COLORS[@]} -eq 0 ]]; then
        load_powerkit_theme
    fi
    
    # Return theme color or fallback
    printf '%s' "${POWERKIT_THEME_COLORS[$color_name]:-$fallback}"
}

# Alias for get_powerkit_color (shorter name for use in render scripts)
get_color() { get_powerkit_color "$@"; }

# =============================================================================
# Generic Utility Functions
# =============================================================================

# Extract first numeric value from a string (performance: uses bash regex instead of grep)
# Usage: extract_numeric "CPU: 45%" -> "45"
extract_numeric() {
    local content="$1"
    [[ "$content" =~ ([0-9]+) ]] && printf '%s' "${BASH_REMATCH[1]}" || printf ''
}

# Evaluate a numeric condition
# Usage: evaluate_condition <value> <condition> <threshold>
# Conditions: lt, le, gt, ge, eq, ne, always
# Returns: 0 if condition met, 1 otherwise
evaluate_condition() {
    local value="$1"
    local condition="$2"
    local threshold="$3"
    
    [[ "$condition" == "always" || "$condition" == "$POWERKIT_CONDITION_ALWAYS" ]] && return 0
    [[ -z "$threshold" || -z "$value" ]] && return 0
    
    case "$condition" in
        lt) (( value < threshold )) ;;
        le) (( value <= threshold )) ;;
        gt) (( value > threshold )) ;;
        ge) (( value >= threshold )) ;;
        eq) (( value == threshold )) ;;
        ne) (( value != threshold )) ;;
        *)  return 0 ;;
    esac
}

# Format large numbers with K/M/B suffixes
# Usage: format_number <number> [precision]
# Examples: 1234 -> 1.2K, 47000 -> 47K, 1234567 -> 1.2M
format_number() {
    local num="${1:-0}"
    local precision="${2:-1}"

    # Handle non-numeric or empty input
    [[ ! "$num" =~ ^[0-9]+$ ]] && { echo "$num"; return; }

    if (( num >= 1000000000 )); then
        # Billions
        local div=$((num / 1000000000))
        local rem=$(( (num % 1000000000) / 100000000 ))
        if (( rem > 0 && precision > 0 )); then
            printf '%d.%dB' "$div" "$rem"
        else
            printf '%dB' "$div"
        fi
    elif (( num >= 1000000 )); then
        # Millions
        local div=$((num / 1000000))
        local rem=$(( (num % 1000000) / 100000 ))
        if (( rem > 0 && precision > 0 )); then
            printf '%d.%dM' "$div" "$rem"
        else
            printf '%dM' "$div"
        fi
    elif (( num >= 1000 )); then
        # Thousands
        local div=$((num / 1000))
        local rem=$(( (num % 1000) / 100 ))
        if (( rem > 0 && precision > 0 )); then
            printf '%d.%dK' "$div" "$rem"
        else
            printf '%dK' "$div"
        fi
    else
        printf '%d' "$num"
    fi
}

# Build display info string for plugins
# Usage: build_display_info <show> [accent] [accent_icon] [icon]
build_display_info() {
    local show="${1:-1}"
    local accent="${2:-}"
    local accent_icon="${3:-}"
    local icon="${4:-}"

    printf '%s:%s:%s:%s' "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Toast Notification (Popup UI)
# Generic toast notification that stays visible until user dismisses
# =============================================================================

# Show a toast notification with custom content
# Usage: show_toast_notification <title> <content> [width] [height] [type]
#   - content: file path (if exists) OR direct string message
#   - type: "file" (auto-detect), "string" (force string), "error", "warning", "info", "success"
# Examples:
#   show_toast_notification "Warning" "/path/to/file.log"
#   show_toast_notification "Error" "Something went wrong!" 60 20 "error"
#   show_toast_notification "Info" "Operation completed" 50 10 "success"
show_toast_notification() {
    local title="$1"
    local content="$2"
    local popup_width="${3:-70}"
    local popup_height="${4:-20}"
    local content_type="${5:-auto}"
    
    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/${_DEFAULT_CACHE_DIRECTORY:-tmux-powerkit}"
    mkdir -p "$cache_dir"
    
    local content_file=""
    local is_temp_file=false
    
    # Determine content type: file path or string message
    if [[ "$content_type" == "auto" ]]; then
        [[ -f "$content" ]] && content_type="file" || content_type="string"
    fi
    
    # Prepare content file
    if [[ "$content_type" == "file" ]]; then
        content_file="$content"
        [[ ! -f "$content_file" ]] && {
            tmux display-message -d 3000 "Toast error: content file not found" 2>/dev/null || true
            return 1
        }
    else
        # String content - create temp file with optional styling
        content_file="${cache_dir}/.toast_content_$$.log"
        is_temp_file=true
        
        local color_code=""
        case "$content_type" in
            error)   color_code='\033[1;31m' ;;  # Red
            warning) color_code='\033[1;33m' ;;  # Yellow
            success) color_code='\033[1;32m' ;;  # Green
            info)    color_code='\033[1;36m' ;;  # Cyan
            *)       color_code='\033[0m' ;;     # Default
        esac
        
        {
            echo ""
            if [[ -n "$color_code" && "$content_type" != "string" ]]; then
                echo -e "  ${color_code}${content}\033[0m"
            else
                echo -e "  $content"
            fi
            echo ""
        } > "$content_file"
    fi
    
    # Check tmux version for popup support (>= 3.2)
    local tmux_version major minor
    tmux_version=$(tmux -V 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
    major="${tmux_version%%.*}"
    minor="${tmux_version##*.}"
    
    if [[ "$major" -gt 3 ]] || { [[ "$major" -eq 3 ]] && [[ "$minor" -ge 2 ]]; }; then
        # Create popup script
        local popup_script="${cache_dir}/toast_notification.sh"
        
        cat > "$popup_script" << 'TOAST_EOF'
#!/usr/bin/env bash
clear
echo ""
[[ -f "$1" ]] && cat "$1"
echo ""
echo -e "  \033[2m─────────────────────────────────────────────────────────────\033[0m"
echo -e "  \033[1;37mPress any key to dismiss...\033[0m"
echo ""
read -rsn1
TOAST_EOF
        chmod +x "$popup_script"
        
        tmux display-popup -E -w "$popup_width" -h "$popup_height" \
            -T " $title " \
            "bash '$popup_script' '$content_file'" 2>/dev/null || {
            # Fallback
            local first_line
            first_line=$(head -n1 "$content_file" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')
            tmux display-message -d 10000 "$title - $first_line" 2>/dev/null || true
        }
    else
        # Fallback for older tmux
        local first_line
        first_line=$(head -n1 "$content_file" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')
        tmux display-message -d 10000 "$title - $first_line" 2>/dev/null || true
    fi
    
    # Cleanup temp file
    [[ "$is_temp_file" == true ]] && rm -f "$content_file" 2>/dev/null
}

# Shorthand for quick toast messages
# Usage: toast <message> [type] [duration_ms]
toast() {
    local message="$1"
    local type="${2:-info}"
    local duration="${3:-3000}"
    
    # For simple messages, use display-message (faster, non-blocking)
    if [[ "$type" == "simple" ]]; then
        tmux display-message -d "$duration" "$message" 2>/dev/null || true
        return
    fi
    
    # Use popup for styled messages
    local title
    case "$type" in
        error)   title="⚠️  Error" ;;
        warning) title="⚡ Warning" ;;
        success) title="✅ Success" ;;
        info)    title="ℹ️  Info" ;;
        *)       title="📢 Notice" ;;
    esac
    
    show_toast_notification "$title" "$message" 50 10 "$type"
}

# =============================================================================
# Plugin Error Handling & Debug
# Execute plugin with error trapping and optional toast on failure
# =============================================================================

# Global flag to enable/disable error toasts (can be set via tmux option)
_POWERKIT_DEBUG_MODE=""

# Check if debug mode is enabled
is_debug_mode() {
    [[ -z "$_POWERKIT_DEBUG_MODE" ]] && {
        _POWERKIT_DEBUG_MODE=$(get_tmux_option "@powerkit_debug" "false")
    }
    [[ "$_POWERKIT_DEBUG_MODE" == "true" || "$_POWERKIT_DEBUG_MODE" == "1" ]]
}

# Execute a plugin script with error trapping
# Usage: execute_plugin_safe <plugin_script> [args...]
# Returns: plugin output on success, empty on error (with toast if debug mode)
execute_plugin_safe() {
    local plugin_script="$1"
    shift
    local plugin_args=("$@")
    
    local plugin_name
    plugin_name=$(basename "$plugin_script" .sh)
    
    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/${_DEFAULT_CACHE_DIRECTORY:-tmux-powerkit}"
    mkdir -p "$cache_dir"
    
    local error_file="${cache_dir}/.plugin_error_${plugin_name}.log"
    local output_file="${cache_dir}/.plugin_output_${plugin_name}.log"
    
    # Execute plugin capturing stdout and stderr
    local exit_code=0
    if [[ -x "$plugin_script" ]]; then
        "$plugin_script" "${plugin_args[@]}" > "$output_file" 2> "$error_file" || exit_code=$?
    elif [[ -f "$plugin_script" ]]; then
        bash "$plugin_script" "${plugin_args[@]}" > "$output_file" 2> "$error_file" || exit_code=$?
    else
        echo "Plugin not found: $plugin_script" > "$error_file"
        exit_code=127
    fi
    
    # Check for errors
    if [[ $exit_code -ne 0 ]] || [[ -s "$error_file" ]]; then
        if is_debug_mode; then
            _show_plugin_error_toast "$plugin_name" "$exit_code" "$error_file" "$output_file"
        fi
        
        # Graceful degradation - still output whatever plugin produced
        [[ -s "$output_file" ]] && cat "$output_file"
        rm -f "$error_file" "$output_file" 2>/dev/null
        return $exit_code
    fi
    
    cat "$output_file"
    rm -f "$error_file" "$output_file" 2>/dev/null
    return 0
}

# Internal: Build and show error toast for plugin failure
_show_plugin_error_toast() {
    local plugin_name="$1"
    local exit_code="$2"
    local error_file="$3"
    local output_file="$4"
    
    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/${_DEFAULT_CACHE_DIRECTORY:-tmux-powerkit}"
    local toast_content="${cache_dir}/.toast_error_${plugin_name}.log"
    
    {
        echo -e "  \033[1;31m━━━ Plugin Error Report ━━━\033[0m"
        echo ""
        echo -e "  \033[1;37mPlugin:\033[0m    $plugin_name"
        echo -e "  \033[1;37mExit Code:\033[0m $exit_code"
        echo -e "  \033[1;37mTime:\033[0m      $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        
        if [[ -s "$error_file" ]]; then
            echo -e "  \033[1;31m┌─ stderr ─────────────────────────────────────────┐\033[0m"
            sed 's/^/  │ /' "$error_file" | head -20
            echo -e "  \033[1;31m└──────────────────────────────────────────────────┘\033[0m"
            echo ""
        fi
        
        if [[ -s "$output_file" ]]; then
            echo -e "  \033[1;33m┌─ stdout ─────────────────────────────────────────┐\033[0m"
            sed 's/^/  │ /' "$output_file" | head -10
            echo -e "  \033[1;33m└──────────────────────────────────────────────────┘\033[0m"
            echo ""
        fi
        
        echo -e "  \033[2mTip: Disable debug with: set -g @powerkit_debug 'false'\033[0m"
    } > "$toast_content"
    
    # Show toast asynchronously
    (show_toast_notification "⚠️  PowerKit: $plugin_name" "$toast_content" 60 25 &) 2>/dev/null
}

# Execute command with error trapping
# Usage: trap_errors <command> [args...]
trap_errors() {
    local cmd="$1"
    shift
    
    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/${_DEFAULT_CACHE_DIRECTORY:-tmux-powerkit}"
    mkdir -p "$cache_dir"
    
    local error_file="${cache_dir}/.trap_error_$$.log"
    local exit_code=0
    
    "$cmd" "$@" 2> "$error_file" || exit_code=$?
    
    if [[ $exit_code -ne 0 ]] && is_debug_mode && [[ -s "$error_file" ]]; then
        local error_msg
        error_msg=$(cat "$error_file")
        toast "Command failed: $cmd\nExit code: $exit_code\n\n$error_msg" "error"
    fi
    
    rm -f "$error_file" 2>/dev/null
    return $exit_code
}

# =============================================================================
# Centralized Logging System
# =============================================================================

# Log levels: debug, info, warn, error
# Logs to: ~/.cache/tmux-powerkit/powerkit.log

_POWERKIT_LOG_FILE=""

_get_log_file() {
    [[ -n "$_POWERKIT_LOG_FILE" ]] && { printf '%s' "$_POWERKIT_LOG_FILE"; return; }
    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/${_DEFAULT_CACHE_DIRECTORY:-tmux-powerkit}"
    mkdir -p "$cache_dir"
    _POWERKIT_LOG_FILE="${cache_dir}/powerkit.log"
    printf '%s' "$_POWERKIT_LOG_FILE"
}

# Internal logging function
# Usage: _log <level> <source> <message>
_log() {
    local level="$1"
    local source="$2"
    local message="$3"

    # Only log debug messages if debug mode is enabled
    [[ "$level" == "DEBUG" ]] && ! is_debug_mode && return 0

    local log_file
    log_file=$(_get_log_file)

    # Rotate log if > 1MB
    if [[ -f "$log_file" ]]; then
        local size
        if is_macos; then
            size=$(stat -f%z "$log_file" 2>/dev/null || echo 0)
        else
            size=$(stat -c%s "$log_file" 2>/dev/null || echo 0)
        fi
        [[ "$size" -gt 1048576 ]] && mv "$log_file" "${log_file}.old" 2>/dev/null
    fi

    printf '[%s] [%-5s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$source" "$message" >> "$log_file"
}

# Public logging functions
# Usage: log_debug <source> <message>
log_debug() { _log "DEBUG" "$1" "$2"; }

# Usage: log_info <source> <message>
log_info() { _log "INFO" "$1" "$2"; }

# Usage: log_warn <source> <message>
log_warn() { _log "WARN" "$1" "$2"; }

# Usage: log_error <source> <message>
log_error() { _log "ERROR" "$1" "$2"; }

# Log error to file and optionally show toast (backwards compatible)
# Usage: log_plugin_error <plugin_name> <message> [show_toast]
log_plugin_error() {
    local plugin_name="$1"
    local message="$2"
    local show_toast="${3:-false}"

    log_error "$plugin_name" "$message"

    if [[ "$show_toast" == "true" ]] && is_debug_mode; then
        local log_file
        log_file=$(_get_log_file)
        toast "[$plugin_name] $message\n\nLogged to: $log_file" "error"
    fi
}

# Log missing dependency
# Usage: log_missing_dep <plugin_name> <dependency>
log_missing_dep() {
    local plugin_name="$1"
    local dependency="$2"
    log_warn "$plugin_name" "Missing dependency: $dependency"
}

# Get log file path (for users)
# Usage: get_log_file
get_log_file() { _get_log_file; }

# =============================================================================
# Performance Telemetry System (Optional)
# =============================================================================

# Telemetry state
_POWERKIT_TELEMETRY_FILE=""
_POWERKIT_TELEMETRY_ENABLED=""

# Check if telemetry is enabled
is_telemetry_enabled() {
    [[ -z "$_POWERKIT_TELEMETRY_ENABLED" ]] && {
        _POWERKIT_TELEMETRY_ENABLED=$(get_tmux_option "@powerkit_telemetry" "$POWERKIT_TELEMETRY_ENABLED")
    }
    [[ "$_POWERKIT_TELEMETRY_ENABLED" == "true" || "$_POWERKIT_TELEMETRY_ENABLED" == "1" ]]
}

# Get telemetry log file
_get_telemetry_file() {
    [[ -n "$_POWERKIT_TELEMETRY_FILE" ]] && { printf '%s' "$_POWERKIT_TELEMETRY_FILE"; return; }
    local custom_file
    custom_file=$(get_tmux_option "@powerkit_telemetry_log_file" "$POWERKIT_TELEMETRY_LOG_FILE")
    if [[ -n "$custom_file" ]]; then
        _POWERKIT_TELEMETRY_FILE="$custom_file"
    else
        local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/${_DEFAULT_CACHE_DIRECTORY:-tmux-powerkit}"
        mkdir -p "$cache_dir"
        _POWERKIT_TELEMETRY_FILE="${cache_dir}/telemetry.log"
    fi
    printf '%s' "$_POWERKIT_TELEMETRY_FILE"
}

# Get current timestamp in milliseconds
_get_timestamp_ms() {
    if is_macos; then
        # macOS: use python for millisecond precision
        python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null || printf '%s000' "$(date +%s)"
    else
        # Linux: date with nanoseconds
        date +%s%3N 2>/dev/null || printf '%s000' "$(date +%s)"
    fi
}

# Record telemetry event
# Usage: telemetry_record <event_type> <source> <duration_ms> [extra_data]
telemetry_record() {
    is_telemetry_enabled || return 0

    local event_type="$1"
    local source="$2"
    local duration_ms="$3"
    local extra_data="${4:-}"

    local telemetry_file
    telemetry_file=$(_get_telemetry_file)

    # Rotate log if > max size
    if [[ -f "$telemetry_file" ]]; then
        local max_size
        max_size=$(get_tmux_option "@powerkit_telemetry_max_log_size" "$POWERKIT_TELEMETRY_MAX_LOG_SIZE")
        local size
        if is_macos; then
            size=$(stat -f%z "$telemetry_file" 2>/dev/null || echo 0)
        else
            size=$(stat -c%s "$telemetry_file" 2>/dev/null || echo 0)
        fi
        [[ "$size" -gt "$max_size" ]] && mv "$telemetry_file" "${telemetry_file}.old" 2>/dev/null
    fi

    printf '%s|%s|%s|%d|%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$event_type" "$source" "$duration_ms" "$extra_data" >> "$telemetry_file"
}

# Record plugin execution time
# Usage: telemetry_plugin_start <plugin_name>
# Returns: start timestamp
telemetry_plugin_start() {
    is_telemetry_enabled || return 0
    _get_timestamp_ms
}

# Record plugin execution end
# Usage: telemetry_plugin_end <plugin_name> <start_timestamp> [cache_hit]
telemetry_plugin_end() {
    is_telemetry_enabled || return 0

    local plugin_name="$1"
    local start_ts="$2"
    local cache_hit="${3:-false}"

    local end_ts duration_ms
    end_ts=$(_get_timestamp_ms)
    duration_ms=$((end_ts - start_ts))

    # Log slow plugins
    local slow_threshold
    slow_threshold=$(get_tmux_option "@powerkit_telemetry_slow_threshold" "$POWERKIT_TELEMETRY_SLOW_THRESHOLD")
    if [[ "$duration_ms" -ge "$slow_threshold" ]]; then
        log_warn "telemetry" "Slow plugin: $plugin_name took ${duration_ms}ms"
    fi

    # Record telemetry
    local event_type="plugin_exec"
    [[ "$cache_hit" == "true" ]] && event_type="cache_hit"
    telemetry_record "$event_type" "$plugin_name" "$duration_ms" "cache_hit=$cache_hit"
}

# Record cache operation
# Usage: telemetry_cache <operation> <key> <hit>
telemetry_cache() {
    is_telemetry_enabled || return 0

    local track_cache
    track_cache=$(get_tmux_option "@powerkit_telemetry_track_cache_hits" "$POWERKIT_TELEMETRY_TRACK_CACHE_HITS")
    [[ "$track_cache" != "true" ]] && return 0

    local operation="$1"  # get, set, invalidate
    local key="$2"
    local hit="${3:-}"    # true/false for get operations

    telemetry_record "cache_$operation" "$key" 0 "hit=$hit"
}

# Get telemetry summary
# Usage: telemetry_summary [hours]
telemetry_summary() {
    is_telemetry_enabled || { printf 'Telemetry disabled'; return; }

    local hours="${1:-1}"
    local telemetry_file
    telemetry_file=$(_get_telemetry_file)

    [[ ! -f "$telemetry_file" ]] && { printf 'No telemetry data'; return; }

    local cutoff_time
    cutoff_time=$(date -d "-${hours} hours" +%s 2>/dev/null || date -v-"${hours}"H +%s 2>/dev/null)

    # Calculate summary
    local total_events=0 total_time=0 slow_count=0 cache_hits=0 cache_misses=0

    while IFS='|' read -r timestamp event_type source duration extra; do
        total_events=$((total_events + 1))
        total_time=$((total_time + duration))

        local slow_threshold
        slow_threshold=$(get_tmux_option "@powerkit_telemetry_slow_threshold" "$POWERKIT_TELEMETRY_SLOW_THRESHOLD")
        [[ "$duration" -ge "$slow_threshold" ]] && slow_count=$((slow_count + 1))

        [[ "$event_type" == "cache_hit" ]] && cache_hits=$((cache_hits + 1))
        [[ "$event_type" == "cache_get" && "$extra" == *"hit=false"* ]] && cache_misses=$((cache_misses + 1))
    done < "$telemetry_file"

    local avg_time=0
    [[ "$total_events" -gt 0 ]] && avg_time=$((total_time / total_events))

    local cache_total=$((cache_hits + cache_misses))
    local hit_rate=0
    [[ "$cache_total" -gt 0 ]] && hit_rate=$((cache_hits * 100 / cache_total))

    printf 'Events: %d | Avg: %dms | Slow: %d | Cache hit: %d%%\n' \
        "$total_events" "$avg_time" "$slow_count" "$hit_rate"
}

# Clear telemetry data
telemetry_clear() {
    local telemetry_file
    telemetry_file=$(_get_telemetry_file)
    rm -f "$telemetry_file" "${telemetry_file}.old" 2>/dev/null
    log_info "telemetry" "Telemetry data cleared"
}
