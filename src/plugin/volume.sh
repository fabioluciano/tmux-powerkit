#!/usr/bin/env bash
# Plugin: volume - Display system volume percentage with mute indicator

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "volume"

plugin_get_type() { printf 'static'; }

get_volume_macos() { osascript -e 'output volume of (get volume settings)' 2>/dev/null; }
is_muted_macos() { [[ "$(osascript -e 'output muted of (get volume settings)' 2>/dev/null)" == "true" ]]; }

get_volume_wpctl() {
    local vol
    vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print $2}')
    [[ -n "$vol" ]] && awk "BEGIN {printf \"%.0f\", $vol * 100}"
}
is_muted_wpctl() { wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q '\[MUTED\]'; }

get_volume_pactl() { pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oP '\d+%' | head -1 | tr -d '%'; }
is_muted_pactl() { [[ "$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -oP 'yes|no')" == "yes" ]]; }

get_volume_pamixer() { pamixer --get-volume 2>/dev/null; }
is_muted_pamixer() { pamixer --get-mute 2>/dev/null | grep -q "true"; }

get_volume_amixer() { amixer sget Master 2>/dev/null | grep -oP '\[\d+%\]' | head -1 | tr -d '[]%'; }
is_muted_amixer() { amixer sget Master 2>/dev/null | grep -q '\[off\]'; }

volume_get_percentage() {
    local backend percentage=""
    backend=$(detect_audio_backend)

    case "$backend" in
        macos)      percentage=$(get_volume_macos) ;;
        pipewire)   percentage=$(get_volume_wpctl) ;;
        pulseaudio) percentage=$(get_volume_pactl) ;;
        alsa)       percentage=$(get_volume_amixer) ;;
    esac

    [[ -n "$percentage" && "$percentage" =~ ^[0-9]+$ ]] && printf '%s' "$percentage"
}

volume_is_muted() {
    local backend
    backend=$(detect_audio_backend)

    case "$backend" in
        macos)      is_muted_macos ;;
        pipewire)   is_muted_wpctl ;;
        pulseaudio) is_muted_pactl ;;
        alsa)       is_muted_amixer ;;
        *)          return 1 ;;
    esac
}

plugin_get_display_info() {
    local content="${1:-}"
    local show="1" accent="" accent_icon="" icon=""
    
    local value
    value=$(extract_numeric "$content")
    
    if [[ "$content" == "MUTED" ]] || volume_is_muted; then
        icon=$(get_cached_option "@powerkit_plugin_volume_icon_muted" "${POWERKIT_PLUGIN_VOLUME_ICON_MUTED:-󰖁}")
        accent=$(get_cached_option "@powerkit_plugin_volume_muted_accent_color" "${POWERKIT_PLUGIN_VOLUME_MUTED_ACCENT_COLOR:-red}")
        accent_icon=$(get_cached_option "@powerkit_plugin_volume_muted_accent_color_icon" "${POWERKIT_PLUGIN_VOLUME_MUTED_ACCENT_COLOR_ICON:-red1}")
    elif [[ -n "$value" ]]; then
        local low_threshold medium_threshold
        low_threshold=$(get_cached_option "@powerkit_plugin_volume_low_threshold" "${POWERKIT_PLUGIN_VOLUME_LOW_THRESHOLD:-30}")
        medium_threshold=$(get_cached_option "@powerkit_plugin_volume_medium_threshold" "${POWERKIT_PLUGIN_VOLUME_MEDIUM_THRESHOLD:-70}")
        
        if [[ "$value" -le "$low_threshold" ]]; then
            icon=$(get_cached_option "@powerkit_plugin_volume_icon_low" "${POWERKIT_PLUGIN_VOLUME_ICON_LOW:-󰕿}")
        elif [[ "$value" -le "$medium_threshold" ]]; then
            icon=$(get_cached_option "@powerkit_plugin_volume_icon_medium" "${POWERKIT_PLUGIN_VOLUME_ICON_MEDIUM:-󰖀}")
        else
            icon=$(get_cached_option "@powerkit_plugin_volume_icon" "${POWERKIT_PLUGIN_VOLUME_ICON:-󰕾}")
        fi
    fi
    
    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

load_plugin() {
    local cached_value
    if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached_value"
        return 0
    fi

    local percentage
    percentage=$(volume_get_percentage)
    [[ -z "$percentage" ]] && return 0

    local result
    volume_is_muted && result="MUTED" || result="${percentage}%"

    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
