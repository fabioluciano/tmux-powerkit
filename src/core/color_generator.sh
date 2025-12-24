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

# Calculate lighter color (increase brightness toward white)
# Usage: color_lighter "#ff5500" 18.9
# Performance: Uses pure bash integer math (percent * 10 for precision)
color_lighter() {
    local hex="$1"
    local percent="${2:-$_COLOR_LIGHTER_PERCENT}"

    local rgb
    rgb=$(_hex_to_rgb "$hex") || return 1
    read -r r g b <<< "$rgb"

    # Convert percent to integer (multiply by 10 for one decimal place precision)
    # e.g., 18.9 -> 189
    local percent_int="${percent%.*}${percent#*.}"
    percent_int="${percent_int:0:3}"  # Limit to 3 digits
    [[ ${#percent_int} -lt 3 ]] && percent_int="${percent_int}0"

    # Move each component toward 255 (white)
    # Formula: new = old + (255 - old) * percent / 100
    # Using integer math: new = old + (255 - old) * percent_int / 1000
    local new_r new_g new_b
    new_r=$(( r + (255 - r) * percent_int / 1000 ))
    new_g=$(( g + (255 - g) * percent_int / 1000 ))
    new_b=$(( b + (255 - b) * percent_int / 1000 ))

    new_r=$(_clamp "$new_r")
    new_g=$(_clamp "$new_g")
    new_b=$(_clamp "$new_b")

    _rgb_to_hex "$new_r" "$new_g" "$new_b"
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

    # Convert percent to integer (multiply by 10 for one decimal place precision)
    # e.g., 44.2 -> 442
    local percent_int="${percent%.*}${percent#*.}"
    percent_int="${percent_int:0:3}"  # Limit to 3 digits
    [[ ${#percent_int} -lt 3 ]] && percent_int="${percent_int}0"

    # Calculate factor as 1000 - percent_int (e.g., 44.2% -> factor = 558)
    local factor=$(( 1000 - percent_int ))

    # Scale each component toward 0 (black)
    # Formula: new = old * (1 - percent/100) = old * factor / 1000
    local new_r new_g new_b
    new_r=$(( r * factor / 1000 ))
    new_g=$(( g * factor / 1000 ))
    new_b=$(( b * factor / 1000 ))

    new_r=$(_clamp "$new_r")
    new_g=$(_clamp "$new_g")
    new_b=$(_clamp "$new_b")

    _rgb_to_hex "$new_r" "$new_g" "$new_b"
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
generate_color_variants() {
    # Check if THEME_COLORS exists
    if ! declare -p THEME_COLORS &>/dev/null; then
        log_error "color_generator" "THEME_COLORS not defined"
        return 1
    fi

    local color_name base_color

    for color_name in "${_COLORS_WITH_VARIANTS[@]}"; do
        base_color="${THEME_COLORS[$color_name]:-}"
        [[ -z "$base_color" ]] && continue

        # Generate light variants (toward white)
        _COLOR_VARIANTS["${color_name}-light"]=$(color_lighter "$base_color" "$_COLOR_LIGHT_PERCENT")
        _COLOR_VARIANTS["${color_name}-lighter"]=$(color_lighter "$base_color" "$_COLOR_LIGHTER_PERCENT")
        _COLOR_VARIANTS["${color_name}-lightest"]=$(color_lighter "$base_color" "$_COLOR_LIGHTEST_PERCENT")

        # Generate dark variants (toward black)
        _COLOR_VARIANTS["${color_name}-dark"]=$(color_darker "$base_color" "$_COLOR_DARK_PERCENT")
        _COLOR_VARIANTS["${color_name}-darker"]=$(color_darker "$base_color" "$_COLOR_DARKER_PERCENT")
        _COLOR_VARIANTS["${color_name}-darkest"]=$(color_darker "$base_color" "$_COLOR_DARKEST_PERCENT")

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

# Serialize all colors to a single string for caching
# Format: base_colors|variants (newline-separated key=value pairs)
# Usage: serialize_theme_colors
serialize_theme_colors() {
    local output=""
    local key
    
    # Serialize base colors
    for key in "${!THEME_COLORS[@]}"; do
        output+="${key}=${THEME_COLORS[$key]}"
        output+=$'\n'
    done
    
    output+="|"
    
    # Serialize variants
    for key in "${!_COLOR_VARIANTS[@]}"; do
        output+="${key}=${_COLOR_VARIANTS[$key]}"
        output+=$'\n'
    done
    
    printf '%s' "$output"
}

# Deserialize colors from cache string
# Usage: deserialize_theme_colors "cache_content"
deserialize_theme_colors() {
    local content="$1"
    
    # Split by pipe delimiter
    local base_part="${content%%|*}"
    local variants_part="${content#*|}"
    
    # Clear existing
    THEME_COLORS=()
    _COLOR_VARIANTS=()
    
    # Parse base colors
    local key value
    while IFS='=' read -r key value; do
        [[ -z "$key" ]] && continue
        THEME_COLORS["$key"]="$value"
    done <<< "$base_part"
    
    # Parse variants
    while IFS='=' read -r key value; do
        [[ -z "$key" ]] && continue
        _COLOR_VARIANTS["$key"]="$value"
    done <<< "$variants_part"
}
