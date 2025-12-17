#!/usr/bin/env bash

# Catppuccin Mocha Theme - PowerKit Semantic Color Mapping
# Based on https://github.com/catppuccin/catppuccin
# Soothing pastel theme for the high-spirited!

declare -A THEME_COLORS=(
    # Core System Colors
    [transparent]="NONE"
    [none]="NONE"

    # Background Colors
    [background]="#1e1e2e"           # Base
    [background-alt]="#181825"       # Mantle
    [surface]="#313244"              # Surface0
    [overlay]="#45475a"              # Surface1

    # Text Colors
    [text]="#cdd6f4"                 # Text
    [text-muted]="#a6adc8"           # Subtext0
    [text-disabled]="#6c7086"        # Overlay1

    # Border Colors
    [border]="#45475a"               # Surface1
    [border-subtle]="#313244"        # Surface0
    [border-strong]="#585b70"        # Surface2

    # Semantic Colors (PowerKit Standard)
    [accent]="#cba6f7"               # Mauve - Main accent
    [primary]="#89b4fa"              # Blue - Primary
    [secondary]="#45475a"            # Surface1 - Secondary
    [secondary-strong]="#313244"     # Surface0 - Strong secondary

    # Status Colors (PowerKit Standard)
    [success]="#a6e3a1"              # Green
    [warning]="#f9e2af"              # Yellow
    [error]="#f38ba8"                # Red
    [info]="#89dceb"                 # Sky

    # Interactive States
    [hover]="#313244"                # Surface0 - Hover state
    [active]="#74c7ec"               # Sapphire - Active state
    [focus]="#b4befe"                # Lavender - Focus state
    [disabled]="#6c7086"             # Overlay1 - Disabled state

    # Additional Variants
    [success-subtle]="#94e2d5"       # Teal
    [success-strong]="#638861"       # Strong success (40% darker)
    [warning-strong]="#fab387"       # Peach
    [error-strong]="#eba0ac"         # Maroon
    [info-subtle]="#b4befe"          # Lavender
    [info-strong]="#7287fd"          # Blue (darker)
    [error-subtle]="#f5c2e7"         # Pink
    [warning-subtle]="#f5e0dc"       # Rosewater

    # System Colors
    [white]="#ffffff"                # Text
    [black]="#11111b"                # Crust
)

export THEME_COLORS
