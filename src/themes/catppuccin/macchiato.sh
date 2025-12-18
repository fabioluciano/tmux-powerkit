#!/usr/bin/env bash

# Catppuccin Macchiato Theme - PowerKit Semantic Color Mapping
# Based on https://github.com/catppuccin/catppuccin
# Dark variant - Soothing pastel theme

declare -A THEME_COLORS=(
    # Core System Colors
    [transparent]="NONE"
    [none]="NONE"

    # Background Colors
    [background]="#24273a"           # Base
    [background-alt]="#1e2030"       # Mantle
    [surface]="#363a4f"              # Surface0
    [overlay]="#494d64"              # Surface1

    # Text Colors
    [text]="#cad3f5"                 # Text
    [text-muted]="#a5adcb"           # Subtext0
    [text-disabled]="#6e738d"        # Overlay1

    # Border Colors
    [border]="#494d64"               # Surface1
    [border-subtle]="#363a4f"        # Surface0
    [border-strong]="#5b6078"        # Surface2

    # Semantic Colors (PowerKit Standard)
    [accent]="#c6a0f6"               # Mauve - Main accent
    [primary]="#8aadf4"              # Blue - Primary
    [secondary]="#363a4f"            # Surface0 - Secondary (plugin content bg)
    [secondary-strong]="#24273a"     # Base - Strong secondary (darker)

    # Status Colors (PowerKit Standard)
    [success]="#a6da95"              # Green
    [warning]="#eed49f"              # Yellow - Warning (original catppuccin)
    [error]="#ed8796"                # Red
    [info]="#91d7e3"                 # Sky

    # Interactive States
    [hover]="#363a4f"                # Surface0 - Hover state
    [active]="#5b6078"               # Surface2 - Active state (icon bg, lighter than secondary)
    [focus]="#b7bdf8"                # Lavender - Focus state
    [disabled]="#6e738d"             # Overlay1 - Disabled state

    # Additional Variants
    [success-subtle]="#b6e0a9"       # Subtle success (18.9% lighter)
    [success-strong]="#5c7953"       # Strong success (44.2% darker)
    [warning-strong]="#857658"       # Strong warning (44.2% darker)
    [error-strong]="#844b53"         # Strong error (44.2% darker)
    [info-subtle]="#a5dee8"          # Subtle info (18.9% lighter)
    [info-strong]="#50777e"          # Strong info (44.2% darker)
    [error-subtle]="#f09da9"         # Subtle error (18.9% lighter)
    [warning-subtle]="#f1ddb4"       # Subtle warning (18.9% lighter)

    # System Colors
    [white]="#ffffff"                # Text
    [black]="#181926"                # Crust
)

export THEME_COLORS
