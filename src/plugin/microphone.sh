#!/usr/bin/env bash
# =============================================================================
# Plugin: microphone
# Description: Display microphone activity status (active/inactive/muted)
# Type: conditional (hides when inactive)
# Dependencies: pactl or amixer (Linux, optional), osascript (macOS)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    if is_linux; then
        require_any_cmd "pactl" "amixer" 1  # Optional
    fi
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Icons
    declare_option "icon" "icon" $'\ued03' "Plugin icon (microphone on)"
    declare_option "muted_icon" "icon" "" "Icon when muted"

    # Colors - Active state
    declare_option "active_accent_color" "color" "error" "Background color when active"
    declare_option "active_accent_color_icon" "color" "error" "Icon background when active"

    # Colors - Muted state
    declare_option "muted_accent_color" "color" "warning" "Background color when muted"
    declare_option "muted_accent_color_icon" "color" "warning" "Icon background when muted"

    # Cache
    declare_option "cache_ttl" "number" "2" "Cache duration in seconds"
}

plugin_init "microphone"

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local _content="${1:-}"

    _microphone_is_available || { echo "0:::"; return 0; }

    local status_result usage_status mute_status
    status_result=$(_get_cached_or_fetch)
    usage_status="${status_result%:*}"
    mute_status="${status_result#*:}"

    if [[ "$usage_status" == "active" ]]; then
        if [[ "$mute_status" == "muted" ]]; then
            local muted_accent muted_accent_icon muted_icon
            muted_accent=$(get_option "muted_accent_color")
            muted_accent_icon=$(get_option "muted_accent_color_icon")
            muted_icon=$(get_option "muted_icon")
            echo "1:${muted_accent}:${muted_accent_icon}:${muted_icon}"
        else
            local active_accent active_accent_icon icon
            active_accent=$(get_option "active_accent_color")
            active_accent_icon=$(get_option "active_accent_color_icon")
            icon=$(get_option "icon")
            echo "1:${active_accent}:${active_accent_icon}:${icon}"
        fi
    else
        echo "0:::"
    fi
}

# =============================================================================
# Helper Functions
# =============================================================================

_microphone_is_available() {
    is_macos && return 1
    is_linux && { has_cmd pactl || has_cmd amixer; } && return 0
    return 1
}

_toggle_microphone_mute() {
    if ! is_linux; then
        toast "Microphone mute toggle not supported on this platform" "simple"
        return
    fi

    if ! has_cmd pactl; then
        toast "pactl not found - PulseAudio required" "simple"
        return
    fi
    
    local default_source
    default_source=$(pactl get-default-source 2>/dev/null)
    
    if [[ -z "$default_source" ]]; then
        toast "No microphone found" "simple"
        return
    fi
    
    if pactl set-source-mute "$default_source" toggle 2>/dev/null; then
        rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/tmux-powerkit/microphone.cache" 2>/dev/null
        local is_muted="unmuted"
        pactl get-source-mute "$default_source" 2>/dev/null | grep -q "yes" && is_muted="muted"
        toast "🎤 Microphone $is_muted" "simple"
        tmux refresh-client -S 2>/dev/null || true
    else
        toast "Failed to toggle microphone" "simple"
    fi
}

# Keybinding removido: a maioria dos teclados possui tecla dedicada para mute

_detect_microphone_mute_status_linux() {
    if has_cmd pactl; then
        local default_source mute_status
        default_source=$(pactl get-default-source 2>/dev/null)
        [[ -n "$default_source" ]] && {
            mute_status=$(pactl get-source-mute "$default_source" 2>/dev/null | grep -o "yes\|no")
            [[ "$mute_status" == "yes" ]] && { echo "muted"; return; }
        }
    fi

    if has_cmd amixer; then
        amixer get Capture 2>/dev/null | grep -q "\[off\]" && { echo "muted"; return; }
    fi

    echo "unmuted"
}

_detect_microphone_usage_linux() {
    if has_cmd pactl; then
        pactl list short source-outputs 2>/dev/null | grep -q . && { echo "active"; return; }
    fi

    if has_cmd lsof; then
        local active_capture
        active_capture=$(lsof /dev/snd/* 2>/dev/null | grep -E "pcmC[0-9]+D[0-9]+c" | grep -cvE "(pipewire|wireplumb|pulseaudio)")
        [[ "${active_capture:-0}" -gt 0 ]] && { echo "active"; return; }
    fi

    local mic_processes=("zoom" "teams" "discord" "skype" "obs" "audacity" "arecord" "ffmpeg" "vlc")
    for proc in "${mic_processes[@]}"; do
        pgrep -x "$proc" >/dev/null 2>&1 && { echo "active"; return; }
    done

    echo "inactive"
}

_detect_microphone_mute_status() {
    if is_macos; then
        local mute_status
        mute_status=$(osascript -e "input volume of (get volume settings)" 2>/dev/null | grep -o "0\|[1-9][0-9]*")
        [[ "$mute_status" == "0" ]] && echo "muted" || echo "unmuted"
    elif is_linux; then
        _detect_microphone_mute_status_linux
    else
        echo "unmuted"
    fi
}

_detect_microphone_usage() {
    is_macos && { echo "inactive"; return; }
    is_linux && { _detect_microphone_usage_linux; return; }
    echo "inactive"
}

_get_cached_or_fetch() {
    local cached_value
    if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        echo "$cached_value"
    else
        local combined_result
        combined_result="$(_detect_microphone_usage):$(_detect_microphone_mute_status)"
        cache_set "$CACHE_KEY" "$combined_result"
        echo "$combined_result"
    fi
}

# =============================================================================
# Main Logic
# =============================================================================

load_plugin() {
    _microphone_is_available || return 0

    local status_result usage_status mute_status
    status_result=$(_get_cached_or_fetch)
    usage_status="${status_result%:*}"
    mute_status="${status_result#*:}"

    if [[ "$usage_status" == "active" ]]; then
        [[ "$mute_status" == "muted" ]] && printf 'MUTED' || printf 'ON'
    fi
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
