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
    [secondary]="#494d64"            # Surface1 - Secondary
    [secondary-strong]="#363a4f"     # Surface0 - Strong secondary

    # Status Colors (PowerKit Standard)
    [success]="#a6da95"              # Green
    [warning]="#eed49f"              # Yellow
    [error]="#ed8796"                # Red
    [info]="#91d7e3"                 # Sky

    # Interactive States
    [hover]="#363a4f"                # Surface0 - Hover state
    [active]="#7dc4e4"               # Sapphire - Active state
    [focus]="#b7bdf8"                # Lavender - Focus state
    [disabled]="#6e738d"             # Overlay1 - Disabled state

    # Additional Variants
    [success-subtle]="#8bd5ca"       # Teal
    [success-strong]="#638259"       # Strong success (40% darker)
    [warning-strong]="#f5a97f"       # Peach
    [error-strong]="#ee99a0"         # Maroon
    [info-subtle]="#b7bdf8"          # Lavender
    [info-strong]="#8aadf4"          # Blue
    [error-subtle]="#f5bde6"         # Pink
    [warning-subtle]="#f4dbd6"       # Rosewater

    # System Colors
    [white]="#ffffff"                # Text
    [black]="#181926"                # Crust
)

export THEME_COLORS
