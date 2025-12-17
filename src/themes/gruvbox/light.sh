#!/usr/bin/env bash

# Gruvbox Light Theme - PowerKit Semantic Color Mapping
# Based on https://github.com/morhetz/gruvbox
# Retro groove color scheme - Light variant

declare -A THEME_COLORS=(
    # Core System Colors
    [transparent]="NONE"
    [none]="NONE"

    # Background Colors
    [background]="#fbf1c7"           # bg0 - Main background
    [background-alt]="#f9f5d7"       # bg0_h - Lighter background (hard)
    [surface]="#ebdbb2"              # bg1 - Surface
    [overlay]="#d5c4a1"              # bg2 - Overlay

    # Text Colors
    [text]="#3c3836"                 # fg1 - Primary text
    [text-muted]="#665c54"           # gray - Muted text
    [text-disabled]="#a89984"        # bg3 - Disabled text

    # Border Colors
    [border]="#d5c4a1"               # bg2 - Default border
    [border-subtle]="#ebdbb2"        # bg1 - Subtle border
    [border-strong]="#7c6f64"        # bg4 - Strong border

    # Semantic Colors (PowerKit Standard)
    [accent]="#b57614"               # yellow - Main accent (warm)
    [primary]="#076678"              # blue - Primary
    [secondary]="#d5c4a1"            # bg2 - Secondary
    [secondary-strong]="#ebdbb2"     # bg1 - Strong secondary

    # Status Colors (PowerKit Standard)
    [success]="#79740e"              # green
    [warning]="#be8631"              # Yellow (13% lighter)
    [error]="#9d0006"                # red
    [info]="#076678"                 # blue

    # Interactive States
    [hover]="#ebdbb2"                # bg1 - Hover state
    [active]="#427b58"               # aqua - Active state
    [focus]="#d79921"                # bright yellow - Focus state
    [disabled]="#bdae93"             # bg3 - Disabled state

    # Additional Variants (Faded colors)
    [success-subtle]="#928e3b"       # Subtle success (18.9% lighter)
    [success-strong]="#434007"       # Strong success (44.2% darker)
    [warning-strong]="#6a4a1b"       # Strong warning (44.2% darker)
    [error-strong]="#570003"         # Strong error (44.2% darker)
    [info-subtle]="#358291"          # Subtle info (18.9% lighter)
    [info-strong]="#033842"          # Strong info (44.2% darker)
    [error-subtle]="#af3035"         # Subtle error (18.9% lighter)
    [warning-subtle]="#ca9c57"       # Subtle warning (18.9% lighter)

    # System Colors
    [white]="#ffffff"                # bg0_h (lightest)
    [black]="#282828"                # fg0 (darkest)
)

export THEME_COLORS
