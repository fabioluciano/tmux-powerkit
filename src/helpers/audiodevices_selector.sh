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
        has_cmd "SwitchAudioSource" || {
            toast "❌ Install: brew install switchaudio-osx" "error"
            return 0
        }
        audio_system="macos"
        current_input=$(SwitchAudioSource -c -t input 2>/dev/null || echo "")
        while IFS= read -r device; do
            [[ -z "$device" ]] && continue
            local marker=" "
            [[ "$device" == "$current_input" ]] && marker="●"
            menu_items+=("$marker $device")
            device_names+=("$device")
        done < <(SwitchAudioSource -a -t input 2>/dev/null)
    elif has_cmd "pactl"; then
        audio_system="linux"
        current_input=$(pactl get-default-source 2>/dev/null || echo "")
        while IFS=$'\t' read -r index name _; do
            [[ "$name" == *.monitor ]] && continue
            local description
            description=$(pactl list sources | grep -A 30 "Source #$index" | grep -E "(Description|device\.description)" | head -1 | sed -n 's/.*Description: \(.*\)/\1/p; s/.*device\.description = "\([^"]*\)".*/\1/p')
            [[ -z "$description" ]] && description=$(echo "$name" | sed 's/alsa_input\.//; s/\.analog-stereo//; s/_/ /g')
            local marker=" "
            [[ "$name" == "$current_input" ]] && marker="●"
            menu_items+=("$marker $description")
            device_names+=("$name")
        done < <(pactl list short sources 2>/dev/null)
    else
        toast "❌ No supported audio system found" "error"
        return 0
    fi

    [[ ${#menu_items[@]} -eq 0 ]] && {
        toast "❌ No input devices found" "error"
        return 0
    }

    # Device names are passed as argv to a sub-helper instead of being
    # interpolated into a shell command. This prevents any name
    # containing single quotes (or other metacharacters) from breaking
    # out of the quoting and being evaluated by the shell.
    # Names that would still need shell quoting are refused up front.
    local -a safe_names=() safe_descs=()
    local i name clean_desc item
    for i in "${!menu_items[@]}"; do
        name="${device_names[$i]}"
        clean_desc="${menu_items[$i]#* }"
        if [[ "$name" =~ ^[A-Za-z0-9._:/@+=,-]+$ ]] && [[ "$clean_desc" =~ ^[A-Za-z0-9._:/@+=,\ -]+$ ]]; then
            safe_names+=("$name")
            safe_descs+=("$clean_desc")
        fi
    done
    [[ ${#safe_names[@]} -eq 0 ]] && {
        toast "❌ No safe input devices found" "error"
        return 0
    }

    local helper_path="${BASH_SOURCE[0]}"
    local -a menu_args=()
    for i in "${!safe_names[@]}"; do
        item="●"
        [[ "$audio_system" == "macos" ]] && item=""
        [[ "${safe_names[$i]}" == "$current_input" ]] && item="●"
        local desc="${safe_descs[$i]}"
        if [[ "$audio_system" == "linux" ]]; then
            menu_args+=("$item $desc" "" "run-shell \"$helper_path _set source '${safe_names[$i]}'\"")
        else
            menu_args+=("$item $desc" "" "run-shell \"$helper_path _set input '${safe_names[$i]}'\"")
        fi
    done
    tmux display-menu -T "  Select Input Device" -x C -y C "${menu_args[@]}"
}

# Internal action invoked by the menu via run-shell. Receives the device
# name as argv (not via shell interpolation), validates it again, and
# dispatches to the backend.
_pk_set_input() {
    local kind="$1" name="$2"
    # Allow both the macOS SwitchAudioSource form (input|output) and the
    # pactl form (source|sink).
    [[ "$kind" =~ ^(source|input|sink|output)$ ]] || {
        echo "invalid kind" >&2
        return 2
    }
    [[ "$name" =~ ^[A-Za-z0-9._:/@+=,-]+$ ]] || {
        echo "invalid name" >&2
        return 2
    }
    if is_macos; then
        # Map sink→output so the macOS branch stays symmetric with the
        # menu entries produced above.
        local mac_kind="$kind"
        [[ "$mac_kind" == "sink" ]] && mac_kind="output"
        SwitchAudioSource -s "$name" -t "$mac_kind" >/dev/null 2>&1
    else
        # Map input→source so pactl gets the right verb.
        local target="$kind"
        [[ "$target" == "input" ]] && target="source"
        [[ "$target" == "output" ]] && target="sink"
        pactl "set-default-$target" "$name"
    fi
}

# =============================================================================
# Output Device Selection
# =============================================================================

select_output_device() {
    local audio_system="" current_output=""
    local -a menu_items=() device_names=()

    if is_macos; then
        has_cmd "SwitchAudioSource" || {
            toast "❌ Install: brew install switchaudio-osx" "error"
            return 0
        }
        audio_system="macos"
        current_output=$(SwitchAudioSource -c -t output 2>/dev/null || echo "")
        while IFS= read -r device; do
            [[ -z "$device" ]] && continue
            local marker=" "
            [[ "$device" == "$current_output" ]] && marker="●"
            menu_items+=("$marker $device")
            device_names+=("$device")
        done < <(SwitchAudioSource -a -t output 2>/dev/null)
    elif has_cmd "pactl"; then
        audio_system="linux"
        current_output=$(pactl get-default-sink 2>/dev/null || echo "")
        while IFS=$'\t' read -r index name _; do
            local description
            description=$(pactl list sinks | grep -A 30 "Sink #$index" | grep -E "(Description|device\.description)" | head -1 | sed -n 's/.*Description: \(.*\)/\1/p; s/.*device\.description = "\([^"]*\)".*/\1/p')
            [[ -z "$description" ]] && description=$(echo "$name" | sed 's/alsa_output\.//; s/\.analog-stereo//; s/\.hdmi-stereo//; s/_/ /g')
            local marker=" "
            [[ "$name" == "$current_output" ]] && marker="●"
            menu_items+=("$marker $description")
            device_names+=("$name")
        done < <(pactl list short sinks 2>/dev/null)
    else
        toast "❌ No supported audio system found" "error"
        return 0
    fi

    [[ ${#menu_items[@]} -eq 0 ]] && {
        toast "❌ No output devices found" "error"
        return 0
    }

    # Filter to a name allowlist, then pass the name as argv to a
    # sub-helper via run-shell. See select_input_device for rationale.
    local -a safe_names=() safe_descs=()
    local i name clean_desc
    for i in "${!menu_items[@]}"; do
        name="${device_names[$i]}"
        clean_desc="${menu_items[$i]#* }"
        if [[ "$name" =~ ^[A-Za-z0-9._:/@+=,-]+$ ]] && [[ "$clean_desc" =~ ^[A-Za-z0-9._:/@+=,\ -]+$ ]]; then
            safe_names+=("$name")
            safe_descs+=("$clean_desc")
        fi
    done
    [[ ${#safe_names[@]} -eq 0 ]] && {
        toast "❌ No safe output devices found" "error"
        return 0
    }

    local helper_path="${BASH_SOURCE[0]}"
    local -a menu_args=()
    for i in "${!safe_names[@]}"; do
        local item=" "
        [[ "${safe_names[$i]}" == "$current_output" ]] && item="●"
        local desc="${safe_descs[$i]}"
        if [[ "$audio_system" == "linux" ]]; then
            menu_args+=("$item $desc" "" "run-shell \"$helper_path _set sink '${safe_names[$i]}'\"")
        else
            menu_args+=("$item $desc" "" "run-shell \"$helper_path _set output '${safe_names[$i]}'\"")
        fi
    done
    tmux display-menu -T "   Select Output Device" -x C -y C "${menu_args[@]}"
}

# =============================================================================
# Main Entry Point
# =============================================================================

helper_main() {
    local action="${1:-output}"

    case "$action" in
    input | mic | microphone) select_input_device ;;
    output | speaker | speakers | "") select_output_device ;;
    _set)
        shift
        _pk_set_input "$@"
        ;;
    *)
        echo "Unknown action: $action" >&2
        return 1
        ;;
    esac
}

# Dispatch to handler
helper_dispatch "$@"
