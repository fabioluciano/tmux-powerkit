#!/usr/bin/env bash
# =============================================================================
# Plugin: brightness
# Description: Display screen brightness level
# Type: conditional (hidden based on display conditions)
# Dependencies:
#   macOS Intel: ioreg (built-in, accurate real-time values)
#   macOS Apple Silicon: BetterDisplay recommended (ioreg may have stale values)
#                        Install from: https://betterdisplay.pro
#   Linux: brightnessctl/xbacklight (optional)
#
# Note: On Apple Silicon, the native ioreg command may return cached/stale
# brightness values. BetterDisplay provides accurate real-time values and
# also supports external monitors via DDC.
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    if is_macos; then
        # macOS uses built-in ioreg (always available)
        # BetterDisplay is optional but recommended for external monitors
        local display_opt
        display_opt=$(get_option "display")
        if [[ "$display_opt" == "external" || "$display_opt" == "all" || "$display_opt" == Display:* ]]; then
            if ! defaults read pro.betterdisplay.BetterDisplay &>/dev/null; then
                log_info "brightness" "BetterDisplay recommended for external monitors. Install from: https://betterdisplay.pro"
            fi
        fi
        return 0
    else
        require_any_cmd "brightnessctl" "xbacklight" 1  # Optional
    fi
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Monitor selection (macOS with BetterDisplay only)
    declare_option "display" "string" "builtin" "Display selection: builtin (or built-in), external, all, or Display:N"
    declare_option "separator" "string" " | " "Separator when showing multiple displays"

    # Display options
    declare_option "display_condition" "string" "always" "Display condition (always|lt|lte|gt|gte)"
    declare_option "display_threshold" "number" "" "Display threshold value"

    # Icons (Material Design Icons - brightness)
    declare_option "icon" "icon" $'\U000F00E0' "Plugin icon (brightness-7)"
    declare_option "icon_low" "icon" $'\U000F00DE' "Icon when brightness is low (<30%)"
    declare_option "icon_medium" "icon" $'\U000F00DF' "Icon when brightness is medium (30-70%)"
    declare_option "icon_high" "icon" $'\U000F00E0' "Icon when brightness is high (>70%)"

    # Colors
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

plugin_init "brightness"

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1" show="1" accent="" accent_icon="" icon=""
    local value=$(extract_numeric "$content")

    # Display condition
    local cond=$(get_option "display_condition")
    local thresh=$(get_option "display_threshold")
    [[ "$cond" != "always" && -n "$thresh" ]] && ! evaluate_condition "$value" "$cond" "$thresh" && show="0"

    # Dynamic icon
    if [[ -n "$value" ]]; then
        local low=$(get_option "icon_low")
        local med=$(get_option "icon_medium")
        local high=$(get_option "icon_high")
        [[ "$value" -lt 30 ]] && icon="$low" || { [[ "$value" -lt 70 ]] && icon="$med" || icon="$high"; }
    fi

    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Main Logic
# =============================================================================

# Get brightness from BetterDisplay for a specific display
# Returns percentage (0-100)
_get_betterdisplay_brightness() {
    local display_id="$1"
    local bd_output="$2"
    local value line

    # Try combinedBrightness first (hardware + software = visual brightness)
    # Format can be: = 1; or = "0.875"; (with or without quotes)
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
# Output format: "ID:TYPE" per line (e.g., "2:builtin" or "3:external")
_get_betterdisplay_displays() {
    local bd_output="$1"
    local display_ids

    # Get unique display IDs that have brightness values
    display_ids=$(echo "$bd_output" | grep -E '"value@(hardware|combined)Brightness-' | \
        grep -oE '@Display:[0-9]+' | grep -oE '[0-9]+' | sort -u)

    for id in $display_ids; do
        # Verify this display actually has a brightness value by trying to extract it
        local line has_value
        line=$(echo "$bd_output" | grep -E "\"value@(hardware|combined)Brightness-[^@]+@Display:${id}\"" | head -1)
        # Extract value handling both quoted and unquoted formats: = 1; or = "0.875";
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

_get_brightness_ioreg() {
    # IOKit via AppleARMBacklight (built-in display on Apple Silicon)
    # Uses "brightness" key which represents visual brightness (0-65536 scale)
    # NOT "rawBrightness" which is hardware-level and doesn't match visual brightness
    local ioreg_output value max brightness_info
    ioreg_output=$(ioreg -c AppleARMBacklight -r 2>/dev/null)
    [[ -z "$ioreg_output" ]] && ioreg_output=$(ioreg -r -k IODisplayParameters 2>/dev/null)
    [[ -z "$ioreg_output" ]] && return 1

    # Use "brightness" key first (visual brightness, 0-65536 scale)
    # This matches what the user sees in System Settings
    brightness_info=$(echo "$ioreg_output" | grep -o '"brightness"={[^}]*}' | head -1)
    if [[ -n "$brightness_info" ]]; then
        value=$(echo "$brightness_info" | grep -o '"value"=[0-9]*' | cut -d= -f2)
        max=$(echo "$brightness_info" | grep -o '"max"=[0-9]*' | cut -d= -f2)
        if [[ -n "$value" && -n "$max" && "$max" -gt 0 ]]; then
            printf '%d%%' "$((value * 100 / max))"
            return 0
        fi
    fi

    # Fallback to rawBrightness (hardware level, may not match visual)
    brightness_info=$(echo "$ioreg_output" | grep -o '"rawBrightness"={[^}]*}' | head -1)
    if [[ -n "$brightness_info" ]]; then
        value=$(echo "$brightness_info" | grep -o '"value"=[0-9]*' | cut -d= -f2)
        max=$(echo "$brightness_info" | grep -o '"max"=[0-9]*' | cut -d= -f2)
        if [[ -n "$value" && -n "$max" && "$max" -gt 0 ]]; then
            printf '%d%%' "$((value * 100 / max))"
            return 0
        fi
    fi

    return 1
}

_get_brightness_macos() {
    local display_opt separator
    display_opt=$(get_option "display")
    separator=$(get_option "separator")

    # Try BetterDisplay first (more accurate real-time values on Apple Silicon)
    # ioreg values may be stale/cached on modern macOS
    if defaults read pro.betterdisplay.BetterDisplay &>/dev/null; then
        local bd_output
        bd_output=$(defaults read pro.betterdisplay.BetterDisplay 2>/dev/null)

        local displays result_parts=()

        case "$display_opt" in
            builtin|built-in)
                # Get only built-in display
                displays=$(_get_betterdisplay_displays "$bd_output" | grep ":builtin" | cut -d: -f1 | head -1)
                ;;
            external)
                # Get only external displays
                displays=$(_get_betterdisplay_displays "$bd_output" | grep ":external" | cut -d: -f1)
                ;;
            all)
                # Get all displays
                displays=$(_get_betterdisplay_displays "$bd_output" | cut -d: -f1)
                ;;
            Display:*)
                # Specific display ID (e.g., "Display:2")
                displays="${display_opt#Display:}"
                ;;
            *)
                # Default to builtin
                displays=$(_get_betterdisplay_displays "$bd_output" | grep ":builtin" | cut -d: -f1 | head -1)
                ;;
        esac

        for disp_id in $displays; do
            local brightness
            brightness=$(_get_betterdisplay_brightness "$disp_id" "$bd_output")
            [[ -n "$brightness" ]] && result_parts+=("${brightness}%")
        done

        if [[ ${#result_parts[@]} -gt 0 ]]; then
            join_with_separator "$separator" "${result_parts[@]}"
            return 0
        fi
    fi

    # Fallback to ioreg (works without BetterDisplay, but may have stale values on Apple Silicon)
    _get_brightness_ioreg
}

_get_brightness_linux() {
    # Method 1: sysfs
    local dir="/sys/class/backlight"
    if [[ -d "$dir" ]]; then
        for d in "$dir"/*; do
            [[ -f "$d/brightness" && -f "$d/max_brightness" ]] || continue
            awk 'FNR==1{c=$0} END{if(FNR==2 && $0>0) printf "%d%%", (c/$0)*100}' \
                "$d/brightness" "$d/max_brightness" 2>/dev/null && return 0
        done
    fi

    # Method 2: brightnessctl
    local max=$(brightnessctl max 2>/dev/null)
    [[ -n "$max" && "$max" -gt 0 ]] && { brightnessctl get 2>/dev/null | awk -v m="$max" '{printf "%d%%", ($0/m)*100}'; return 0; }

    # Method 3: light
    light -G 2>/dev/null | awk '{printf "%d%%", $1}' && return 0

    # Method 4: xbacklight
    xbacklight -get 2>/dev/null | awk '{printf "%d%%", $1}' && return 0

    return 1
}

_get_brightness() {
    if is_macos; then
        _get_brightness_macos
    else
        _get_brightness_linux
    fi
}

_has_brightness() {
    local brightness_value=$(_get_brightness)
    [[ -n "$brightness_value" && "$brightness_value" =~ ^[0-9]+$ ]]
}

load_plugin() {
    local cached
    if cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached"
        return 0
    fi

    local result
    result=$(_get_brightness)
    [[ -z "$result" ]] && return 0

    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
