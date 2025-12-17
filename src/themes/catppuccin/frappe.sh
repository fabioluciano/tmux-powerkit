#!/usr/bin/env bash

# Catppuccin Frappé Theme - PowerKit Semantic Color Mapping
# Based on https://github.com/catppuccin/catppuccin
# Medium-dark variant - Soothing pastel theme

declare -A THEME_COLORS=(
    # Core System Colors
    [transparent]="NONE"
    [none]="NONE"

    # Background Colors
    [background]="#303446"           # Base
    [background-alt]="#292c3c"       # Mantle
    [surface]="#414559"              # Surface0
    [overlay]="#51576d"              # Surface1

    # Text Colors
    [text]="#c6d0f5"                 # Text
    [text-muted]="#a5adce"           # Subtext0
    [text-disabled]="#737994"        # Overlay1

    # Border Colors
    [border]="#51576d"               # Surface1
    [border-subtle]="#414559"        # Surface0
    [border-strong]="#626880"        # Surface2

    # Semantic Colors (PowerKit Standard)
    [accent]="#ca9ee6"               # Mauve - Main accent
    [primary]="#8caaee"              # Blue - Primary
    [secondary]="#51576d"            # Surface1 - Secondary
    [secondary-strong]="#414559"     # Surface0 - Strong secondary

    # Status Colors (PowerKit Standard)
    [success]="#a6d189"              # Green
    [warning]="#e5c890"              # Yellow
    [error]="#e78284"                # Red
    [info]="#99d1db"                 # Sky

    # Interactive States
    [hover]="#414559"                # Surface0 - Hover state
    [active]="#85c1dc"               # Sapphire - Active state
    [focus]="#babbf1"                # Lavender - Focus state
    [disabled]="#737994"             # Overlay1 - Disabled state

    # Additional Variants
    [success-subtle]="#81c8be"       # Teal
    [success-strong]="#638052"       # Strong success (40% darker)
    [warning-strong]="#ef9f76"       # Peach
    [error-strong]="#ea999c"         # Maroon
    [info-subtle]="#babbf1"          # Lavender
    [info-strong]="#8caaee"          # Blue
    [error-subtle]="#f4b8e4"         # Pink
    [warning-subtle]="#f2d5cf"       # Rosewater

    # System Colors
    [white]="#ffffff"                # Text
    [black]="#232634"                # Crust
)

export THEME_COLORS
