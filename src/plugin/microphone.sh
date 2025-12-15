#!/usr/bin/env bash
# Plugin: microphone - Display microphone activity status (active/inactive)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "microphone"

plugin_get_type() { printf 'conditional'; }

microphone_is_available() {
    is_macos && return 1
    is_linux && { command -v pactl >/dev/null 2>&1 || command -v amixer >/dev/null 2>&1; } && return 0
    return 1
}

toggle_microphone_mute() {
    if ! is_linux; then
        toast "Microphone mute toggle not supported on this platform" "simple"
        return
    fi
    
    if ! command -v pactl >/dev/null 2>&1; then
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

detect_microphone_mute_status_linux() {
    if command -v pactl >/dev/null 2>&1; then
        local default_source mute_status
        default_source=$(pactl get-default-source 2>/dev/null)
        [[ -n "$default_source" ]] && {
            mute_status=$(pactl get-source-mute "$default_source" 2>/dev/null | grep -o "yes\|no")
            [[ "$mute_status" == "yes" ]] && { echo "muted"; return; }
        }
    fi
    
    if command -v amixer >/dev/null 2>&1; then
        amixer get Capture 2>/dev/null | grep -q "\[off\]" && { echo "muted"; return; }
    fi
    
    echo "unmuted"
}

detect_microphone_usage_linux() {
    if command -v pactl >/dev/null 2>&1; then
        pactl list short source-outputs 2>/dev/null | grep -q . && { echo "active"; return; }
    fi
    
    if command -v lsof >/dev/null 2>&1; then
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

detect_microphone_mute_status() {
    if is_macos; then
        local mute_status
        mute_status=$(osascript -e "input volume of (get volume settings)" 2>/dev/null | grep -o "0\|[1-9][0-9]*")
        [[ "$mute_status" == "0" ]] && echo "muted" || echo "unmuted"
    elif is_linux; then
        detect_microphone_mute_status_linux
    else
        echo "unmuted"
    fi
}

detect_microphone_usage() {
    is_macos && { echo "inactive"; return; }
    is_linux && { detect_microphone_usage_linux; return; }
    echo "inactive"
}

get_cached_or_fetch() {
    local cached_value
    if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        echo "$cached_value"
    else
        local combined_result
        combined_result="$(detect_microphone_usage):$(detect_microphone_mute_status)"
        cache_set "$CACHE_KEY" "$combined_result"
        echo "$combined_result"
    fi
}

plugin_get_display_info() {
    local _content="${1:-}"
    
    microphone_is_available || { echo "0:::"; return 0; }
    
    local status_result usage_status mute_status
    status_result=$(get_cached_or_fetch)
    usage_status="${status_result%:*}"
    mute_status="${status_result#*:}"
    
    if [[ "$usage_status" == "active" ]]; then
        if [[ "$mute_status" == "muted" ]]; then
            echo "1:$POWERKIT_PLUGIN_MICROPHONE_MUTED_ACCENT_COLOR:$POWERKIT_PLUGIN_MICROPHONE_MUTED_ACCENT_COLOR_ICON:$POWERKIT_PLUGIN_MICROPHONE_MUTED_ICON"
        else
            echo "1:$POWERKIT_PLUGIN_MICROPHONE_ACTIVE_ACCENT_COLOR:$POWERKIT_PLUGIN_MICROPHONE_ACTIVE_ACCENT_COLOR_ICON:$POWERKIT_PLUGIN_MICROPHONE_ICON"
        fi
    else
        echo "0:::"
    fi
}

load_plugin() {
    microphone_is_available || return 0
    
    local status_result usage_status mute_status
    status_result=$(get_cached_or_fetch)
    usage_status="${status_result%:*}"
    mute_status="${status_result#*:}"
    
    if [[ "$usage_status" == "active" ]]; then
        [[ "$mute_status" == "muted" ]] && printf 'MUTED' || printf 'ON'
    fi
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
