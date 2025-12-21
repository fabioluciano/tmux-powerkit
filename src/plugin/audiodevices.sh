#!/usr/bin/env bash
# =============================================================================
# Plugin: audiodevices
# Description: Display current audio input/output devices
# Type: conditional (hidden when audio system is not available)
# Dependencies: macOS: SwitchAudioSource (optional), Linux: pactl (optional)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    if is_macos; then
        require_cmd "SwitchAudioSource" 1  # Optional
    else
        require_cmd "pactl" 1  # Optional
    fi
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "show" "string" "both" "Show input/output devices (off|input|output|both)"
    declare_option "max_length" "number" "0" "Maximum device name length"
    declare_option "separator" "string" " | " "Separator between input/output devices"
    declare_option "show_device_icons" "bool" "true" "Show icons next to device names"

    # Icons
    declare_option "icon" "icon" $'\U000F0025' "Plugin icon"
    declare_option "input_icon" "icon" $'\U000F036C' "Icon for input device"
    declare_option "output_icon" "icon" $'\U000F1120' "Icon for output device"

    # Colors
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Keybindings
    declare_option "input_key" "key" "C-i" "Key binding for input device selector"
    declare_option "output_key" "key" "C-o" "Key binding for output device selector"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

plugin_init "audiodevices"

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    if [[ "$(get_option "show")" == "off" ]]; then
        echo "0:::"
        return
    fi

    # Return icon only - let render_plugins.sh use config colors
    # This avoids triggering threshold detection when colors match defaults
    local icon
    icon=$(get_option "icon")

    echo "1:::${icon}"
}

# =============================================================================
# Main Logic
# =============================================================================

# Detect audio system
_get_audio_system() {
    if is_macos && has_cmd SwitchAudioSource; then
        echo "macos"
    elif has_cmd pactl; then
        echo "linux"
    else
        echo "none"
    fi
}

_get_input() {
    case "$(_get_audio_system)" in
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

_get_output() {
    case "$(_get_audio_system)" in
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

_get_cached_device() {
    local type="${1:-}"
    [[ -z "$type" ]] && return
    local key="${CACHE_KEY}_${type}" result
    if result=$(cache_get "$key" "$CACHE_TTL"); then
        echo "$result"
    else
        local device_name
        [[ "$type" == "input" ]] && device_name=$(_get_input) || device_name=$(_get_output)
        cache_set "$key" "$device_name"
        echo "$device_name"
    fi
}

setup_keybindings() {
    # Keybindings are always set up, even when show="off"
    # This allows users to use the device selector without displaying in status bar
    local base_dir="${ROOT_DIR%/plugin}"
    local script="${base_dir}/helpers/audio_device_selector.sh"
    local input_key output_key
    input_key=$(get_option "input_key")
    output_key=$(get_option "output_key")
    [[ -n "$input_key" ]] && tmux bind-key "$input_key" run-shell "bash '$script' input"
    [[ -n "$output_key" ]] && tmux bind-key "$output_key" run-shell "bash '$script' output"
}

load_plugin() {
    local show max_len show_icons
    show=$(get_option "show")
    max_len=$(get_option "max_length")
    show_icons=$(get_option "show_device_icons")

    [[ "$show" == "off" ]] && return
    [[ "$(_get_audio_system)" == "none" ]] && return

    local input output parts=()
    local input_icon_char output_icon_char
    if [[ "$show_icons" == "true" ]]; then
        input_icon_char=$(get_option "input_icon")
        output_icon_char=$(get_option "output_icon")
    fi

    case "$show" in
        input|both)
            input=$(_get_cached_device input)
            input=$(truncate_text "$input" "$max_len")
            [[ "$show_icons" == "true" && -n "$input" ]] && input="${input_icon_char} ${input}"
            ;;
    esac
    case "$show" in
        output|both)
            output=$(_get_cached_device output)
            output=$(truncate_text "$output" "$max_len")
            [[ "$show_icons" == "true" && -n "$output" ]] && output="${output_icon_char} ${output}"
            ;;
    esac
    case "$show" in
        input) [[ -n "$input" ]] && parts+=("$input") ;;
        output) [[ -n "$output" ]] && parts+=("$output") ;;
        both)
            [[ -n "$input" ]] && parts+=("$input")
            [[ -n "$output" ]] && parts+=("$output")
            ;;
    esac
    if [[ ${#parts[@]} -gt 0 ]]; then
        local sep
        sep=$(get_option "separator")
        join_with_separator "$sep" "${parts[@]}"
    fi
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
