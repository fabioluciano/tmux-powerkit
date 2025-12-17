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
    [warning]="#b57614"              # yellow
    [error]="#9d0006"                # red
    [info]="#076678"                 # blue

    # Interactive States
    [hover]="#ebdbb2"                # bg1 - Hover state
    [active]="#427b58"               # aqua - Active state
    [focus]="#d79921"                # bright yellow - Focus state
    [disabled]="#bdae93"             # bg3 - Disabled state

    # Additional Variants (Faded colors)
    [success-subtle]="#98971a"       # bright green
    [success-strong]="#494608"       # Strong success (40% darker)
    [warning-strong]="#af3a03"       # orange
    [error-strong]="#cc241d"         # bright red
    [info-subtle]="#458588"          # bright blue
    [info-strong]="#076678"          # dark blue (faded)
    [error-subtle]="#cc241d"         # bright red
    [warning-subtle]="#d79921"       # bright yellow

    # System Colors
    [white]="#ffffff"                # bg0_h (lightest)
    [black]="#282828"                # fg0 (darkest)
)

export THEME_COLORS
