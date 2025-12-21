#!/usr/bin/env bash
# =============================================================================
# Plugin: volume
# Description: Display system volume percentage with mute indicator
# Type: static (always visible, informational)
# Dependencies: pactl/amixer/wpctl (Linux - optional), osascript (macOS)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    if is_linux; then
        require_any_cmd "pactl" "amixer" "wpctl" 1  # Optional
    fi
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Icons
    declare_option "icon" "icon" $'\U000F0028' "Plugin icon (high volume)"
    declare_option "icon_low" "icon" "󰕿" "Icon for low volume"
    declare_option "icon_medium" "icon" "󰖀" "Icon for medium volume"
    declare_option "icon_muted" "icon" "󰖁" "Icon for muted state"

    # Colors - Default
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Colors - Muted state
    declare_option "muted_accent_color" "color" "error" "Background color when muted"
    declare_option "muted_accent_color_icon" "color" "error-strong" "Icon background color when muted"

    # Thresholds
    declare_option "low_threshold" "number" "30" "Low volume threshold percentage"
    declare_option "medium_threshold" "number" "70" "Medium volume threshold percentage"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

plugin_init "volume"

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'static'; }

plugin_get_display_info() {
    local content="${1:-}"
    local show="1" accent="" accent_icon="" icon=""

    local value
    value=$(extract_numeric "$content")

    if [[ "$content" == "MUTED" ]] || _volume_is_muted; then
        icon=$(get_option "icon_muted")
        accent=$(get_option "muted_accent_color")
        accent_icon=$(get_option "muted_accent_color_icon")
    elif [[ -n "$value" ]]; then
        local low_threshold medium_threshold
        low_threshold=$(get_option "low_threshold")
        medium_threshold=$(get_option "medium_threshold")

        if [[ "$value" -le "$low_threshold" ]]; then
            icon=$(get_option "icon_low")
        elif [[ "$value" -le "$medium_threshold" ]]; then
            icon=$(get_option "icon_medium")
        else
            icon=$(get_option "icon")
        fi
    fi

    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Helper Functions
# =============================================================================

_get_volume_macos() { osascript -e 'output volume of (get volume settings)' 2>/dev/null; }
_is_muted_macos() { [[ "$(osascript -e 'output muted of (get volume settings)' 2>/dev/null)" == "true" ]]; }

_get_volume_wpctl() {
    local vol
    vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print $2}')
    [[ -n "$vol" ]] && awk "BEGIN {printf \"%.0f\", $vol * 100}"
}
_is_muted_wpctl() { wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q '\[MUTED\]'; }

_get_volume_pactl() { pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oP '\d+%' | head -1 | tr -d '%'; }
_is_muted_pactl() { [[ "$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -oP 'yes|no')" == "yes" ]]; }

_get_volume_pamixer() { pamixer --get-volume 2>/dev/null; }
_is_muted_pamixer() { pamixer --get-mute 2>/dev/null | grep -q "true"; }

_get_volume_amixer() { amixer sget Master 2>/dev/null | grep -oP '\[\d+%\]' | head -1 | tr -d '[]%'; }
_is_muted_amixer() { amixer sget Master 2>/dev/null | grep -q '\[off\]'; }

_volume_get_percentage() {
    local backend percentage=""
    backend=$(detect_audio_backend)

    case "$backend" in
        macos)      percentage=$(_get_volume_macos) ;;
        pipewire)   percentage=$(_get_volume_wpctl) ;;
        pulseaudio) percentage=$(_get_volume_pactl) ;;
        alsa)       percentage=$(_get_volume_amixer) ;;
    esac

    [[ -n "$percentage" && "$percentage" =~ ^[0-9]+$ ]] && printf '%s' "$percentage"
}

_volume_is_muted() {
    local backend
    backend=$(detect_audio_backend)

    case "$backend" in
        macos)      _is_muted_macos ;;
        pipewire)   _is_muted_wpctl ;;
        pulseaudio) _is_muted_pactl ;;
        alsa)       _is_muted_amixer ;;
        *)          return 1 ;;
    esac
}

# =============================================================================
# Main Logic
# =============================================================================

load_plugin() {
    local cached_value
    if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached_value"
        return 0
    fi

    local percentage
    percentage=$(_volume_get_percentage)
    [[ -z "$percentage" ]] && return 0

    local result
    _volume_is_muted && result="MUTED" || result="${percentage}%"

    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
