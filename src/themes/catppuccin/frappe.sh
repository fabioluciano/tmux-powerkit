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
    [secondary]="#414559"            # Surface0 - Secondary (plugin content bg)
    [secondary-strong]="#303446"     # Base - Strong secondary (darker)

    # Status Colors (PowerKit Standard)
    [success]="#a6d189"              # Green
    [warning]="#e5c890"              # Yellow - Warning (original catppuccin)
    [error]="#e78284"                # Red
    [info]="#99d1db"                 # Sky

    # Interactive States
    [hover]="#414559"                # Surface0 - Hover state
    [active]="#626880"               # Surface2 - Active state (icon bg, lighter than secondary)
    [focus]="#babbf1"                # Lavender - Focus state
    [disabled]="#737994"             # Overlay1 - Disabled state

    # Additional Variants
    [success-subtle]="#b6d99f"       # Subtle success (18.9% lighter)
    [success-strong]="#5c744c"       # Strong success (44.2% darker)
    [warning-strong]="#806f50"       # Strong warning (44.2% darker)
    [error-strong]="#804849"         # Strong error (44.2% darker)
    [info-subtle]="#acd9e1"          # Subtle info (18.9% lighter)
    [info-strong]="#55747a"          # Strong info (44.2% darker)
    [error-subtle]="#eb999b"         # Subtle error (18.9% lighter)
    [warning-subtle]="#ead3a7"       # Subtle warning (18.9% lighter)

    # System Colors
    [white]="#ffffff"                # Text
    [black]="#232634"                # Crust
)

export THEME_COLORS
