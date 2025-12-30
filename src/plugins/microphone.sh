#!/usr/bin/env bash
# =============================================================================
# Plugin: microphone
# Description: Display microphone status - shows only when microphone is active
# Type: conditional (hidden when microphone is inactive)
# Dependencies: powerkit-microphone binary (macOS, bundled), pactl/amixer (Linux)
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
    if is_macos; then
        # macOS: require native binary (downloaded on-demand from releases)
        require_macos_binary "powerkit-microphone" "microphone" || return 1
        return 0
    fi
    if is_linux; then
        require_any_cmd "pactl" "amixer" 1  # Optional
    fi
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "show_volume" "bool" "false" "Show input volume percentage"

    # Icons
    declare_option "icon" "icon" $'\U000F036C' "Microphone icon"
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
    local status
    status=$(plugin_data_get "status")
    [[ "$status" == "active" ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() {
    local status mute
    status=$(plugin_data_get "status")
    mute=$(plugin_data_get "mute")

    # Plugin is hidden when inactive, but return ok for consistency
    [[ "$status" != "active" ]] && { printf 'ok'; return; }
    # Active: muted = warning (needs attention), unmuted = info (in use)
    [[ "$mute" == "muted" ]] && printf 'warning' || printf 'info'
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
# macOS Detection (via powerkit-microphone binary)
# =============================================================================

_detect_macos_status() {
    local powerkit_mic="${POWERKIT_ROOT}/bin/powerkit-microphone"
    [[ ! -x "$powerkit_mic" ]] && return 1

    local output
    output=$("$powerkit_mic" 2>/dev/null) || return 1

    # Output format: status\x1Fmute\x1Fvolume
    local mic_status mute_status volume
    mic_status="${output%%$'\x1F'*}"
    local rest="${output#*$'\x1F'}"
    mute_status="${rest%%$'\x1F'*}"
    volume="${rest#*$'\x1F'}"
    volume="${volume%$'\n'}"

    # Store all values
    plugin_data_set "status" "$mic_status"
    plugin_data_set "mute" "$mute_status"
    plugin_data_set "volume" "${volume:-0}"

    return 0
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

    echo "inactive"
}

_detect_linux_volume() {
    # Get capture volume from pactl
    if has_cmd pactl; then
        local default_source volume_str
        default_source=$(pactl get-default-source 2>/dev/null)
        if [[ -n "$default_source" ]]; then
            volume_str=$(pactl get-source-volume "$default_source" 2>/dev/null | grep -oE '[0-9]+%' | head -1)
            volume_str="${volume_str%\%}"
            [[ -n "$volume_str" ]] && { echo "$volume_str"; return; }
        fi
    fi

    # Fallback: amixer
    if has_cmd amixer; then
        local vol
        vol=$(amixer get Capture 2>/dev/null | grep -oE '[0-9]+%' | head -1)
        vol="${vol%\%}"
        [[ -n "$vol" ]] && { echo "$vol"; return; }
    fi

    echo "0"
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    # macOS: Use native binary
    if is_macos; then
        _detect_macos_status && return 0
        # Fallback if binary fails
        plugin_data_set "status" "inactive"
        plugin_data_set "mute" "unmuted"
        plugin_data_set "volume" "0"
        return 0
    fi

    # Linux: Use pactl/amixer
    local mic_status mute_status volume

    mic_status=$(_detect_linux_usage)
    mute_status=$(_detect_linux_mute)
    volume=$(_detect_linux_volume)

    plugin_data_set "status" "$mic_status"
    plugin_data_set "mute" "$mute_status"
    plugin_data_set "volume" "${volume:-0}"
}

# =============================================================================
# Plugin Contract: Render (TEXT ONLY)
# =============================================================================

plugin_render() {
    local mute volume show_volume
    mute=$(plugin_data_get "mute")
    volume=$(plugin_data_get "volume")
    show_volume=$(get_option "show_volume")

    local text
    [[ "$mute" == "muted" ]] && text="MUTED" || text="ON"

    if [[ "$show_volume" == "true" && -n "$volume" && "$volume" != "0" ]]; then
        printf '%s %s%%' "$text" "$volume"
    else
        printf '%s' "$text"
    fi
}
