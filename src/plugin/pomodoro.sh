#!/usr/bin/env bash
# =============================================================================
# Plugin: pomodoro - Pomodoro timer for productivity
# Description: Track work sessions with configurable work/break intervals
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "work_duration" "number" "1" "Work session duration in minutes"
    declare_option "short_break" "number" "5" "Short break duration in minutes"
    declare_option "long_break" "number" "15" "Long break duration in minutes"
    declare_option "sessions_before_long" "number" "4" "Sessions before long break"
    declare_option "show_sessions" "bool" "true" "Show completed sessions count"

    # Icons
    declare_option "icon" "icon" $'\U000F0517' "Plugin icon"
    declare_option "icon_work" "icon" $'\U000F13AB' "Icon during work session"
    declare_option "icon_break" "icon" $'\U000F04B2' "Icon during break"

    # Colors - Work session
    declare_option "work_accent_color" "color" "info" "Background color during work"
    declare_option "work_accent_color_icon" "color" "info" "Icon background during work"

    # Colors - Break session
    declare_option "break_accent_color" "color" "success" "Background color during break"
    declare_option "break_accent_color_icon" "color" "success" "Icon background during break"

    # Keybindings
    declare_option "toggle_key" "key" "C-p" "Keybinding to toggle timer"
    declare_option "start_key" "key" "" "Keybinding to start work session"
    declare_option "stop_key" "key" "" "Keybinding to stop timer"
    declare_option "skip_key" "key" "" "Keybinding to skip to next phase"
}

plugin_init "pomodoro"

# State file for persistent timer
POMODORO_STATE_FILE="${CACHE_DIR}/pomodoro_state"

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"

    # Hide if idle/empty
    [[ -z "$content" || "$content" == "idle" ]] && { build_display_info "0" "" "" ""; return; }

    local state=$(_get_state)
    local accent="" accent_icon="" icon=""

    case "$state" in
        work)
            accent=$(get_option "work_accent_color")
            accent_icon=$(get_option "work_accent_color_icon")
            icon=$(get_option "icon_work")
            ;;
        short_break|long_break)
            accent=$(get_option "break_accent_color")
            accent_icon=$(get_option "break_accent_color_icon")
            icon=$(get_option "icon_break")
            ;;
    esac

    build_display_info "1" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Configuration
# =============================================================================

_work_duration=$(get_option "work_duration")
_short_break=$(get_option "short_break")
_long_break=$(get_option "long_break")
_sessions_before_long=$(get_option "sessions_before_long")
_show_sessions=$(get_option "show_sessions")

# =============================================================================
# Helper Functions
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
    _force_status_refresh
}

# Start break
_start_break() {
    local sessions=$(_get_sessions)
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
    local sessions=$(_get_sessions)
    sessions=$((sessions + 1))
    _save_state "idle" "0" "$sessions"
    _start_break
}

# Stop/reset timer
_stop_timer() {
    rm -f "$POMODORO_STATE_FILE"
    _force_status_refresh
}

# Toggle timer (start if idle, pause/resume otherwise)
_toggle_timer() {
    local state=$(_get_state)
    case "$state" in
        idle) _start_work ;;
        work|short_break|long_break) _stop_timer ;;
    esac
}

# Format time remaining as MM:SS
_format_time() {
    local seconds="$1"
    [[ "$seconds" -lt 0 ]] && seconds=0
    printf '%02d:%02d' "$((seconds / 60))" "$((seconds % 60))"
}

# =============================================================================
# Keybinding Setup
# =============================================================================

setup_keybindings() {
    local helper_path="${ROOT_DIR}/../helpers/pomodoro_timer.sh"
    local toggle_key start_key stop_key skip_key

    toggle_key=$(get_option "toggle_key")
    start_key=$(get_option "start_key")
    stop_key=$(get_option "stop_key")
    skip_key=$(get_option "skip_key")

    # Toggle (start/stop)
    [[ -n "$toggle_key" ]] && tmux bind-key "$toggle_key" run-shell \
        "bash '$helper_path' toggle"

    # Start work session
    [[ -n "$start_key" ]] && tmux bind-key "$start_key" run-shell \
        "bash '$helper_path' start"

    # Stop/reset
    [[ -n "$stop_key" ]] && tmux bind-key "$stop_key" run-shell \
        "bash '$helper_path' stop"

    # Skip to next phase
    [[ -n "$skip_key" ]] && tmux bind-key "$skip_key" run-shell \
        "bash '$helper_path' skip"
}

# =============================================================================
# Main Logic
# =============================================================================

_compute_pomodoro() {
    local state=$(_get_state)
    [[ "$state" == "idle" ]] && return

    local start_time=$(_get_start_time)
    local current_time=$(date +%s)
    local elapsed=$((current_time - start_time))
    local duration=0
    local icon=""

    case "$state" in
        work)
            duration=$((_work_duration * 60))
            icon=$(get_option "icon_work")
            ;;
        short_break)
            duration=$((_short_break * 60))
            icon=$(get_option "icon_break")
            ;;
        long_break)
            duration=$((_long_break * 60))
            icon=$(get_option "icon_break")
            ;;
    esac

    local remaining=$((duration - elapsed))

    # Auto-transition when timer expires
    if [[ "$remaining" -le 0 ]]; then
        case "$state" in
            work)
                # Notify and transition to break
                tmux display-message "Pomodoro: Work session complete! Take a break." 2>/dev/null || true
                _complete_work
                # Re-compute with new state
                _compute_pomodoro
                return
                ;;
            short_break|long_break)
                # Notify and go idle
                tmux display-message "Pomodoro: Break over! Ready for next session." 2>/dev/null || true
                _save_state "idle" "0" "$(_get_sessions)"
                return
                ;;
        esac
    fi

    local output=$(_format_time "$remaining")

    # Show session count if enabled
    if [[ "$_show_sessions" == "true" ]]; then
        local sessions=$(_get_sessions)
        output="$output #$sessions"
    fi

    printf '%s' "$output"
}

load_plugin() {
    _compute_pomodoro
}

[[ -z "${1:-}" ]] && load_plugin || true
