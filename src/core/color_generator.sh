#!/usr/bin/env bash
# =============================================================================
# PowerKit Core: Color Generator
# Description: Generates lighter and darker color variants from base colors
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "color_generator" && return 0

. "${POWERKIT_ROOT}/src/core/defaults.sh"
. "${POWERKIT_ROOT}/src/core/logger.sh"
. "${POWERKIT_ROOT}/src/core/cache.sh"

# =============================================================================
# Configuration (from defaults.sh)
# =============================================================================

# Light variant percentages (toward white)
_COLOR_LIGHT_PERCENT="${POWERKIT_COLOR_LIGHT_PERCENT}"
_COLOR_LIGHTER_PERCENT="${POWERKIT_COLOR_LIGHTER_PERCENT}"
_COLOR_LIGHTEST_PERCENT="${POWERKIT_COLOR_LIGHTEST_PERCENT}"

# Dark variant percentages (toward black)
_COLOR_DARK_PERCENT="${POWERKIT_COLOR_DARK_PERCENT}"
_COLOR_DARKER_PERCENT="${POWERKIT_COLOR_DARKER_PERCENT}"
_COLOR_DARKEST_PERCENT="${POWERKIT_COLOR_DARKEST_PERCENT}"

# Generated color variants cache
declare -gA _COLOR_VARIANTS=()

# =============================================================================
# Universal Colors (merged into every theme)
# =============================================================================

# Colors that exist in ALL themes - not theme-specific
declare -gA _UNIVERSAL_COLORS=(
    [transparent]="NONE"
    [none]="NONE"
    [white]="#ffffff"
    [black]="#000000"
)

# =============================================================================
# Color Conversion Functions
# =============================================================================

# Parse hex color to RGB components
# Usage: _hex_to_rgb "#ff5500"
# Returns: "r g b" (space-separated decimal values)
_hex_to_rgb() {
    local hex="${1#\#}"  # Remove # if present

    # Validate hex format
    if [[ ! "$hex" =~ ^[0-9a-fA-F]{6}$ ]]; then
        log_error "color_generator" "Invalid hex color: $1"
        echo "0 0 0"
        return 1
    fi

    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))

    echo "$r $g $b"
}

# Convert RGB to hex
# Usage: _rgb_to_hex 255 85 0
_rgb_to_hex() {
    local r=$1 g=$2 b=$3
    printf '#%02x%02x%02x' "$r" "$g" "$b"
}

# Clamp value between 0 and 255
# Usage: _clamp 300  # Returns 255
_clamp() {
    local val=$1
    if (( val < 0 )); then
        echo 0
    elif (( val > 255 )); then
        echo 255
    else
        echo "$val"
    fi
}

# =============================================================================
# Color Variant Functions
# =============================================================================

# Convert percent string to integer (multiply by 10 for one decimal place precision)
# Usage: _percent_to_int "18.9"  # Returns 189
_percent_to_int() {
    local percent="$1"
    local percent_int="${percent%.*}${percent#*.}"
    percent_int="${percent_int:0:3}"  # Limit to 3 digits
    [[ ${#percent_int} -lt 3 ]] && percent_int="${percent_int}0"
    printf '%s' "$percent_int"
}

# Generate lighter color from pre-parsed RGB values (internal, fast)
# Usage: _generate_lighter_from_rgb r g b percent
_generate_lighter_from_rgb() {
    local r=$1 g=$2 b=$3 percent="$4"
    local percent_int
    percent_int=$(_percent_to_int "$percent")

    # Move each component toward 255 (white)
    local new_r=$(( r + (255 - r) * percent_int / 1000 ))
    local new_g=$(( g + (255 - g) * percent_int / 1000 ))
    local new_b=$(( b + (255 - b) * percent_int / 1000 ))

    # Inline clamp for performance
    (( new_r > 255 )) && new_r=255; (( new_r < 0 )) && new_r=0
    (( new_g > 255 )) && new_g=255; (( new_g < 0 )) && new_g=0
    (( new_b > 255 )) && new_b=255; (( new_b < 0 )) && new_b=0

    printf '#%02x%02x%02x' "$new_r" "$new_g" "$new_b"
}

# Generate darker color from pre-parsed RGB values (internal, fast)
# Usage: _generate_darker_from_rgb r g b percent
_generate_darker_from_rgb() {
    local r=$1 g=$2 b=$3 percent="$4"
    local percent_int factor
    percent_int=$(_percent_to_int "$percent")
    factor=$(( 1000 - percent_int ))

    # Scale each component toward 0 (black)
    local new_r=$(( r * factor / 1000 ))
    local new_g=$(( g * factor / 1000 ))
    local new_b=$(( b * factor / 1000 ))

    # Inline clamp for performance
    (( new_r > 255 )) && new_r=255; (( new_r < 0 )) && new_r=0
    (( new_g > 255 )) && new_g=255; (( new_g < 0 )) && new_g=0
    (( new_b > 255 )) && new_b=255; (( new_b < 0 )) && new_b=0

    printf '#%02x%02x%02x' "$new_r" "$new_g" "$new_b"
}

# Calculate lighter color (increase brightness toward white)
# Usage: color_lighter "#ff5500" 18.9
# Performance: Uses pure bash integer math (percent * 10 for precision)
color_lighter() {
    local hex="$1"
    local percent="${2:-$_COLOR_LIGHTER_PERCENT}"

    local rgb
    rgb=$(_hex_to_rgb "$hex") || return 1
    read -r r g b <<< "$rgb"

    _generate_lighter_from_rgb "$r" "$g" "$b" "$percent"
}

# Calculate darker color (decrease brightness toward black)
# Usage: color_darker "#ff5500" 44.2
# Performance: Uses pure bash integer math (percent * 10 for precision)
color_darker() {
    local hex="$1"
    local percent="${2:-$_COLOR_DARKER_PERCENT}"

    local rgb
    rgb=$(_hex_to_rgb "$hex") || return 1
    read -r r g b <<< "$rgb"

    _generate_darker_from_rgb "$r" "$g" "$b" "$percent"
}

# =============================================================================
# Variant Generation
# =============================================================================

# Colors that get automatic variants (from defaults.sh)
# shellcheck disable=SC2206
_COLORS_WITH_VARIANTS=(${POWERKIT_COLORS_WITH_VARIANTS})

# Generate all color variants from base theme colors
# Usage: generate_color_variants
# Expects: THEME_COLORS associative array to be populated
# Generates 6 variants per base color:
#   -light, -lighter, -lightest (toward white)
#   -dark, -darker, -darkest (toward black)
# Note: Theme-level caching is handled by theme_loader, not here
# Performance: Pre-parses RGB once per color (6x fewer hex parses)
generate_color_variants() {
    # Check if THEME_COLORS exists
    if ! declare -p THEME_COLORS &>/dev/null; then
        log_error "color_generator" "THEME_COLORS not defined"
        return 1
    fi

    local color_name base_color rgb r g b

    for color_name in "${_COLORS_WITH_VARIANTS[@]}"; do
        base_color="${THEME_COLORS[$color_name]:-}"
        [[ -z "$base_color" ]] && continue

        # Pre-parse RGB once (instead of 6 times)
        rgb=$(_hex_to_rgb "$base_color") || continue
        read -r r g b <<< "$rgb"

        # Generate light variants (toward white) using pre-parsed RGB
        _COLOR_VARIANTS["${color_name}-light"]=$(_generate_lighter_from_rgb "$r" "$g" "$b" "$_COLOR_LIGHT_PERCENT")
        _COLOR_VARIANTS["${color_name}-lighter"]=$(_generate_lighter_from_rgb "$r" "$g" "$b" "$_COLOR_LIGHTER_PERCENT")
        _COLOR_VARIANTS["${color_name}-lightest"]=$(_generate_lighter_from_rgb "$r" "$g" "$b" "$_COLOR_LIGHTEST_PERCENT")

        # Generate dark variants (toward black) using pre-parsed RGB
        _COLOR_VARIANTS["${color_name}-dark"]=$(_generate_darker_from_rgb "$r" "$g" "$b" "$_COLOR_DARK_PERCENT")
        _COLOR_VARIANTS["${color_name}-darker"]=$(_generate_darker_from_rgb "$r" "$g" "$b" "$_COLOR_DARKER_PERCENT")
        _COLOR_VARIANTS["${color_name}-darkest"]=$(_generate_darker_from_rgb "$r" "$g" "$b" "$_COLOR_DARKEST_PERCENT")

        log_debug "color_generator" "Generated 6 variants for $color_name"
    done
}

# Get a color (base, generated variant, or universal)
# Usage: get_color "secondary-lighter"
get_color() {
    local name="$1"

    # Check universal colors first (transparent, none, white, black)
    if [[ -n "${_UNIVERSAL_COLORS[$name]:-}" ]]; then
        printf '%s' "${_UNIVERSAL_COLORS[$name]}"
        return 0
    fi

    # Check generated variants
    if [[ -n "${_COLOR_VARIANTS[$name]:-}" ]]; then
        printf '%s' "${_COLOR_VARIANTS[$name]}"
        return 0
    fi

    # Check base theme colors
    if [[ -n "${THEME_COLORS[$name]:-}" ]]; then
        printf '%s' "${THEME_COLORS[$name]}"
        return 0
    fi

    # Not found
    log_warn "color_generator" "Color not found: $name"
    return 1
}

# Check if a color exists (universal, base, or variant)
# Usage: has_color "secondary-lighter"
has_color() {
    local name="$1"
    [[ -n "${_UNIVERSAL_COLORS[$name]:-}" ]] || \
    [[ -n "${_COLOR_VARIANTS[$name]:-}" ]] || \
    [[ -n "${THEME_COLORS[$name]:-}" ]]
}

# Get all available color names
# Usage: list_colors
list_colors() {
    local name

    printf 'Universal colors:\n'
    for name in "${!_UNIVERSAL_COLORS[@]}"; do
        printf '  %s: %s\n' "$name" "${_UNIVERSAL_COLORS[$name]}"
    done

    printf '\nBase colors:\n'
    for name in "${!THEME_COLORS[@]}"; do
        printf '  %s: %s\n' "$name" "${THEME_COLORS[$name]}"
    done

    printf '\nGenerated variants:\n'
    for name in "${!_COLOR_VARIANTS[@]}"; do
        printf '  %s: %s\n' "$name" "${_COLOR_VARIANTS[$name]}"
    done
}

# Clear generated variants (for theme switching)
clear_color_variants() {
    _COLOR_VARIANTS=()
}

# =============================================================================
# Theme Color Serialization (for cache)
# =============================================================================

# Variant suffixes for detection
_VARIANT_SUFFIXES=("-light" "-lighter" "-lightest" "-dark" "-darker" "-darkest")

# Check if a color name is a variant (has variant suffix)
_is_variant_color() {
    local name="$1"
    local suffix
    for suffix in "${_VARIANT_SUFFIXES[@]}"; do
        [[ "$name" == *"$suffix" ]] && return 0
    done
    return 1
}

# Serialize all colors to a single string for caching
# Format: key=value pairs separated by \x1F (Unit Separator)
# Usage: serialize_theme_colors
serialize_theme_colors() {
    local output=""
    local key
    local sep=$'\x1F'

    # Serialize base colors
    for key in "${!THEME_COLORS[@]}"; do
        [[ -n "$output" ]] && output+="$sep"
        output+="${key}=${THEME_COLORS[$key]}"
    done

    # Serialize variants
    for key in "${!_COLOR_VARIANTS[@]}"; do
        [[ -n "$output" ]] && output+="$sep"
        output+="${key}=${_COLOR_VARIANTS[$key]}"
    done

    printf '%s' "$output"
}

# Deserialize colors from cache string
# Usage: deserialize_theme_colors "cache_content"
deserialize_theme_colors() {
    local content="$1"
    local sep=$'\x1F'

    # Clear existing
    THEME_COLORS=()
    _COLOR_VARIANTS=()

    # Parse all colors, routing to correct array based on suffix
    local entry key value
    while IFS= read -r -d "$sep" entry || [[ -n "$entry" ]]; do
        [[ -z "$entry" ]] && continue
        key="${entry%%=*}"
        value="${entry#*=}"
        if _is_variant_color "$key"; then
            _COLOR_VARIANTS["$key"]="$value"
        else
            THEME_COLORS["$key"]="$value"
        fi
    done <<< "$content"
}
