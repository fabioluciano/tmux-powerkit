#!/usr/bin/env bash
# =============================================================================
# Plugin: camera
# Description: Display camera status - shows only when camera is active
# Type: conditional (hidden when camera is inactive)
# Dependencies: macOS: built-in, Linux: lsof/fuser (optional)
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active: Camera is in use
#   - inactive: Camera is not in use (plugin hidden)
#
# Health:
#   - info: Camera is active (visual indicator)
#
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "camera"
    metadata_set "name" "Camera"
    metadata_set "version" "2.1.0"
    metadata_set "description" "Display camera status"
    metadata_set "priority" "125"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    if is_linux; then
        require_cmd "lsof" 1  # Optional
    fi
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    declare_option "icon" "icon" $'\U000F0100' "Camera icon"
    declare_option "cache_ttl" "number" "2" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

plugin_get_state() {
    local status
    status=$(plugin_data_get "status")
    [[ "$status" == "active" ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() { printf 'info'; }
plugin_get_context() { printf ''; }
plugin_get_icon() { get_option "icon"; }

# =============================================================================
# Detection Logic
# =============================================================================

_detect_macos() {
    # Camera daemons on macOS
    local procs=("VDCAssistant" "appleh16camerad" "cameracaptured" "UVCAssistant")
    local p pid cpu

    for p in "${procs[@]}"; do
        pid=$(pgrep -f "$p" 2>/dev/null | head -1)
        if [[ -n "$pid" ]]; then
            cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ' | cut -d. -f1)
            [[ -n "$cpu" && "$cpu" -ge 1 ]] && return 0
        fi
    done
    return 1
}

_detect_linux() {
    # Method 1: lsof
    has_cmd lsof && lsof /dev/video* 2>/dev/null | grep -q "/dev/video" && return 0
    # Method 2: fuser
    has_cmd fuser && fuser /dev/video* 2>/dev/null | grep -q "[0-9]" && return 0
    return 1
}

_is_camera_active() {
    is_macos && _detect_macos || _detect_linux
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    if _is_camera_active; then
        plugin_data_set "status" "active"
    else
        plugin_data_set "status" "inactive"
    fi
}

# =============================================================================
# Plugin Contract: Render (TEXT ONLY)
# =============================================================================

plugin_render() {
    printf 'ON'
}
