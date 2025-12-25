#!/usr/bin/env bash
# =============================================================================
# Plugin: volume
# Description: Display system volume percentage with mute indicator
# Dependencies: pactl/amixer/wpctl (Linux - optional), osascript (macOS)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "volume"
    metadata_set "name" "Volume"
    metadata_set "description" "Display system volume percentage with mute indicator"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    if is_linux; then
        # Any audio backend is optional on Linux
        require_any_cmd "wpctl" "pactl" "pamixer" "amixer" 1
    fi
    # macOS always has osascript
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "show_percentage" "bool" "true" "Show percentage symbol"

    # Icons (Material Design Icons - nf-md-volume_*)
    declare_option "icon" "icon" $'\U000F057E' "Volume high icon"
    declare_option "icon_medium" "icon" $'\U000F0580' "Volume medium icon"
    declare_option "icon_low" "icon" $'\U000F057F' "Volume low icon"
    declare_option "icon_muted" "icon" $'\U000F0581' "Volume muted icon"

    # Thresholds for icon selection
    declare_option "low_threshold" "number" "30" "Low volume threshold percentage"
    declare_option "medium_threshold" "number" "70" "Medium volume threshold percentage"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'always'; }
plugin_get_state() { printf 'active'; }
plugin_get_health() {
    local muted
    muted=$(plugin_data_get "muted")
    [[ "$muted" == "1" ]] && printf 'error' || printf 'ok'
}

plugin_get_context() {
    local muted volume low_th med_th
    muted=$(plugin_data_get "muted")
    volume=$(plugin_data_get "volume")
    low_th=$(get_option "low_threshold")
    med_th=$(get_option "medium_threshold")

    volume="${volume:-0}"
    low_th="${low_th:-30}"
    med_th="${med_th:-70}"

    if [[ "$muted" == "1" ]]; then
        printf 'muted'
    elif (( volume <= low_th )); then
        printf 'low'
    elif (( volume <= med_th )); then
        printf 'medium'
    else
        printf 'high'
    fi
}

plugin_get_icon() {
    local volume muted low_th med_th
    volume=$(plugin_data_get "volume")
    muted=$(plugin_data_get "muted")
    low_th=$(get_option "low_threshold")
    med_th=$(get_option "medium_threshold")

    volume="${volume:-0}"
    low_th="${low_th:-30}"
    med_th="${med_th:-70}"

    if [[ "$muted" == "1" || "$volume" -eq 0 ]]; then
        get_option "icon_muted"
    elif (( volume <= low_th )); then
        get_option "icon_low"
    elif (( volume <= med_th )); then
        get_option "icon_medium"
    else
        get_option "icon"
    fi
}

# =============================================================================
# Audio Backend Detection
# =============================================================================

_detect_audio_backend() {
    if is_macos; then
        printf 'macos'
    elif has_cmd "wpctl"; then
        printf 'pipewire'
    elif has_cmd "pactl"; then
        printf 'pulseaudio'
    elif has_cmd "pamixer"; then
        printf 'pamixer'
    elif has_cmd "amixer"; then
        printf 'alsa'
    else
        printf 'none'
    fi
}

# =============================================================================
# macOS Backend
# =============================================================================

_get_volume_macos() {
    osascript -e 'output volume of (get volume settings)' 2>/dev/null
}

_is_muted_macos() {
    [[ "$(osascript -e 'output muted of (get volume settings)' 2>/dev/null)" == "true" ]]
}

# =============================================================================
# PipeWire/WirePlumber Backend (wpctl)
# =============================================================================

_get_volume_wpctl() {
    local vol
    vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print $2}')
    [[ -n "$vol" ]] && awk "BEGIN {printf \"%.0f\", $vol * 100}"
}

_is_muted_wpctl() {
    wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q '\[MUTED\]'
}

# =============================================================================
# PulseAudio Backend (pactl)
# =============================================================================

_get_volume_pactl() {
    pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oP '\d+%' | head -1 | tr -d '%'
}

_is_muted_pactl() {
    [[ "$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -oP 'yes|no')" == "yes" ]]
}

# =============================================================================
# pamixer Backend
# =============================================================================

_get_volume_pamixer() {
    pamixer --get-volume 2>/dev/null
}

_is_muted_pamixer() {
    pamixer --get-mute 2>/dev/null | grep -q "true"
}

# =============================================================================
# ALSA Backend (amixer)
# =============================================================================

_get_volume_amixer() {
    amixer sget Master 2>/dev/null | grep -oP '\[\d+%\]' | head -1 | tr -d '[]%'
}

_is_muted_amixer() {
    amixer sget Master 2>/dev/null | grep -q '\[off\]'
}

# =============================================================================
# Backend Dispatcher
# =============================================================================

_volume_get_percentage() {
    local backend percentage=""
    backend=$(_detect_audio_backend)

    case "$backend" in
        macos)      percentage=$(_get_volume_macos) ;;
        pipewire)   percentage=$(_get_volume_wpctl) ;;
        pulseaudio) percentage=$(_get_volume_pactl) ;;
        pamixer)    percentage=$(_get_volume_pamixer) ;;
        alsa)       percentage=$(_get_volume_amixer) ;;
    esac

    [[ -n "$percentage" && "$percentage" =~ ^[0-9]+$ ]] && printf '%s' "$percentage"
}

_volume_is_muted() {
    local backend
    backend=$(_detect_audio_backend)

    case "$backend" in
        macos)      _is_muted_macos ;;
        pipewire)   _is_muted_wpctl ;;
        pulseaudio) _is_muted_pactl ;;
        pamixer)    _is_muted_pamixer ;;
        alsa)       _is_muted_amixer ;;
        *)          return 1 ;;
    esac
}

# =============================================================================
# Main Logic
# =============================================================================

plugin_collect() {
    local volume muted=0

    volume=$(_volume_get_percentage)
    _volume_is_muted && muted=1

    plugin_data_set "volume" "${volume:-0}"
    plugin_data_set "muted" "$muted"
}

plugin_render() {
    local volume muted show_pct
    volume=$(plugin_data_get "volume")
    muted=$(plugin_data_get "muted")
    show_pct=$(get_option "show_percentage")

    if [[ "$muted" == "1" ]]; then
        printf 'MUTE'
    else
        [[ "$show_pct" == "true" ]] && printf '%s%%' "$volume" || printf '%s' "$volume"
    fi
}

