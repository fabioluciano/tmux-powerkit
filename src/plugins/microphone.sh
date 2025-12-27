#!/usr/bin/env bash
# =============================================================================
# Plugin: microphone
# Description: Display microphone status - shows only when microphone is active
# Type: conditional (hidden when microphone is inactive)
# Dependencies: Linux: pactl/amixer (optional)
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active: Microphone is in use
#   - inactive: Microphone is not in use (plugin hidden)
#
# Health:
#   - ok: Microphone active and unmuted
#   - warning: Microphone active but muted
#   - info: Microphone inactive
#
# Context:
#   - muted: Microphone is muted
#   - unmuted: Microphone is not muted
#
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "microphone"
    metadata_set "name" "Microphone"
    metadata_set "description" "Display microphone status"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    if is_linux; then
        require_any_cmd "pactl" "amixer" 1  # Optional
    fi
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    declare_option "icon" "icon" $'\U000F036C' "Microphone icon"
    declare_option "icon_muted" "icon" $'\U000F036D' "Microphone muted icon"
    declare_option "cache_ttl" "number" "2" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

plugin_get_state() {
    local status
    status=$(plugin_data_get "status")
    [[ "$status" == "active" ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() {
    local status mute
    status=$(plugin_data_get "status")
    mute=$(plugin_data_get "mute")

    [[ "$status" != "active" ]] && { printf 'info'; return; }
    [[ "$mute" == "muted" ]] && printf 'warning' || printf 'ok'
}

plugin_get_context() {
    local mute
    mute=$(plugin_data_get "mute")
    printf '%s' "${mute:-unmuted}"
}

plugin_get_icon() {
    local mute
    mute=$(plugin_data_get "mute")
    [[ "$mute" == "muted" ]] && get_option "icon_muted" || get_option "icon"
}

# =============================================================================
# Detection Logic
# =============================================================================

_detect_linux_mute() {
    # Method 1: PulseAudio/PipeWire via pactl
    if has_cmd pactl; then
        local default_source mute_status
        default_source=$(pactl get-default-source 2>/dev/null)
        if [[ -n "$default_source" ]]; then
            mute_status=$(pactl get-source-mute "$default_source" 2>/dev/null | grep -o "yes\|no")
            [[ "$mute_status" == "yes" ]] && { echo "muted"; return; }
        fi
    fi

    # Method 2: ALSA via amixer
    if has_cmd amixer; then
        amixer get Capture 2>/dev/null | grep -q "\[off\]" && { echo "muted"; return; }
    fi

    echo "unmuted"
}

_detect_linux_usage() {
    # Method 1: Check PulseAudio source outputs (most reliable)
    if has_cmd pactl; then
        pactl list short source-outputs 2>/dev/null | grep -q . && { echo "active"; return; }
    fi

    # Method 2: Check for processes using audio capture devices
    if has_cmd lsof; then
        local active_capture
        active_capture=$(lsof /dev/snd/* 2>/dev/null | grep -E "pcmC[0-9]+D[0-9]+c" | grep -cvE "(pipewire|wireplumb|pulseaudio)")
        [[ "${active_capture:-0}" -gt 0 ]] && { echo "active"; return; }
    fi

    echo "inactive"
}

_is_microphone_active() {
    # macOS: Cannot reliably detect microphone usage without SIP bypass
    is_macos && return 1

    # Linux: Multiple detection methods
    is_linux && [[ "$(_detect_linux_usage)" == "active" ]] && return 0

    return 1
}

_get_mute_status() {
    is_linux && { _detect_linux_mute; return; }
    echo "unmuted"
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    if _is_microphone_active; then
        plugin_data_set "status" "active"
        plugin_data_set "mute" "$(_get_mute_status)"
    else
        plugin_data_set "status" "inactive"
        plugin_data_set "mute" "unmuted"
    fi
}

# =============================================================================
# Plugin Contract: Render (TEXT ONLY)
# =============================================================================

plugin_render() {
    local mute
    mute=$(plugin_data_get "mute")
    [[ "$mute" == "muted" ]] && printf 'MUTED' || printf 'ON'
}
