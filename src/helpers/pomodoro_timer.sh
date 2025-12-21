#!/usr/bin/env bash
# Helper: pomodoro_timer - Pomodoro timer CLI operations
# Usage: pomodoro_timer.sh {toggle|start|stop|skip}

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$_SCRIPT_DIR/.."

# Source common dependencies
# shellcheck source=src/helper_bootstrap.sh
. "$ROOT_DIR/helper_bootstrap.sh"

# =============================================================================
# Configuration
# =============================================================================

POMODORO_STATE_FILE="${POWERKIT_CACHE_DIR}/pomodoro_state"

# Defaults from plugin_declare_options() in pomodoro.sh
_work_duration=$(get_tmux_option "@powerkit_plugin_pomodoro_work_duration" "25")
_short_break=$(get_tmux_option "@powerkit_plugin_pomodoro_short_break" "5")
_long_break=$(get_tmux_option "@powerkit_plugin_pomodoro_long_break" "15")
_sessions_before_long=$(get_tmux_option "@powerkit_plugin_pomodoro_sessions_before_long" "4")

# =============================================================================
# Timer Functions
# =============================================================================

# Refresh status bar
force_status_refresh() {
    tmux refresh-client -S 2>/dev/null || true
}

# Get current state: idle|work|short_break|long_break
get_state() {
    [[ -f "$POMODORO_STATE_FILE" ]] && head -1 "$POMODORO_STATE_FILE" || echo "idle"
}

# Get start timestamp
get_start_time() {
    [[ -f "$POMODORO_STATE_FILE" ]] && sed -n '2p' "$POMODORO_STATE_FILE" || echo "0"
}

# Get completed sessions count
get_sessions() {
    [[ -f "$POMODORO_STATE_FILE" ]] && sed -n '3p' "$POMODORO_STATE_FILE" || echo "0"
}

# Save state
save_state() {
    local state="$1"
    local start_time="${2:-$(date +%s)}"
    local sessions="${3:-$(get_sessions)}"
    printf '%s\n%s\n%s\n' "$state" "$start_time" "$sessions" > "$POMODORO_STATE_FILE"
}

# Start work session
start_work() {
    save_state "work" "$(date +%s)" "$(get_sessions)"
    toast " Work session started" "simple"
    force_status_refresh
}

# Start break
start_break() {
    local sessions
    sessions=$(get_sessions)
    local break_type="short_break"

    # Long break after configured sessions
    if [[ $((sessions % _sessions_before_long)) -eq 0 && "$sessions" -gt 0 ]]; then
        break_type="long_break"
    fi

    save_state "$break_type" "$(date +%s)" "$sessions"
    force_status_refresh
}

# Complete work session
complete_work() {
    local sessions
    sessions=$(get_sessions)
    sessions=$((sessions + 1))
    save_state "idle" "0" "$sessions"
    start_break
}

# Stop/reset timer
stop_timer() {
    rm -f "$POMODORO_STATE_FILE"
    toast " Timer stopped" "simple"
    force_status_refresh
}

# Toggle timer (start if idle, stop if running)
toggle_timer() {
    local state
    state=$(get_state)
    case "$state" in
        idle) start_work ;;
        work|short_break|long_break) stop_timer ;;
    esac
}

# Skip to next phase
skip_phase() {
    local state
    state=$(get_state)
    case "$state" in
        work)
            complete_work
            toast " Skipped to break" "simple"
            ;;
        short_break|long_break)
            save_state "idle" "0" "$(get_sessions)"
            start_work
            ;;
        idle)
            toast " No active session" "simple"
            ;;
    esac
}

# =============================================================================
# Main
# =============================================================================

case "${1:-}" in
    toggle) toggle_timer ;;
    start)  start_work ;;
    stop)   stop_timer ;;
    skip)   skip_phase ;;
    *)      echo "Usage: $0 {toggle|start|stop|skip}"; exit 1 ;;
esac
