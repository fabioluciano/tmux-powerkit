#!/usr/bin/env bash
# =============================================================================
# PowerKit Utils: Keybinding
# Description: Utilities for binding tmux keys with flexible options
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "utils_keybinding" && return 0

. "${POWERKIT_ROOT}/src/core/logger.sh"
. "${POWERKIT_ROOT}/src/core/options.sh"
. "${POWERKIT_ROOT}/src/core/cache.sh"
. "${POWERKIT_ROOT}/src/utils/ui_backend.sh"

# =============================================================================
# Conflict Detection
# =============================================================================

# Global array to track reported conflicts in this session
declare -gA _REPORTED_CONFLICTS=()

# Clear conflict log file for new session
# Usage: _clear_conflict_log
_clear_conflict_log() {
    local cache_dir
    cache_dir="$(dirname "$(get_cache_dir)")"
    local log_file="${cache_dir}/keybinding_conflicts.log"
    [[ -f "$log_file" ]] && rm -f "$log_file"
    _REPORTED_CONFLICTS=()
}

# Check and log keybinding conflicts
# Usage: _check_and_log_conflict KEY SOURCE
_check_and_log_conflict() {
    local key="$1" source="$2"
    
    # Check if we already reported this key conflict
    if [[ -n "${_REPORTED_CONFLICTS[$key]:-}" ]]; then
        return 0
    fi
    
    # Get conflict action setting
    local conflict_action
    conflict_action=$(get_tmux_option "@powerkit_keybinding_conflict_action" "warn")
    
    # Skip if conflict detection is disabled
    [[ "$conflict_action" == "ignore" ]] && return 0
    
    # Check if this key is already bound
    local existing_binding
    existing_binding=$(tmux list-keys -T prefix 2>/dev/null | grep "bind-key.*-T prefix.*$key " || true)
    
    [[ -z "$existing_binding" ]] && return 0
    
    # Extract the command from existing binding
    local existing_cmd=""
    if [[ "$existing_binding" =~ bind-key[[:space:]]+-T[[:space:]]+prefix[[:space:]]+[^[:space:]]+[[:space:]]+(.+) ]]; then
        existing_cmd="${BASH_REMATCH[1]}"
    fi
    
    # Check if it's a PowerKit binding
    if [[ "$existing_cmd" == *"/tmux-powerkit/"* ]] || \
       [[ "$existing_cmd" == *"powerkit"* ]] || \
       [[ "$existing_cmd" == *"PowerKit"* ]]; then
        # It's a PowerKit binding - no conflict
        return 0
    fi
    
    # Mark this conflict as reported
    _REPORTED_CONFLICTS[$key]="$source"
    
    # Real conflict detected - log it
    local cache_dir
    cache_dir="$(dirname "$(get_cache_dir)")"
    local log_file="${cache_dir}/keybinding_conflicts.log"
    
    # Ensure cache directory exists
    [[ -d "$cache_dir" ]] || mkdir -p "$cache_dir"
    
    # Append to log file (just the conflict line, footer will be added later)
    {
        if [[ ! -f "$log_file" ]]; then
            echo "=== PowerKit Keybinding Conflicts ==="
            echo "Detected at: $(date)"
            echo "Conflict action: $conflict_action"
            echo ""
        fi
        echo "  • External conflict: '$key' wanted by PowerKit:$source, but already bound to: ${existing_cmd:0:80}"
    } >> "$log_file"
    
    log_warn "keybinding" "Conflict: '$key' ($source) will override: ${existing_cmd:0:60}"
}

# =============================================================================
# Keybinding Types
# =============================================================================
# - run-shell: Execute a shell command (simple commands)
# - popup: Display a popup window with a command
# - display-message: Show a tmux message
# - send-keys: Send keys to the current pane
# - custom: Raw tmux command (advanced usage)

# =============================================================================
# Core Binding Function
# =============================================================================

# Bind a key in tmux with full flexibility
# Usage: pk_bind [OPTIONS] KEY COMMAND
#
# Options:
#   -t, --type TYPE       Binding type: run-shell, popup, display-message, send-keys, custom
#                         (default: run-shell)
#   -T, --table TABLE     Key table: prefix, root, copy-mode, copy-mode-vi
#                         (default: prefix)
#   -n, --no-prefix       Shorthand for --table root (bind without prefix)
#   -r, --repeat          Allow key repeat
#   -N, --note NOTE       Description note for the binding
#   -w, --width WIDTH     Popup width (only for popup type)
#   -H, --height HEIGHT   Popup height (only for popup type) - Note: uppercase H
#   -s, --source SOURCE   Source identifier for logging (e.g., "pomodoro:toggle")
#   -b, --background      Run in background (for run-shell type)
#
# Examples:
#   pk_bind "C-x" "echo hello"
#   pk_bind -t popup -w "80%" -H "60%" "C-e" "bash script.sh"
#   pk_bind -n "M-x" "tmux display-message 'Hello'"
#   pk_bind -T root "M-Left" "select-pane -L"
#
pk_bind() {
    local key="" command=""
    local bind_type="run-shell"
    local table="prefix"
    local repeat=""
    local note=""
    local popup_width=""
    local popup_height=""
    local source=""
    local background=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--type)
                bind_type="$2"
                shift 2
                ;;
            -T|--table)
                table="$2"
                shift 2
                ;;
            -n|--no-prefix)
                table="root"
                shift
                ;;
            -r|--repeat)
                repeat="-r"
                shift
                ;;
            -N|--note)
                note="$2"
                shift 2
                ;;
            -w|--width)
                popup_width="$2"
                shift 2
                ;;
            -H|--height)
                popup_height="$2"
                shift 2
                ;;
            -s|--source)
                source="$2"
                shift 2
                ;;
            -b|--background)
                background="-b"
                shift
                ;;
            -*)
                log_warn "keybinding" "Unknown option: $1"
                shift
                ;;
            *)
                if [[ -z "$key" ]]; then
                    key="$1"
                else
                    command="$1"
                fi
                shift
                ;;
        esac
    done

    # Validate required parameters
    if [[ -z "$key" ]]; then
        log_error "keybinding" "pk_bind: key is required"
        return 1
    fi

    if [[ -z "$command" && "$bind_type" != "custom" ]]; then
        log_error "keybinding" "pk_bind: command is required"
        return 1
    fi

    # Check for keybinding conflicts (only for prefix table)
    if [[ "$table" == "prefix" && -n "$source" ]]; then
        _check_and_log_conflict "$key" "$source"
    fi

    # Build the bind-key command
    local bind_args=()
    bind_args+=("-T" "$table")
    
    if [[ -n "$repeat" ]]; then bind_args+=("$repeat"); fi
    if [[ -n "$note" ]]; then bind_args+=("-N" "$note"); fi
    
    bind_args+=("$key")

    # Build command based on type
    case "$bind_type" in
        run-shell)
            bind_args+=("run-shell" ${background:+"$background"} "$command")
            ;;
        popup)
            local popup_args=("-E")
            if [[ -n "$popup_width" ]]; then popup_args+=("-w" "$popup_width"); fi
            if [[ -n "$popup_height" ]]; then popup_args+=("-h" "$popup_height"); fi
            bind_args+=("display-popup" "${popup_args[@]}" "$command")
            ;;
        display-message)
            bind_args+=("display-message" "$command")
            ;;
        send-keys)
            bind_args+=("send-keys" "$command")
            ;;
        custom)
            # For custom, command is the full tmux command
            # shellcheck disable=SC2206 # Intentional word splitting for tmux args
            bind_args+=($command)
            ;;
        *)
            log_error "keybinding" "pk_bind: unknown type '$bind_type'"
            return 1
            ;;
    esac

    # Execute the bind-key command
    if tmux bind-key "${bind_args[@]}"; then
        local table_info
        [[ "$table" == "root" ]] && table_info="(no prefix)" || table_info="(prefix + $key)"
        log_debug "keybinding" "Bound: ${source:-$key} $table_info -> $bind_type"
        return 0
    else
        log_error "keybinding" "Failed to bind: ${source:-$key}"
        return 1
    fi
}

# =============================================================================
# Convenience Functions
# =============================================================================

# Bind a key to run a shell command (with prefix)
# Usage: pk_bind_shell KEY COMMAND [SOURCE]
pk_bind_shell() {
    local key="$1" command="$2" source="${3:-}"
    [[ -z "$key" ]] && return 0
    if [[ -n "$source" ]]; then
        pk_bind -s "$source" "$key" "$command"
    else
        pk_bind "$key" "$command"
    fi
}

# Bind a key to run a shell command (without prefix - root table)
# Usage: pk_bind_shell_root KEY COMMAND [SOURCE]
pk_bind_shell_root() {
    local key="$1" command="$2" source="${3:-}"
    [[ -z "$key" ]] && return 0
    if [[ -n "$source" ]]; then
        pk_bind -n -s "$source" "$key" "$command"
    else
        pk_bind -n "$key" "$command"
    fi
}

# Bind a key to open a popup (with prefix)
# Usage: pk_bind_popup KEY COMMAND [WIDTH] [HEIGHT] [SOURCE]
pk_bind_popup() {
    local key="$1" command="$2"
    local width="${3:-80%}" height="${4:-60%}" source="${5:-}"
    [[ -z "$key" ]] && return 0
    if [[ -n "$source" ]]; then
        pk_bind -t popup -w "$width" -H "$height" -s "$source" "$key" "$command"
    else
        pk_bind -t popup -w "$width" -H "$height" "$key" "$command"
    fi
}

# Bind a key to open a popup (without prefix - root table)
# Usage: pk_bind_popup_root KEY COMMAND [WIDTH] [HEIGHT] [SOURCE]
pk_bind_popup_root() {
    local key="$1" command="$2"
    local width="${3:-80%}" height="${4:-60%}" source="${5:-}"
    [[ -z "$key" ]] && return 0
    if [[ -n "$source" ]]; then
        pk_bind -n -t popup -w "$width" -H "$height" -s "$source" "$key" "$command"
    else
        pk_bind -n -t popup -w "$width" -H "$height" "$key" "$command"
    fi
}

# Bind a key to display a message
# Usage: pk_bind_message KEY MESSAGE [SOURCE]
pk_bind_message() {
    local key="$1" message="$2" source="${3:-}"
    [[ -z "$key" ]] && return 0
    if [[ -n "$source" ]]; then
        pk_bind -t display-message -s "$source" "$key" "$message"
    else
        pk_bind -t display-message "$key" "$message"
    fi
}

# =============================================================================
# Smart Binding (Auto-detect table based on key)
# =============================================================================

# Intelligently bind a key, auto-detecting if it should use root table
# Keys with M- (Meta/Alt) can optionally be bound to root for direct access
# Usage: pk_bind_smart KEY COMMAND [OPTIONS...]
#   Options are passed through to pk_bind
#
# Environment:
#   POWERKIT_META_KEYS_USE_ROOT - If "true", M- keys are bound to root table
#
pk_bind_smart() {
    local key="$1"
    shift
    
    [[ -z "$key" ]] && return 0
    
    # Check if Meta keys should use root table
    local use_root="${POWERKIT_META_KEYS_USE_ROOT:-false}"
    
    if [[ "$use_root" == "true" && "$key" =~ ^M- ]]; then
        pk_bind -n "$key" "$@"
    else
        pk_bind "$key" "$@"
    fi
}

# =============================================================================
# Unbind Function
# =============================================================================

# Unbind a key from tmux
# Usage: pk_unbind [-T TABLE] KEY
pk_unbind() {
    local table="prefix"
    local key=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -T|--table)
                table="$2"
                shift 2
                ;;
            -n|--no-prefix)
                table="root"
                shift
                ;;
            *)
                key="$1"
                shift
                ;;
        esac
    done
    
    [[ -z "$key" ]] && return 1
    
    if tmux unbind-key -T "$table" "$key" 2>/dev/null; then
        log_debug "keybinding" "Unbound: $key from $table table"
        return 0
    else
        log_debug "keybinding" "Key not bound: $key in $table table"
        return 1
    fi
}

# =============================================================================
# Utility Functions
# =============================================================================

# Check if a key is bound in a specific table
# Usage: pk_is_bound [-T TABLE] KEY
# Returns: 0 if bound, 1 if not
pk_is_bound() {
    local table="prefix"
    local key=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -T|--table)
                table="$2"
                shift 2
                ;;
            -n|--no-prefix)
                table="root"
                shift
                ;;
            *)
                key="$1"
                shift
                ;;
        esac
    done
    
    [[ -z "$key" ]] && return 1
    
    tmux list-keys -T "$table" 2>/dev/null | grep -q "\\b${key}\\b"
}

# Get the command bound to a key
# Usage: pk_get_binding [-T TABLE] KEY
pk_get_binding() {
    local table="prefix"
    local key=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -T|--table)
                table="$2"
                shift 2
                ;;
            -n|--no-prefix)
                table="root"
                shift
                ;;
            *)
                key="$1"
                shift
                ;;
        esac
    done
    
    [[ -z "$key" ]] && return 1
    
    tmux list-keys -T "$table" 2>/dev/null | grep "\\b${key}\\b" | head -1
}

# =============================================================================
# Direct Execution Functions (not for binding, but for running commands)
# =============================================================================

# Run a shell command in tmux
# Usage: pk_run_shell [-b|--background] COMMAND
pk_run_shell() {
    local background=""
    local command=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -b|--background)
                background="-b"
                shift
                ;;
            *)
                command="$1"
                shift
                ;;
        esac
    done
    
    [[ -z "$command" ]] && return 1
    
    # shellcheck disable=SC2086
    tmux run-shell $background "$command"
}

# Show a popup with a command
# Usage: pk_popup [-w WIDTH] [-H HEIGHT] [-T TITLE] [-E] COMMAND
pk_popup() {
    local width="" height="" title="" exit_on_close="-E"
    local command=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -w|--width)
                width="$2"
                shift 2
                ;;
            -H|--height)
                height="$2"
                shift 2
                ;;
            -T|--title)
                title="$2"
                shift 2
                ;;
            -E)
                exit_on_close="-E"
                shift
                ;;
            --no-exit)
                exit_on_close=""
                shift
                ;;
            *)
                command="$1"
                shift
                ;;
        esac
    done
    
    [[ -z "$command" ]] && return 1
    
    local popup_args=()
    if [[ -n "$exit_on_close" ]]; then popup_args+=("$exit_on_close"); fi
    if [[ -n "$title" ]]; then popup_args+=("-T" "$title"); fi
    if [[ -n "$width" ]]; then popup_args+=("-w" "$width"); fi
    if [[ -n "$height" ]]; then popup_args+=("-h" "$height"); fi
    popup_args+=("$command")
    
    tmux display-popup "${popup_args[@]}"
}

# Show a popup with a command after a delay (non-blocking)
# Usage: pk_popup_delayed DELAY_SECONDS [-w WIDTH] [-H HEIGHT] COMMAND
pk_popup_delayed() {
    local delay="${1:-1}"
    shift
    
    local width="" height="" command=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -w|--width)
                width="-w $2"
                shift 2
                ;;
            -H|--height)
                height="-h $2"
                shift 2
                ;;
            *)
                command="$1"
                shift
                ;;
        esac
    done
    
    [[ -z "$command" ]] && return 1
    
    # Run popup in background with delay
    # Wait for a client to be attached before showing the popup
    # This handles the case where PowerKit starts during detached session creation
    local popup_script
    popup_script=$(cat << 'SCRIPT_EOF'
delay=DELAY_PLACEHOLDER
width="WIDTH_PLACEHOLDER"
height="HEIGHT_PLACEHOLDER"
command="COMMAND_PLACEHOLDER"

# Wait for initial delay
sleep "$delay"

# Wait up to 30 seconds for a client to attach
max_wait=30
waited=0
while [[ $waited -lt $max_wait ]]; do
    if tmux list-clients 2>/dev/null | grep -q .; then
        # Client found, show popup
        tmux display-popup -E $width $height "$command"
        exit 0
    fi
    sleep 1
    ((waited++))
done
# No client attached after timeout, skip popup silently
SCRIPT_EOF
)
    
    # Substitute placeholders
    popup_script="${popup_script//DELAY_PLACEHOLDER/$delay}"
    popup_script="${popup_script//WIDTH_PLACEHOLDER/$width}"
    popup_script="${popup_script//HEIGHT_PLACEHOLDER/$height}"
    popup_script="${popup_script//COMMAND_PLACEHOLDER/$command}"
    
    # Execute via bash
    tmux run-shell -b "bash -c '$popup_script'" 2>/dev/null || true
}

# =============================================================================
# Toast Wrappers (delegates to ui_backend.sh)
# =============================================================================

# Legacy wrapper - delegates to ui_toast from ui_backend.sh
# Usage: pk_toast MESSAGE [LEVEL]
pk_toast() {
    ui_toast "$@"
}

# Legacy wrapper - delegates to ui_toast_popup from ui_backend.sh
# Usage: pk_toast_popup MESSAGE [WIDTH] [HEIGHT]
pk_toast_popup() {
    ui_toast_popup "$@"
}

# =============================================================================
# Plugin Keybinding Registration
# =============================================================================

# Register a keybinding from a plugin
# This function is used by plugins to register their keybindings during setup
# Usage: register_keybinding KEY TMUX_COMMAND [SOURCE]
#
# Arguments:
#   KEY          - The key combination (e.g., "C-p", "M-k")
#   TMUX_COMMAND - Complete tmux command (e.g., "run-shell '...'", "display-popup -E ...")
#   SOURCE       - Optional source identifier for logging (default: "plugin")
#
# Examples:
#   register_keybinding "C-p" "run-shell 'bash script.sh'"
#   register_keybinding "M-k" "display-popup -E -w 80% -h 60% 'command'"
#
register_keybinding() {
    local key="${1:-}"
    local tmux_command="${2:-}"
    local source="${3:-plugin}"

    # Validate parameters
    if [[ -z "$key" ]]; then
        log_warn "keybinding" "register_keybinding: key is required"
        return 1
    fi

    if [[ -z "$tmux_command" ]]; then
        log_warn "keybinding" "register_keybinding: command is required"
        return 1
    fi

    # Use pk_bind with custom type to pass through the complete tmux command
    pk_bind -t custom -s "$source" "$key" "$tmux_command"
}

log_debug "keybinding" "Keybinding utils module loaded"
