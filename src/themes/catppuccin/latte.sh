#!/usr/bin/env bash

# Catppuccin Latte Theme - PowerKit Semantic Color Mapping
# Based on https://github.com/catppuccin/catppuccin
# Light variant - Soothing pastel theme

declare -A THEME_COLORS=(
    # Core System Colors
    [transparent]="NONE"
    [none]="NONE"

    # Background Colors
    [background]="#eff1f5"           # Base
    [background-alt]="#e6e9ef"       # Mantle
    [surface]="#ccd0da"              # Surface0
    [overlay]="#bcc0cc"              # Surface1

    # Text Colors
    [text]="#4c4f69"                 # Text
    [text-muted]="#6c6f85"           # Subtext0
    [text-disabled]="#9ca0b0"        # Overlay1

    # Border Colors
    [border]="#bcc0cc"               # Surface1
    [border-subtle]="#ccd0da"        # Surface0
    [border-strong]="#acb0be"        # Surface2

    # Semantic Colors (PowerKit Standard)
    [accent]="#8839ef"               # Mauve - Main accent
    [primary]="#1e66f5"              # Blue - Primary
    [secondary]="#bcc0cc"            # Surface1 - Secondary
    [secondary-strong]="#ccd0da"     # Surface0 - Strong secondary

    # Status Colors (PowerKit Standard)
    [success]="#40a02b"              # Green
    [warning]="#df8e1d"              # Yellow
    [error]="#d20f39"                # Red
    [info]="#04a5e5"                 # Sky

    # Interactive States
    [hover]="#ccd0da"                # Surface0 - Hover state
    [active]="#209fb5"               # Sapphire - Active state
    [focus]="#7287fd"                # Lavender - Focus state
    [disabled]="#9ca0b0"             # Overlay1 - Disabled state

    # Additional Variants
    [success-subtle]="#179299"       # Teal
    [success-strong]="#266019"       # Strong success (40% darker)
    [warning-strong]="#fe640b"       # Peach
    [error-strong]="#e64553"         # Maroon
    [info-subtle]="#7287fd"          # Lavender
    [info-strong]="#1e66f5"          # Blue
    [error-subtle]="#ea76cb"         # Pink
    [warning-subtle]="#dc8a78"       # Rosewater

    # System Colors
    [white]="#ffffff"                # Base (lightest in light theme)
    [black]="#4c4f69"                # Text (darkest in light theme)
)

export THEME_COLORS
