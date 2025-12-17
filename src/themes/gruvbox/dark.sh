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
    [warning]="#dca53d"              # Yellow (13% lighter)
    [error]="#cc241d"                # red
    [info]="#458588"                 # blue

    # Interactive States
    [hover]="#3c3836"                # bg1 - Hover state
    [active]="#689d6a"               # aqua - Active state
    [focus]="#fabd2f"                # bright yellow - Focus state
    [disabled]="#665c54"             # bg3 - Disabled state

    # Additional Variants (Bright colors)
    [success-subtle]="#abaa45"       # Subtle success (18.9% lighter)
    [success-strong]="#54540e"       # Strong success (44.2% darker)
    [warning-strong]="#7a5c22"       # Strong warning (44.2% darker)
    [error-strong]="#711410"         # Strong error (44.2% darker)
    [info-subtle]="#689c9e"          # Subtle info (18.9% lighter)
    [info-strong]="#264a4b"          # Strong info (44.2% darker)
    [error-subtle]="#d54d47"         # Subtle error (18.9% lighter)
    [warning-subtle]="#e2b661"       # Subtle warning (18.9% lighter)

    # System Colors
    [white]="#ffffff"                # fg0 (lightest)
    [black]="#1d2021"                # bg0_h (darkest)
)

export THEME_COLORS
