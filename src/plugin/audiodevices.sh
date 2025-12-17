#!/usr/bin/env bash
# Plugin: audiodevices - Display current audio input/output devices

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "audiodevices"

# Configuration
_show=$(get_tmux_option "@powerkit_plugin_audiodevices_show" "$POWERKIT_PLUGIN_AUDIODEVICES_SHOW")
_max_len=$(get_tmux_option "@powerkit_plugin_audiodevices_max_length" "$POWERKIT_PLUGIN_AUDIODEVICES_MAX_LENGTH")
_separator=$(get_tmux_option "@powerkit_plugin_audiodevices_separator" "$POWERKIT_PLUGIN_AUDIODEVICES_SEPARATOR")
_input_key=$(get_tmux_option "@powerkit_plugin_audiodevices_input_key" "$POWERKIT_PLUGIN_AUDIODEVICES_INPUT_KEY")
_output_key=$(get_tmux_option "@powerkit_plugin_audiodevices_output_key" "$POWERKIT_PLUGIN_AUDIODEVICES_OUTPUT_KEY")

plugin_get_type() { printf 'static'; }

# Detect audio system
get_audio_system() {
    if is_macos && require_cmd SwitchAudioSource 1; then
        echo "macos"
    elif require_cmd pactl 1; then
        echo "linux"
    else
        echo "none"
    fi
}

get_input() {
    case "$(get_audio_system)" in
        linux)
            local src=$(pactl get-default-source 2>/dev/null)
            [[ -n "$src" ]] && pactl list sources 2>/dev/null | grep -A 20 "Name: $src" | grep "Description:" | cut -d: -f2- | sed 's/^ *//' || echo "No Input"
            ;;
        macos)
            SwitchAudioSource -c -t input 2>/dev/null || echo "No Input"
            ;;
        *) echo "Unsupported" ;;
    esac
}

get_output() {
    case "$(get_audio_system)" in
        linux)
            local sink=$(pactl get-default-sink 2>/dev/null)
            [[ -n "$sink" ]] && pactl list sinks 2>/dev/null | grep -A 20 "Name: $sink" | grep "Description:" | cut -d: -f2- | sed 's/^ *//' || echo "No Output"
            ;;
        macos)
            SwitchAudioSource -c -t output 2>/dev/null || echo "No Output"
            ;;
        *) echo "Unsupported" ;;
    esac
}

truncate() {
    local name="$1" max="$2"
    [[ ${#name} -gt $max ]] && echo "${name:0:$((max-3))}..." || echo "$name"
}

get_cached_device() {
    local type="${1:-}"
    [[ -z "$type" ]] && return
    local key="${CACHE_KEY}_${type}" val
    if val=$(cache_get "$key" "$CACHE_TTL"); then
        echo "$val"
    else
        local r
        [[ "$type" == "input" ]] && r=$(get_input) || r=$(get_output)
        cache_set "$key" "$r"
        echo "$r"
    fi
}

plugin_get_display_info() {
    [[ "$_show" == "off" ]] && echo "0:::" || echo "1:::"
}

setup_keybindings() {
    # Keybindings are always set up, even when show="off"
    # This allows users to use the device selector without displaying in status bar
    local base_dir="${ROOT_DIR%/plugin}"
    local script="${base_dir}/helpers/audio_device_selector.sh"
    [[ -n "$_input_key" ]] && tmux bind-key "$_input_key" run-shell "bash '$script' input"
    [[ -n "$_output_key" ]] && tmux bind-key "$_output_key" run-shell "bash '$script' output"
}

load_plugin() {
    [[ "$_show" == "off" ]] && return
    [[ "$(get_audio_system)" == "none" ]] && return

    local input output parts=()
    case "$_show" in
        input|both)
            input=$(get_cached_device input)
            input=$(truncate "$input" "$_max_len")
            ;;
    esac
    case "$_show" in
        output|both)
            output=$(get_cached_device output)
            output=$(truncate "$output" "$_max_len")
            ;;
    esac
    case "$_show" in
        input) [[ -n "$input" ]] && parts+=("$input") ;;
        output) [[ -n "$output" ]] && parts+=("$output") ;;
        both)
            [[ -n "$input" ]] && parts+=("$input")
            [[ -n "$output" ]] && parts+=("$output")
            ;;
    esac
    if [[ ${#parts[@]} -gt 0 ]]; then
        local IFS="$_separator"
        echo "${parts[*]}"
    fi
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
