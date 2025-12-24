#!/usr/bin/env bash
# =============================================================================
# Helper: pomodoro_timer
# Description: Pomodoro timer CLI operations
# Type: command
# =============================================================================

# Source helper base (handles all initialization)
. "$(dirname "${BASH_SOURCE[0]}")/../contract/helper_contract.sh"
helper_init

# =============================================================================
# Metadata
# =============================================================================

helper_get_metadata() {
    helper_metadata_set "id" "pomodoro_timer"
    helper_metadata_set "name" "Pomodoro Timer"
    helper_metadata_set "description" "Control the Pomodoro timer"
    helper_metadata_set "type" "command"
    helper_metadata_set "version" "2.0.0"
}

helper_get_actions() {
    echo "toggle - Start if idle, stop if running"
    echo "start  - Start a work session"
    echo "stop   - Stop/reset the timer"
    echo "skip   - Skip to next phase"
}

# =============================================================================
# Configuration
# =============================================================================

_CACHE_BASE_DIR="$(dirname "$(get_cache_dir)")"
POMODORO_STATE_FILE="${_CACHE_BASE_DIR}/pomodoro_state"

# Defaults from plugin_declare_options() in pomodoro.sh
_work_duration=$(get_tmux_option "@powerkit_plugin_pomodoro_work_duration" "25")
_short_break=$(get_tmux_option "@powerkit_plugin_pomodoro_short_break" "5")
_long_break=$(get_tmux_option "@powerkit_plugin_pomodoro_long_break" "15")
_sessions_before_long=$(get_tmux_option "@powerkit_plugin_pomodoro_sessions_before_long" "4")

# =============================================================================
# Timer Functions
# =============================================================================

# Refresh status bar
_force_status_refresh() {
    tmux refresh-client -S 2>/dev/null || true
}

# Get current state: idle|work|short_break|long_break
_get_state() {
    [[ -f "$POMODORO_STATE_FILE" ]] && head -1 "$POMODORO_STATE_FILE" || echo "idle"
}

# Get start timestamp
_get_start_time() {
    [[ -f "$POMODORO_STATE_FILE" ]] && sed -n '2p' "$POMODORO_STATE_FILE" || echo "0"
}

# Get completed sessions count
_get_sessions() {
    [[ -f "$POMODORO_STATE_FILE" ]] && sed -n '3p' "$POMODORO_STATE_FILE" || echo "0"
}

# Save state
_save_state() {
    local state="$1"
    local start_time="${2:-$(date +%s)}"
    local sessions="${3:-$(_get_sessions)}"
    printf '%s\n%s\n%s\n' "$state" "$start_time" "$sessions" > "$POMODORO_STATE_FILE"
}

# Start work session
_start_work() {
    _save_state "work" "$(date +%s)" "$(_get_sessions)"
    helper_toast " Work session started"
    _force_status_refresh
}

# Start break
_start_break() {
    local sessions
    sessions=$(_get_sessions)
    local break_type="short_break"

    # Long break after configured sessions
    if [[ $((sessions % _sessions_before_long)) -eq 0 && "$sessions" -gt 0 ]]; then
        break_type="long_break"
    fi

    _save_state "$break_type" "$(date +%s)" "$sessions"
    _force_status_refresh
}

# Complete work session
_complete_work() {
    local sessions
    sessions=$(_get_sessions)
    sessions=$((sessions + 1))
    _save_state "idle" "0" "$sessions"
    _start_break
}

# Stop/reset timer
_stop_timer() {
    rm -f "$POMODORO_STATE_FILE"
    helper_toast " Timer stopped"
    _force_status_refresh
}

# Toggle timer (start if idle, stop if running)
_toggle_timer() {
    local state
    state=$(_get_state)
    case "$state" in
        idle) _start_work ;;
        work|short_break|long_break) _stop_timer ;;
    esac
}

# Skip to next phase
_skip_phase() {
    local state
    state=$(_get_state)
    case "$state" in
        work)
            _complete_work
            helper_toast " Skipped to break"
            ;;
        short_break|long_break)
            _save_state "idle" "0" "$(_get_sessions)"
            _start_work
            ;;
        idle)
            helper_toast " No active session"
            ;;
    esac
}

# =============================================================================
# Main Entry Point
# =============================================================================

helper_main() {
    local action="${1:-}"

    case "$action" in
        toggle) _toggle_timer ;;
        start)  _start_work ;;
        stop)   _stop_timer ;;
        skip)   _skip_phase ;;
        "")     _toggle_timer ;;  # Default action
        *)
            echo "Unknown action: $action" >&2
            echo "Use --help for usage information" >&2
            return 1
            ;;
    esac
}

# Dispatch to handler
helper_dispatch "$@"
