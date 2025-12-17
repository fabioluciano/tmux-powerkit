#!/usr/bin/env bash

# Gruvbox Dark Theme - PowerKit Semantic Color Mapping
# Based on https://github.com/morhetz/gruvbox
# Retro groove color scheme

declare -A THEME_COLORS=(
    # Core System Colors
    [transparent]="NONE"
    [none]="NONE"

    # Background Colors
    [background]="#282828"           # bg0 - Main background
    [background-alt]="#1d2021"       # bg0_h - Darker background (hard)
    [surface]="#3c3836"              # bg1 - Surface
    [overlay]="#504945"              # bg2 - Overlay

    # Text Colors
    [text]="#ebdbb2"                 # fg1 - Primary text
    [text-muted]="#a89984"           # gray - Muted text
    [text-disabled]="#665c54"        # bg3 - Disabled text

    # Border Colors
    [border]="#504945"               # bg2 - Default border
    [border-subtle]="#3c3836"        # bg1 - Subtle border
    [border-strong]="#7c6f64"        # bg4 - Strong border

    # Semantic Colors (PowerKit Standard)
    [accent]="#d79921"               # yellow - Main accent (warm)
    [primary]="#458588"              # blue - Primary
    [secondary]="#504945"            # bg2 - Secondary
    [secondary-strong]="#3c3836"     # bg1 - Strong secondary

    # Status Colors (PowerKit Standard)
    [success]="#98971a"              # green
    [warning]="#d79921"              # yellow
    [error]="#cc241d"                # red
    [info]="#458588"                 # blue

    # Interactive States
    [hover]="#3c3836"                # bg1 - Hover state
    [active]="#689d6a"               # aqua - Active state
    [focus]="#fabd2f"                # bright yellow - Focus state
    [disabled]="#665c54"             # bg3 - Disabled state

    # Additional Variants (Bright colors)
    [success-subtle]="#b8bb26"       # bright green
    [success-strong]="#5c5b10"       # Strong success (40% darker)
    [warning-strong]="#fe8019"       # orange
    [error-strong]="#9d0006"         # dark red (faded)
    [info-subtle]="#83a598"          # bright blue
    [info-strong]="#076678"          # dark blue (faded)
    [error-subtle]="#fb4934"         # bright red
    [warning-subtle]="#fabd2f"       # bright yellow

    # System Colors
    [white]="#ffffff"                # fg0 (lightest)
    [black]="#1d2021"                # bg0_h (darkest)
)

export THEME_COLORS
