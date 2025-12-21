#!/usr/bin/env bash
# =============================================================================
# Plugin: camera
# Description: Display camera status (active/inactive)
# Type: conditional (hidden when camera is inactive)
# Dependencies: Linux: lsof (optional)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    if is_linux; then
        require_cmd "lsof" 1  # Optional
    fi
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Icons
    declare_option "icon" "icon" $'\U000F0100' "Plugin icon (webcam)"

    # Colors - Default
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Colors - Active state
    declare_option "active_accent_color" "color" "error" "Background color when camera is active"
    declare_option "active_accent_color_icon" "color" "error-strong" "Icon background color when camera is active"

    # Cache
    declare_option "cache_ttl" "number" "2" "Cache duration in seconds"
}

plugin_init "camera"

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local status=$(_get_status)
    if [[ "$status" == "active" ]]; then
        local icon active_accent active_accent_icon
        icon=$(get_option "icon")
        active_accent=$(get_option "active_accent_color")
        active_accent_icon=$(get_option "active_accent_color_icon")
        build_display_info "1" "$active_accent" "$active_accent_icon" "$icon"
    else
        build_display_info "0" "" "" ""
    fi
}

# =============================================================================
# Main Logic
# =============================================================================

_check_cpu() {
    local pid="$1" min="${2:-1}"
    local cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ' | cut -d. -f1)
    [[ -n "$cpu" && "$cpu" -ge "$min" ]]
}

_detect_macos() {
    # Camera daemons on macOS:
    # - VDCAssistant: FaceTime HD camera (older Macs)
    # - appleh16camerad: Apple Silicon built-in camera
    # - cameracaptured: Camera capture daemon
    # - UVCAssistant: USB Video Class cameras (external webcams like Logitech, etc.)
    local procs=("VDCAssistant" "appleh16camerad" "cameracaptured" "UVCAssistant")
    for p in "${procs[@]}"; do
        local pid=$(pgrep -f "$p" 2>/dev/null)
        [[ -n "$pid" ]] && _check_cpu "$pid" 1 && { echo "active"; return; }
    done
    echo "inactive"
}

_detect_linux() {
    # Method 1: lsof (most reliable)
    has_cmd lsof && lsof /dev/video* 2>/dev/null | grep -q "/dev/video" && { printf 'active'; return; }

    # Method 2: fuser (faster than lsof)
    has_cmd fuser && fuser /dev/video* 2>/dev/null | grep -q "[0-9]" && { printf 'active'; return; }

    # Method 3: Check common camera apps with CPU usage
    local apps="gstreamer|ffmpeg|vlc|cheese|obs|zoom|teams|skype"
    local pid
    for pid in $(pgrep -f "$apps" 2>/dev/null); do
        _check_cpu "$pid" 2 && { printf 'active'; return; }
    done

    printf 'inactive'
}

_detect_camera() {
    is_macos && _detect_macos || _detect_linux
}

_get_status() {
    local cached
    if cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        echo "$cached"
    else
        local result=$(_detect_camera)
        cache_set "$CACHE_KEY" "$result"
        echo "$result"
    fi
}

load_plugin() {
    local status=$(_get_status)
    [[ "$status" == "active" ]] && printf 'ON'
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
