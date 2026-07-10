#!/usr/bin/env bash
# =============================================================================
# Plugin: pomodoro
# Description: Pomodoro timer for productivity with configurable intervals
# Dependencies: none
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"


# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "pomodoro"
    metadata_set "name" "Pomodoro"
    metadata_set "description" "Pomodoro timer with work/break cycles"
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Timer durations
    declare_option "work_duration" "number" "25" "Work session duration in minutes"
    declare_option "short_break" "number" "5" "Short break duration in minutes"
    declare_option "long_break" "number" "15" "Long break duration in minutes"
    declare_option "sessions_before_long" "number" "4" "Work sessions before long break"
    
    # Display options
    declare_option "show_remaining" "bool" "true" "Show remaining time"
    declare_option "show_sessions" "bool" "true" "Show completed session count"

    # Icons
    declare_option "icon" "icon" $'\U000F0517' "Default icon"
    declare_option "icon_work" "icon" $'\U000F13AB' "Work session icon"
    declare_option "icon_break" "icon" $'\U000F04B2' "Break session icon"
    declare_option "icon_stopped" "icon" $'\U000F040C' "Stopped icon"

    # Keybindings
    declare_option "keybinding_toggle" "key" "C-p" "Keybinding to toggle timer"
    declare_option "keybinding_start" "key" "" "Keybinding to start work session"
    declare_option "keybinding_stop" "key" "" "Keybinding to stop timer"
    declare_option "keybinding_skip" "key" "" "Keybinding to skip to next phase"

    # Cache
    declare_option "cache_ttl" "number" "1" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

plugin_get_state() {
    local phase=$(plugin_data_get "phase")
    case "$phase" in
        idle|"")    printf 'inactive' ;;
        work)       printf 'active' ;;
        short_break|long_break) printf 'degraded' ;;
        *)          printf 'inactive' ;;
    esac
}

plugin_get_health() {
    local phase=$(plugin_data_get "phase")
    local remaining=$(plugin_data_get "remaining")
    
    case "$phase" in
        work)
            # Warning if less than 5 minutes remaining
            [[ "${remaining:-0}" -lt 300 ]] && printf 'warning' || printf 'info'
            ;;
        short_break|long_break)
            printf 'warning'
            ;;
        *)
            printf 'ok'
            ;;
    esac
}

plugin_get_context() {
    local phase=$(plugin_data_get "phase")
    local sessions=$(plugin_data_get "sessions")
    
    case "$phase" in
        idle|"")    printf 'stopped' ;;
        work)       printf 'working' ;;
        short_break) printf 'short_break' ;;
        long_break)  printf 'long_break' ;;
        *)          printf 'idle' ;;
    esac
}

plugin_get_icon() {
    local phase=$(plugin_data_get "phase")
    
    case "$phase" in
        work)
            get_option "icon_work"
            return
            ;;
        short_break|long_break)
            get_option "icon_break"
            return
            ;;
        *)
            get_option "icon_stopped"
            return
            ;;
    esac
}

# =============================================================================
# State Management (using cache functions)
# =============================================================================

# Cache TTL for pomodoro state (24 hours - timer should persist)
_POMODORO_STATE_TTL=86400

_load_state() {
    # Read state from cache
    _phase=$(cache_get "pomodoro_phase" "$_POMODORO_STATE_TTL")
    _start_time=$(cache_get "pomodoro_start_time" "$_POMODORO_STATE_TTL")
    _sessions=$(cache_get "pomodoro_sessions" "$_POMODORO_STATE_TTL")

    # Set defaults if not found
    [[ -z "$_phase" ]] && _phase="idle"
    [[ -z "$_start_time" ]] && _start_time="0"
    [[ -z "$_sessions" ]] && _sessions="0"
}

_save_state() {
    local phase="$1"
    local start_time="${2:-$EPOCHSECONDS}"
    local sessions="${3:-0}"

    cache_set "pomodoro_phase" "$phase"
    cache_set "pomodoro_start_time" "$start_time"
    cache_set "pomodoro_sessions" "$sessions"
}

_clear_state() {
    cache_clear "pomodoro_phase"
    cache_clear "pomodoro_start_time"
    cache_clear "pomodoro_sessions"
}

# =============================================================================
# Timer Logic
# =============================================================================

_get_duration_for_phase() {
    local phase="$1"
    case "$phase" in
        work)        echo $(($(get_option "work_duration") * 60)) ;;
        short_break) echo $(($(get_option "short_break") * 60)) ;;
        long_break)  echo $(($(get_option "long_break") * 60)) ;;
        *)           echo 0 ;;
    esac
}

_should_long_break() {
    local sessions="$1"
    local sessions_before=$(get_option "sessions_before_long")
    
    [[ "$sessions" -gt 0 && $((sessions % sessions_before)) -eq 0 ]]
}

_notify() {
    local message="$1"
    tmux display-message "Pomodoro: $message" 2>/dev/null || true
}

# =============================================================================
# Main Logic
# =============================================================================

plugin_collect() {
    _load_state
    
    if [[ "$_phase" == "idle" || -z "$_phase" ]]; then
        plugin_data_set "phase" "idle"
        plugin_data_set "sessions" "${_sessions:-0}"
        return 0
    fi
    
    local current_time=$EPOCHSECONDS
    local duration=$(_get_duration_for_phase "$_phase")
    local elapsed=$((current_time - _start_time))
    local remaining=$((duration - elapsed))
    
    # Timer finished - auto-transition
    if (( remaining <= 0 )); then
        case "$_phase" in
            work)
                # Increment sessions and transition to break
                _sessions=$((_sessions + 1))
                
                # Determine break type
                local break_type="short_break"
                if _should_long_break "$_sessions"; then
                    break_type="long_break"
                    _notify "Work complete! Take a long break."
                else
                    _notify "Work complete! Take a short break."
                fi
                
                _save_state "$break_type" "$EPOCHSECONDS" "$_sessions"
                plugin_data_set "phase" "$break_type"
                plugin_data_set "sessions" "$_sessions"
                
                # Recalculate remaining for new phase
                remaining=$(_get_duration_for_phase "$break_type")
                ;;
            short_break|long_break)
                # Break finished - go idle
                _notify "Break over! Ready for next session."
                _save_state "idle" "0" "$_sessions"
                plugin_data_set "phase" "idle"
                plugin_data_set "sessions" "$_sessions"
                return 0
                ;;
        esac
    else
        plugin_data_set "phase" "$_phase"
        plugin_data_set "sessions" "${_sessions:-0}"
    fi
    
    plugin_data_set "remaining" "$remaining"
}

plugin_render() {
    local phase=$(plugin_data_get "phase")
    local remaining=$(plugin_data_get "remaining")
    local sessions=$(plugin_data_get "sessions")
    local show_remaining=$(get_option "show_remaining")
    local show_sessions=$(get_option "show_sessions")
    
    [[ "$phase" == "idle" || -z "$phase" ]] && return 0
    
    local output=""
    
    if [[ "$show_remaining" == "true" ]]; then
        local secs="${remaining:-0}"
        (( secs < 0 )) && secs=0
        output=$(format_timer "$secs")
    else
        case "$phase" in
            work)        output="Work" ;;
            short_break) output="Break" ;;
            long_break)  output="Long Break" ;;
        esac
    fi
    
    # Append session count
    if [[ "$show_sessions" == "true" ]]; then
        output="$output #${sessions:-0}"
    fi
    
    printf '%s' "$output"
}

# =============================================================================
# Keybindings
# =============================================================================

plugin_setup_keybindings() {
    local toggle_key start_key stop_key skip_key helper_script
    toggle_key=$(get_option "keybinding_toggle")
    start_key=$(get_option "keybinding_start")
    stop_key=$(get_option "keybinding_stop")
    skip_key=$(get_option "keybinding_skip")
    helper_script="${POWERKIT_ROOT}/src/helpers/pomodoro_timer.sh"
    
    [[ ! -x "$helper_script" ]] && chmod +x "$helper_script" 2>/dev/null
    
    [[ -n "$toggle_key" ]] && register_keybinding "$toggle_key" "run-shell 'bash \"$helper_script\" toggle'"
    [[ -n "$start_key" ]] && register_keybinding "$start_key" "run-shell 'bash \"$helper_script\" start'"
    [[ -n "$stop_key" ]] && register_keybinding "$stop_key" "run-shell 'bash \"$helper_script\" stop'"
    [[ -n "$skip_key" ]] && register_keybinding "$skip_key" "run-shell 'bash \"$helper_script\" skip'"
}

