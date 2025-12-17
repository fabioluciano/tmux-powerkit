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
    [warning]="#e29c39"              # Yellow (13% lighter)
    [error]="#d20f39"                # Red
    [info]="#04a5e5"                 # Sky

    # Interactive States
    [hover]="#ccd0da"                # Surface0 - Hover state
    [active]="#209fb5"               # Sapphire - Active state
    [focus]="#7287fd"                # Lavender - Focus state
    [disabled]="#9ca0b0"             # Overlay1 - Disabled state

    # Additional Variants
    [success-subtle]="#64b153"       # Subtle success (18.9% lighter)
    [success-strong]="#235917"       # Strong success (44.2% darker)
    [warning-strong]="#7e571f"       # Strong warning (44.2% darker)
    [error-strong]="#75081f"         # Strong error (44.2% darker)
    [info-subtle]="#33b6e9"          # Subtle info (18.9% lighter)
    [info-strong]="#025c7f"          # Strong info (44.2% darker)
    [error-subtle]="#da3c5e"         # Subtle error (18.9% lighter)
    [warning-subtle]="#e7ae5e"       # Subtle warning (18.9% lighter)

    # System Colors
    [white]="#ffffff"                # Base (lightest in light theme)
    [black]="#4c4f69"                # Text (darkest in light theme)
)

export THEME_COLORS
