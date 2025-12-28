#!/usr/bin/env bash
# =============================================================================
# Helper: audiodevices_selector
# Description: Cross-platform audio device selector (PulseAudio/PipeWire/macOS)
# Type: menu
# =============================================================================

# Source helper contract (handles all initialization)
# Using minimal bootstrap for faster startup
. "$(dirname "${BASH_SOURCE[0]}")/../contract/helper_contract.sh"
helper_init

# =============================================================================
# Metadata
# =============================================================================

helper_get_metadata() {
    helper_metadata_set "id" "audiodevices_selector"
    helper_metadata_set "name" "Audio Device Selector"
    helper_metadata_set "description" "Select audio input/output devices"
    helper_metadata_set "type" "menu"
}

helper_get_actions() {
    echo "input - Select input device (microphone)"
    echo "output - Select output device (speakers)"
}

# =============================================================================
# Input Device Selection
# =============================================================================

select_input_device() {
    local audio_system="" current_input=""
    local -a menu_items=() device_names=()

    if is_macos; then
        has_cmd "SwitchAudioSource" || { toast "❌ Install: brew install switchaudio-osx" "error"; return 0; }
        audio_system="macos"
        current_input=$(SwitchAudioSource -c -t input 2>/dev/null || echo "")
        while IFS= read -r device; do
            [[ -z "$device" ]] && continue
            local marker=" "; [[ "$device" == "$current_input" ]] && marker="●"
            menu_items+=("$marker $device"); device_names+=("$device")
        done < <(SwitchAudioSource -a -t input 2>/dev/null)
    elif has_cmd "pactl"; then
        audio_system="linux"
        current_input=$(pactl get-default-source 2>/dev/null || echo "")
        while IFS=$'\t' read -r index name _; do
            [[ "$name" == *.monitor ]] && continue
            local description
            description=$(pactl list sources | grep -A 30 "Source #$index" | grep -E "(Description|device\.description)" | head -1 | sed -n 's/.*Description: \(.*\)/\1/p; s/.*device\.description = "\([^"]*\)".*/\1/p')
            [[ -z "$description" ]] && description=$(echo "$name" | sed 's/alsa_input\.//; s/\.analog-stereo//; s/_/ /g')
            local marker=" "; [[ "$name" == "$current_input" ]] && marker="●"
            menu_items+=("$marker $description"); device_names+=("$name")
        done < <(pactl list short sources 2>/dev/null)
    else
        toast "❌ No supported audio system found" "error"; return 0
    fi

    [[ ${#menu_items[@]} -eq 0 ]] && { toast "❌ No input devices found" "error"; return 0; }

    local -a menu_args=()
    for i in "${!menu_items[@]}"; do
        local item="${menu_items[$i]}" name="${device_names[$i]}" clean_desc="${menu_items[$i]#* }"
        [[ "$audio_system" == "linux" ]] && menu_args+=("$item" "" "run-shell \"pactl set-default-source '$name' && tmux display-message '  Input: $clean_desc'\"") || \
            menu_args+=("$item" "" "run-shell \"SwitchAudioSource -s '$name' -t input >/dev/null 2>&1 && tmux display-message '  Input: $clean_desc'\"")
    done
    tmux display-menu -T "  Select Input Device" -x C -y C "${menu_args[@]}"
}

# =============================================================================
# Output Device Selection
# =============================================================================

select_output_device() {
    local audio_system="" current_output=""
    local -a menu_items=() device_names=()

    if is_macos; then
        has_cmd "SwitchAudioSource" || { toast "❌ Install: brew install switchaudio-osx" "error"; return 0; }
        audio_system="macos"
        current_output=$(SwitchAudioSource -c -t output 2>/dev/null || echo "")
        while IFS= read -r device; do
            [[ -z "$device" ]] && continue
            local marker=" "; [[ "$device" == "$current_output" ]] && marker="●"
            menu_items+=("$marker $device"); device_names+=("$device")
        done < <(SwitchAudioSource -a -t output 2>/dev/null)
    elif has_cmd "pactl"; then
        audio_system="linux"
        current_output=$(pactl get-default-sink 2>/dev/null || echo "")
        while IFS=$'\t' read -r index name _; do
            local description
            description=$(pactl list sinks | grep -A 30 "Sink #$index" | grep -E "(Description|device\.description)" | head -1 | sed -n 's/.*Description: \(.*\)/\1/p; s/.*device\.description = "\([^"]*\)".*/\1/p')
            [[ -z "$description" ]] && description=$(echo "$name" | sed 's/alsa_output\.//; s/\.analog-stereo//; s/\.hdmi-stereo//; s/_/ /g')
            local marker=" "; [[ "$name" == "$current_output" ]] && marker="●"
            menu_items+=("$marker $description"); device_names+=("$name")
        done < <(pactl list short sinks 2>/dev/null)
    else
        toast "❌ No supported audio system found" "error"; return 0
    fi

    [[ ${#menu_items[@]} -eq 0 ]] && { toast "❌ No output devices found" "error"; return 0; }

    local -a menu_args=()
    for i in "${!menu_items[@]}"; do
        local item="${menu_items[$i]}" name="${device_names[$i]}" clean_desc="${menu_items[$i]#* }"
        [[ "$audio_system" == "linux" ]] && menu_args+=("$item" "" "run-shell \"pactl set-default-sink '$name' && tmux display-message '   Output: $clean_desc'\"") || \
            menu_args+=("$item" "" "run-shell \"SwitchAudioSource -s '$name' -t output >/dev/null 2>&1 && tmux display-message '   Output: $clean_desc'\"")
    done
    tmux display-menu -T "   Select Output Device" -x C -y C "${menu_args[@]}"
}

# =============================================================================
# Main Entry Point
# =============================================================================

helper_main() {
    local action="${1:-output}"

    case "$action" in
        input|mic|microphone)    select_input_device ;;
        output|speaker|speakers|"") select_output_device ;;
        *)
            echo "Unknown action: $action" >&2
            return 1
            ;;
    esac
}

# Dispatch to handler
helper_dispatch "$@"
