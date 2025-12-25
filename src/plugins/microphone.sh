#!/usr/bin/env bash
# =============================================================================
# Plugin: microphone
# Description: Display microphone activity status (active/inactive/muted)
# Type: conditional (hidden when inactive)
# Dependencies: macOS: osascript, Linux: pactl/amixer (optional)
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active: Microphone is being used
#   - inactive: Microphone is not in use (plugin hidden)
#
# Health:
#   - ok: Microphone active, unmuted
#   - warning: Microphone active but muted
#   - info: Microphone available but not in use
#
# Context:
#   - muted: Input volume is 0
#   - active: Microphone in use
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
    metadata_set "description" "Display microphone activity status"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    if is_macos; then
        require_cmd "osascript" || return 1
    elif is_linux; then
        require_any_cmd "pactl" "amixer" 1  # Optional
    fi
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "show_volume" "bool" "false" "Show input volume level"

    # Icons (Material Design Icons)
    declare_option "icon" "icon" $'\U000F036C' "Microphone on icon"
    declare_option "icon_muted" "icon" $'\U000F036D' "Microphone muted icon"

    # Cache
    declare_option "cache_ttl" "number" "2" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

plugin_get_state() {
    local usage
    usage=$(plugin_data_get "usage")
    [[ "$usage" == "active" ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() {
    local usage mute
    usage=$(plugin_data_get "usage")
    mute=$(plugin_data_get "mute")

    if [[ "$usage" != "active" ]]; then
        printf 'info'
        return
    fi

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
# macOS Detection
# =============================================================================

_get_macos_input_volume() {
    osascript -e "input volume of (get volume settings)" 2>/dev/null
}

_detect_macos_mute() {
    local volume
    volume=$(_get_macos_input_volume)
    [[ "$volume" == "0" ]] && echo "muted" || echo "unmuted"
}

_detect_macos_usage() {
    # On macOS, we can't reliably detect microphone usage without SIP bypass
    # Just check if input is available (volume > 0 or muted)
    local volume
    volume=$(_get_macos_input_volume)
    [[ -n "$volume" ]] && echo "active" || echo "inactive"
}

# =============================================================================
# Linux Detection
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

    # Method 3: Check for common microphone-using processes
    local mic_processes=("zoom" "teams" "discord" "skype" "obs" "audacity" "arecord" "ffmpeg")
    local proc
    for proc in "${mic_processes[@]}"; do
        pgrep -x "$proc" >/dev/null 2>&1 && { echo "active"; return; }
    done

    echo "inactive"
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    local usage mute volume

    if is_macos; then
        volume=$(_get_macos_input_volume)
        mute=$(_detect_macos_mute)
        # macOS: always show if we can read volume (simplified behavior)
        usage="inactive"
        [[ -n "$volume" ]] && usage="active"
    elif is_linux; then
        usage=$(_detect_linux_usage)
        mute=$(_detect_linux_mute)
        volume=""
    else
        return 0
    fi

    plugin_data_set "usage" "$usage"
    plugin_data_set "mute" "$mute"
    plugin_data_set "volume" "${volume:-0}"
}

# =============================================================================
# Plugin Contract: Render (TEXT ONLY)
# =============================================================================

plugin_render() {
    local usage mute volume show_volume
    usage=$(plugin_data_get "usage")
    mute=$(plugin_data_get "mute")
    volume=$(plugin_data_get "volume")
    show_volume=$(get_option "show_volume")

    [[ "$usage" != "active" ]] && return 0

    if [[ "$mute" == "muted" ]]; then
        printf 'MUTED'
    elif [[ "$show_volume" == "true" && -n "$volume" && "$volume" != "0" ]]; then
        printf '%s%%' "$volume"
    else
        printf 'ON'
    fi
}
