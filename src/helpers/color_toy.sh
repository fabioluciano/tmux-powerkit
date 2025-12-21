#!/usr/bin/env bash
# =============================================================================
# Color Toy - Calculate lighter and darker color variants
# Usage: color_toy.sh <hex_color> <mode> <percentage>
#
# Parameters:
#   hex_color  - Color in hex format (e.g., #ff5500 or ff5500)
#   mode       - darker, lighter, or both
#   percentage - Percentage to adjust (e.g., 18.9 or 44.2)
#
# Examples:
#   ./color_toy.sh "#ff5500" lighter 18.9
#   ./color_toy.sh "394b70" darker 44.2
#   ./color_toy.sh "#bb9af7" both 20
# =============================================================================

set -eu

# Parse hex color to RGB components
_hex_to_rgb() {
    local hex="${1#\#}"  # Remove # if present

    # Validate hex format
    if [[ ! "$hex" =~ ^[0-9a-fA-F]{6}$ ]]; then
        echo "Error: Invalid hex color format. Use #RRGGBB or RRGGBB" >&2
        return 1
    fi

    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))

    echo "$r $g $b"
}

# Convert RGB to hex
_rgb_to_hex() {
    local r=$1 g=$2 b=$3
    printf '#%02x%02x%02x' "$r" "$g" "$b"
}

# Clamp value between 0 and 255
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

# Calculate lighter color (increase brightness)
# Uses HSL lightening: moves color toward white
_calculate_lighter() {
    local r=$1 g=$2 b=$3 percent=$4

    # Calculate how much to add toward white (255)
    local factor
    factor=$(awk -v p="$percent" 'BEGIN { printf "%.4f", p / 100 }')

    local new_r new_g new_b
    new_r=$(awk -v r="$r" -v f="$factor" 'BEGIN { printf "%.0f", r + (255 - r) * f }')
    new_g=$(awk -v g="$g" -v f="$factor" 'BEGIN { printf "%.0f", g + (255 - g) * f }')
    new_b=$(awk -v b="$b" -v f="$factor" 'BEGIN { printf "%.0f", b + (255 - b) * f }')

    new_r=$(_clamp "$new_r")
    new_g=$(_clamp "$new_g")
    new_b=$(_clamp "$new_b")

    _rgb_to_hex "$new_r" "$new_g" "$new_b"
}

# Calculate darker color (decrease brightness)
# Uses HSL darkening: moves color toward black
_calculate_darker() {
    local r=$1 g=$2 b=$3 percent=$4

    # Calculate how much to subtract toward black (0)
    local factor
    factor=$(awk -v p="$percent" 'BEGIN { printf "%.4f", 1 - (p / 100) }')

    local new_r new_g new_b
    new_r=$(awk -v r="$r" -v f="$factor" 'BEGIN { printf "%.0f", r * f }')
    new_g=$(awk -v g="$g" -v f="$factor" 'BEGIN { printf "%.0f", g * f }')
    new_b=$(awk -v b="$b" -v f="$factor" 'BEGIN { printf "%.0f", b * f }')

    new_r=$(_clamp "$new_r")
    new_g=$(_clamp "$new_g")
    new_b=$(_clamp "$new_b")

    _rgb_to_hex "$new_r" "$new_g" "$new_b"
}

# Print usage
_usage() {
    cat << 'EOF'
Color Toy - Calculate lighter and darker color variants

Usage: color_toy.sh <hex_color> <mode> <percentage>

Parameters:
  hex_color  - Color in hex format (e.g., #ff5500 or ff5500)
  mode       - darker, lighter, or both
  percentage - Percentage to adjust (e.g., 18.9 or 44.2)

Examples:
  ./color_toy.sh "#394b70" lighter 18.9
  ./color_toy.sh "#565f89" darker 44.2
  ./color_toy.sh "#bb9af7" both 20

Common percentages used in PowerKit themes:
  - subtle variants: 18.9% lighter
  - strong variants: 44.2% darker
EOF
}

# Main function
main() {
    if [[ $# -lt 3 ]]; then
        _usage
        exit 1
    fi

    local hex_color="$1"
    local mode="$2"
    local percent="$3"

    # Validate mode
    if [[ ! "$mode" =~ ^(darker|lighter|both)$ ]]; then
        echo "Error: Mode must be 'darker', 'lighter', or 'both'" >&2
        exit 1
    fi

    # Validate percentage
    if ! [[ "$percent" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo "Error: Percentage must be a number (e.g., 18.9)" >&2
        exit 1
    fi

    # Parse color
    local rgb
    rgb=$(_hex_to_rgb "$hex_color") || exit 1
    read -r r g b <<< "$rgb"

    echo "Input color: ${hex_color} (R:$r G:$g B:$b)"
    echo "Mode: $mode"
    echo "Percentage: $percent%"
    echo "---"

    case "$mode" in
        lighter)
            local lighter
            lighter=$(_calculate_lighter "$r" "$g" "$b" "$percent")
            echo "Lighter ($percent%): $lighter"
            ;;
        darker)
            local darker
            darker=$(_calculate_darker "$r" "$g" "$b" "$percent")
            echo "Darker ($percent%): $darker"
            ;;
        both)
            local lighter darker
            lighter=$(_calculate_lighter "$r" "$g" "$b" "$percent")
            darker=$(_calculate_darker "$r" "$g" "$b" "$percent")
            echo "Lighter ($percent%): $lighter"
            echo "Darker ($percent%): $darker"
            ;;
    esac
}

# Run if executed directly
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
