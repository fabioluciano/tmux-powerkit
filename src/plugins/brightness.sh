#!/usr/bin/env bash
# =============================================================================
# Plugin: brightness
# Description: Display screen brightness level
# Type: conditional (hidden based on display conditions)
# Dependencies:
#   macOS Intel: ioreg (built-in, accurate real-time values)
#   macOS Apple Silicon: BetterDisplay recommended (ioreg may have stale values)
#                        Install from: https://betterdisplay.pro
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
    metadata_set "version" "2.2.0"
    metadata_set "description" "Display screen brightness level"
    metadata_set "priority" "135"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    if is_macos; then
        # macOS uses built-in ioreg (always available)
        # BetterDisplay is optional but recommended for external monitors
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
    # Monitor selection (macOS with BetterDisplay only)
    declare_option "display" "string" "builtin" "Display: builtin, external, all, or Display:N"
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
# macOS: BetterDisplay Support
# =============================================================================

# Get brightness from BetterDisplay for a specific display
_get_betterdisplay_brightness() {
    local display_id="$1"
    local bd_output="$2"
    local value line

    # Try combinedBrightness first (hardware + software = visual brightness)
    line=$(echo "$bd_output" | grep -E "\"value@combinedBrightness-[^@]+@Display:${display_id}\"" | head -1)
    if [[ -n "$line" ]]; then
        value=$(echo "$line" | sed -E 's/.*= *"?([0-9.]+)"?;.*/\1/')
    fi

    # Fallback to hardwareBrightness
    if [[ -z "$value" ]]; then
        line=$(echo "$bd_output" | grep -E "\"value@hardwareBrightness-[^@]+@Display:${display_id}\"" | head -1)
        if [[ -n "$line" ]]; then
            value=$(echo "$line" | sed -E 's/.*= *"?([0-9.]+)"?;.*/\1/')
        fi
    fi

    [[ -z "$value" ]] && return 1

    # BetterDisplay uses 0-1 scale, convert to percentage
    printf '%d' "$(awk "BEGIN {printf \"%.0f\", $value * 100}")"
}

# Get all display IDs from BetterDisplay that have brightness control
_get_betterdisplay_displays() {
    local bd_output="$1"
    local display_ids

    # Get unique display IDs that have brightness values
    display_ids=$(echo "$bd_output" | grep -E '"value@(hardware|combined)Brightness-' | \
        grep -oE '@Display:[0-9]+' | grep -oE '[0-9]+' | sort -u)

    for id in $display_ids; do
        local line has_value
        line=$(echo "$bd_output" | grep -E "\"value@(hardware|combined)Brightness-[^@]+@Display:${id}\"" | head -1)
        has_value=$(echo "$line" | sed -E 's/.*= *"?([0-9.]+)"?;.*/\1/')
        [[ -z "$has_value" || "$has_value" == "0" ]] && continue

        # Check if it's built-in (AppleController) or external (DDCController)
        if echo "$bd_output" | grep -q "AppleController@Display:${id}"; then
            echo "${id}:builtin"
        else
            echo "${id}:external"
        fi
    done
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
            printf '%d' "$((value * 100 / max))"
            return 0
        fi
    fi

    # Fallback to rawBrightness (hardware level)
    brightness_info=$(echo "$ioreg_output" | grep -o '"rawBrightness"={[^}]*}' | head -1)
    if [[ -n "$brightness_info" ]]; then
        value=$(echo "$brightness_info" | grep -o '"value"=[0-9]*' | cut -d= -f2)
        max=$(echo "$brightness_info" | grep -o '"max"=[0-9]*' | cut -d= -f2)
        if [[ -n "$value" && -n "$max" && "$max" -gt 0 ]]; then
            printf '%d' "$((value * 100 / max))"
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

    # Try BetterDisplay first (more accurate on Apple Silicon)
    if defaults read pro.betterdisplay.BetterDisplay &>/dev/null; then
        local bd_output
        bd_output=$(defaults read pro.betterdisplay.BetterDisplay 2>/dev/null)

        local displays result_parts=()

        case "$display_opt" in
            builtin|built-in)
                displays=$(_get_betterdisplay_displays "$bd_output" | grep ":builtin" | cut -d: -f1 | head -1)
                ;;
            external)
                displays=$(_get_betterdisplay_displays "$bd_output" | grep ":external" | cut -d: -f1)
                ;;
            all)
                displays=$(_get_betterdisplay_displays "$bd_output" | cut -d: -f1)
                ;;
            Display:*)
                displays="${display_opt#Display:}"
                ;;
            *)
                displays=$(_get_betterdisplay_displays "$bd_output" | grep ":builtin" | cut -d: -f1 | head -1)
                ;;
        esac

        for disp_id in $displays; do
            local brightness
            brightness=$(_get_betterdisplay_brightness "$disp_id" "$bd_output")
            [[ -n "$brightness" ]] && result_parts+=("$brightness")
        done

        if [[ ${#result_parts[@]} -gt 0 ]]; then
            # Return first value (or join if multiple)
            if [[ ${#result_parts[@]} -eq 1 ]]; then
                printf '%s' "${result_parts[0]}"
            else
                local IFS="$separator"
                printf '%s' "${result_parts[*]}"
            fi
            return 0
        fi
    fi

    # Fallback to ioreg
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
                printf '%d' "$((cur * 100 / max))"
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
            printf '%d' "$((cur * 100 / max))"
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
