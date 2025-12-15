#!/usr/bin/env bash
# =============================================================================
# PowerKit Utility Functions - KISS/DRY Version
# =============================================================================
# shellcheck disable=SC2034

# Source guard
[[ -n "${_POWERKIT_UTILS_LOADED:-}" ]] && return 0
_POWERKIT_UTILS_LOADED=1

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
# Tmux Option Getter
# =============================================================================

get_tmux_option() {
    local option="$1"
    local default_value="$2"
    local value
    value=$(tmux show-option -gqv "$option" 2>/dev/null)
    printf '%s' "${value:-$default_value}"
}

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

# Extract first numeric value from a string
# Usage: extract_numeric "CPU: 45%" -> "45"
extract_numeric() {
    local content="$1"
    echo "$content" | grep -oE '[0-9]+' | head -1
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

# Log error to file and optionally show toast
# Usage: log_plugin_error <plugin_name> <message> [show_toast]
log_plugin_error() {
    local plugin_name="$1"
    local message="$2"
    local show_toast="${3:-false}"
    
    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/${_DEFAULT_CACHE_DIRECTORY:-tmux-powerkit}"
    mkdir -p "$cache_dir"
    
    local log_file="${cache_dir}/errors.log"
    printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$plugin_name" "$message" >> "$log_file"
    
    if [[ "$show_toast" == "true" ]] && is_debug_mode; then
        toast "[$plugin_name] $message\n\nLogged to: $log_file" "error"
    fi
}
