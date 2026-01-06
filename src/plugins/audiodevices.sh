#!/usr/bin/env bash
# =============================================================================
# Plugin: audiodevices
# Description: Display current audio input/output devices
# Dependencies: macOS: SwitchAudioSource, Linux: pactl
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "audiodevices"
    metadata_set "name" "Audio Devices"
    metadata_set "description" "Display current audio input/output devices"
}

# =============================================================================
# Plugin Contract: Dependencies
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
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "display_mode" "string" "both" "Display mode: off|input|output|both"
    declare_option "max_length" "number" "20" "Maximum device name length"
    declare_option "truncate_suffix" "string" "..." "Truncation suffix"
    declare_option "separator" "string" " | " "Separator between input/output"
    declare_option "show_device_icons" "bool" "true" "Show input/output icons"

    # Icons
    declare_option "icon" "icon" $'\U000F0025' "Plugin icon"
    declare_option "input_icon" "icon" $'\U000F036C' "Input device icon"
    declare_option "output_icon" "icon" $'\U000F1120' "Output device icon"

    # Keybindings (using M- to avoid conflict with C-i/TPM and C-o/rotate-window)
    declare_option "keybinding_input" "key" "M-i" "Keybinding for input device selector"
    declare_option "keybinding_output" "key" "M-o" "Keybinding for output device selector"

    # Cache
    declare_option "cache_ttl" "number" "10" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }

plugin_get_presence() { printf 'conditional'; }

plugin_get_state() {
    local show
    show=$(get_option "display_mode")
    [[ "$show" == "off" ]] && { printf 'inactive'; return; }
    [[ "$(_get_audio_system)" == "none" ]] && { printf 'inactive'; return; }
    printf 'active'
}
plugin_get_health() { printf 'ok'; }

plugin_get_context() {
    local mode=$(get_option "display_mode")
    case "$mode" in
        input)  printf 'input_only' ;;
        output) printf 'output_only' ;;
        both)   printf 'both_devices' ;;
        *)      printf 'disabled' ;;
    esac
}

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# Main Logic
# =============================================================================

# Detect available audio system
_get_audio_system() {
    if is_macos && has_cmd SwitchAudioSource; then
        printf 'macos'
    elif has_cmd pactl; then
        printf 'linux'
    else
        printf 'none'
    fi
}

_get_audio_input() {
    if is_macos; then
        SwitchAudioSource -c -t input 2>/dev/null
    else
        local src
        src=$(pactl get-default-source 2>/dev/null)
        [[ -n "$src" ]] && pactl list sources 2>/dev/null | \
            grep -A 20 "Name: $src" | grep "Description:" | \
            cut -d: -f2- | sed 's/^ *//'
    fi
}

_get_audio_output() {
    if is_macos; then
        SwitchAudioSource -c -t output 2>/dev/null
    else
        local sink
        sink=$(pactl get-default-sink 2>/dev/null)
        [[ -n "$sink" ]] && pactl list sinks 2>/dev/null | \
            grep -A 20 "Name: $sink" | grep "Description:" | \
            cut -d: -f2- | sed 's/^ *//'
    fi
}

plugin_collect() {
    local show input output
    show=$(get_option "display_mode")

    # Skip if audio system not available
    [[ "$show" == "off" ]] && return 0
    [[ "$(_get_audio_system)" == "none" ]] && return 0

    case "$show" in
        input|both)
            input=$(_get_audio_input)
            plugin_data_set "input" "${input:-Unknown}"
            ;;
    esac

    case "$show" in
        output|both)
            output=$(_get_audio_output)
            plugin_data_set "output" "${output:-Unknown}"
            ;;
    esac
}

plugin_render() {
    local show max_len suffix separator show_icons
    local input_icon output_icon
    local parts=()

    show=$(get_option "display_mode")
    max_len=$(get_option "max_length")
    suffix=$(get_option "truncate_suffix")
    separator=$(get_option "separator")
    show_icons=$(get_option "show_device_icons")
    input_icon=$(get_option "input_icon")
    output_icon=$(get_option "output_icon")

    # Build input part
    if [[ "$show" == "input" || "$show" == "both" ]]; then
        local input
        input=$(plugin_data_get "input")
        [[ "$max_len" -gt 0 ]] && input=$(truncate_words "$input" "$max_len" "$suffix")
        [[ "$show_icons" == "true" ]] && input="${input_icon} ${input}"
        parts+=("$input")
    fi

    # Build output part
    if [[ "$show" == "output" || "$show" == "both" ]]; then
        local output
        output=$(plugin_data_get "output")
        [[ "$max_len" -gt 0 ]] && output=$(truncate_words "$output" "$max_len" "$suffix")
        [[ "$show_icons" == "true" ]] && output="${output_icon} ${output}"
        parts+=("$output")
    fi

    # Use utility function for joining (DRY)
    [[ ${#parts[@]} -gt 0 ]] && join_with_separator "$separator" "${parts[@]}"
}

# =============================================================================
# Keybindings
# =============================================================================

plugin_setup_keybindings() {
    local input_key output_key helper_script
    input_key=$(get_option "keybinding_input")
    output_key=$(get_option "keybinding_output")
    helper_script="${POWERKIT_ROOT}/src/helpers/audiodevices_selector.sh"

    # audio_device_selector uses display-menu (not popup)
    pk_bind_shell "$input_key" "bash '$helper_script' input" "audiodevices:input"
    pk_bind_shell "$output_key" "bash '$helper_script' output" "audiodevices:output"
}

