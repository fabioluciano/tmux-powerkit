#!/usr/bin/env bash
# =============================================================================
# Plugin: brightness
# Description: Display screen brightness level
# Type: conditional (hidden based on display conditions)
# Dependencies:
#   macOS: Native helper (powerkit-brightness) using DisplayServices API
#          Fallback: ioreg (may have stale values on Apple Silicon)
#   Linux: sysfs/brightnessctl/light/xbacklight (optional)
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active: Brightness value available
#   - inactive: No brightness control detected
#
# Health:
#   - ok: Normal brightness level
#
# Context:
#   - low, medium, high based on brightness level
#
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "brightness"
    metadata_set "name" "Brightness"
    metadata_set "description" "Display screen brightness level"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    if is_macos; then
        # macOS: require native binary (downloaded on-demand from releases)
        # Falls back to ioreg if binary not available, so don't fail here
        require_macos_binary "powerkit-brightness" "brightness" || true
        return 0
    else
        # Linux - any of these work
        has_cmd "brightnessctl" || has_cmd "light" || has_cmd "xbacklight" || [[ -d "/sys/class/backlight" ]] || return 1
    fi
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Monitor selection
    declare_option "display" "string" "builtin" "Display: builtin, external, all, or display ID"
    declare_option "separator" "string" " | " "Separator when showing multiple displays"

    # Display options
    declare_option "show_percentage" "bool" "true" "Show percentage symbol"

    # Icons (Material Design Icons - brightness)
    declare_option "icon" "icon" $'\U000F00E0' "Plugin icon (brightness-7, high)"
    declare_option "icon_medium" "icon" $'\U000F00DF' "Icon when brightness is medium (30-70%)"
    declare_option "icon_low" "icon" $'\U000F00DE' "Icon when brightness is low (<30%)"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

plugin_get_state() {
    local level=$(plugin_data_get "level")
    [[ -n "$level" ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() { printf 'ok'; }

plugin_get_context() {
    local level=$(plugin_data_get "level")
    level="${level:-50}"

    if (( level <= 30 )); then
        printf 'low'
    elif (( level <= 70 )); then
        printf 'medium'
    else
        printf 'high'
    fi
}

plugin_get_icon() {
    local level=$(plugin_data_get "level")
    level="${level:-50}"

    if (( level <= 30 )); then
        get_option "icon_low"
    elif (( level <= 70 )); then
        get_option "icon_medium"
    else
        get_option "icon"
    fi
}

# =============================================================================
# macOS: ioreg Support (fallback)
# =============================================================================

_get_brightness_ioreg() {
    local ioreg_output value max brightness_info

    # Try AppleARMBacklight first (Apple Silicon)
    ioreg_output=$(ioreg -c AppleARMBacklight -r 2>/dev/null)
    [[ -z "$ioreg_output" ]] && ioreg_output=$(ioreg -r -k IODisplayParameters 2>/dev/null)
    [[ -z "$ioreg_output" ]] && return 1

    # Use "brightness" key first (visual brightness, 0-65536 scale)
    brightness_info=$(echo "$ioreg_output" | grep -o '"brightness"={[^}]*}' | head -1)
    if [[ -n "$brightness_info" ]]; then
        value=$(echo "$brightness_info" | grep -o '"value"=[0-9]*' | cut -d= -f2)
        max=$(echo "$brightness_info" | grep -o '"max"=[0-9]*' | cut -d= -f2)
        if [[ -n "$value" && -n "$max" && "$max" -gt 0 ]]; then
            calc_percent "$value" "$max"
            return 0
        fi
    fi

    # Fallback to rawBrightness (hardware level)
    brightness_info=$(echo "$ioreg_output" | grep -o '"rawBrightness"={[^}]*}' | head -1)
    if [[ -n "$brightness_info" ]]; then
        value=$(echo "$brightness_info" | grep -o '"value"=[0-9]*' | cut -d= -f2)
        max=$(echo "$brightness_info" | grep -o '"max"=[0-9]*' | cut -d= -f2)
        if [[ -n "$value" && -n "$max" && "$max" -gt 0 ]]; then
            calc_percent "$value" "$max"
            return 0
        fi
    fi

    return 1
}

# =============================================================================
# macOS: Main Brightness Detection
# =============================================================================

_get_brightness_macos() {
    local display_opt separator
    display_opt=$(get_option "display")
    separator=$(get_option "separator")

    # Method 1: PowerKit native helper (most reliable on Apple Silicon)
    # Output format: <display_id>:<type>:<brightness>
    # type: builtin or external
    # brightness: 0-100 or -1 if not available
    local helper="${POWERKIT_ROOT}/bin/powerkit-brightness"
    if [[ -x "$helper" ]]; then
        local helper_output
        helper_output=$("$helper" 2>/dev/null)
        
        if [[ -n "$helper_output" ]]; then
            local result_parts=()
            local display_id display_type brightness

            while IFS=: read -r display_id display_type brightness; do
                # Skip displays without brightness control
                [[ "$brightness" == "-1" ]] && continue
                
                # Filter based on display option
                case "$display_opt" in
                    builtin|built-in)
                        [[ "$display_type" == "builtin" ]] && result_parts+=("$brightness")
                        ;;
                    external)
                        [[ "$display_type" == "external" ]] && result_parts+=("$brightness")
                        ;;
                    all)
                        result_parts+=("$brightness")
                        ;;
                    [0-9]*)
                        # Direct display ID
                        [[ "$display_id" == "$display_opt" ]] && result_parts+=("$brightness")
                        ;;
                    *)
                        # Default: builtin
                        [[ "$display_type" == "builtin" ]] && result_parts+=("$brightness")
                        ;;
                esac
            done <<< "$helper_output"
            
            if [[ ${#result_parts[@]} -gt 0 ]]; then
                if [[ ${#result_parts[@]} -eq 1 ]]; then
                    printf '%s' "${result_parts[0]}"
                else
                    join_with_separator "$separator" "${result_parts[@]}"
                fi
                return 0
            fi
        fi
    fi

    # Method 2: Fallback to ioreg (may have stale values on Apple Silicon)
    _get_brightness_ioreg
}

# =============================================================================
# Linux: Brightness Detection
# =============================================================================

_get_brightness_linux() {
    # Method 1: sysfs
    local dir="/sys/class/backlight"
    if [[ -d "$dir" ]]; then
        for d in "$dir"/*; do
            [[ -f "$d/brightness" && -f "$d/max_brightness" ]] || continue
            local cur max
            cur=$(cat "$d/brightness" 2>/dev/null)
            max=$(cat "$d/max_brightness" 2>/dev/null)
            if [[ -n "$cur" && -n "$max" && "$max" -gt 0 ]]; then
                calc_percent "$cur" "$max"
                return 0
            fi
        done
    fi

    # Method 2: brightnessctl
    if has_cmd brightnessctl; then
        local max cur
        max=$(brightnessctl max 2>/dev/null)
        cur=$(brightnessctl get 2>/dev/null)
        if [[ -n "$max" && "$max" -gt 0 && -n "$cur" ]]; then
            calc_percent "$cur" "$max"
            return 0
        fi
    fi

    # Method 3: light
    if has_cmd light; then
        local val
        val=$(light -G 2>/dev/null)
        [[ -n "$val" ]] && { printf '%.0f' "$val"; return 0; }
    fi

    # Method 4: xbacklight
    if has_cmd xbacklight; then
        local val
        val=$(xbacklight -get 2>/dev/null)
        [[ -n "$val" ]] && { printf '%.0f' "$val"; return 0; }
    fi

    return 1
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    local level

    if is_macos; then
        level=$(_get_brightness_macos)
    else
        level=$(_get_brightness_linux)
    fi

    [[ -n "$level" ]] && plugin_data_set "level" "$level"
}

# =============================================================================
# Plugin Contract: Render (TEXT ONLY)
# =============================================================================

plugin_render() {
    local level show_pct
    level=$(plugin_data_get "level")
    show_pct=$(get_option "show_percentage")

    [[ -z "$level" ]] && return 0

    [[ "$show_pct" == "true" ]] && printf '%s%%' "$level" || printf '%s' "$level"
}
