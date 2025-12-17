#!/usr/bin/env bash

# Solarized Dark Theme - PowerKit Semantic Color Mapping
# Based on https://ethanschoonover.com/solarized/
# Precision colors for machines and people

declare -A THEME_COLORS=(
    # Core System Colors
    [transparent]="NONE"
    [none]="NONE"

    # Background Colors
    [background]="#002b36"           # base03 - Main background
    [background-alt]="#073642"       # base02 - Alternative background
    [surface]="#073642"              # base02 - Surface
    [overlay]="#586e75"              # base01 - Overlay

    # Text Colors
    [text]="#93a1a1"                 # base1 - Primary text (brighter)
    [text-muted]="#839496"           # base0 - Muted text
    [text-disabled]="#586e75"        # base01 - Disabled text

    # Border Colors
    [border]="#073642"               # base02 - Default border
    [border-subtle]="#002b36"        # base03 - Subtle border
    [border-strong]="#93a1a1"        # base1 - Strong border

    # Semantic Colors (PowerKit Standard)
    [accent]="#268bd2"               # blue - Main accent
    [primary]="#6c71c4"              # violet - Primary
    [secondary]="#073642"            # base02 - Secondary
    [secondary-strong]="#002b36"     # base03 - Strong secondary

    # Status Colors (PowerKit Standard)
    [success]="#859900"              # green
    [warning]="#b58900"              # yellow
    [error]="#dc322f"                # red
    [info]="#2aa198"                 # cyan

    # Interactive States
    [hover]="#073642"                # base02 - Hover state
    [active]="#d33682"               # magenta - Active state
    [focus]="#268bd2"                # blue - Focus state
    [disabled]="#586e75"             # base01 - Disabled state

    # Additional Variants
    [success-subtle]="#96ab05"       # Lighter green
    [success-strong]="#505c00"       # Strong success (40% darker)
    [warning-strong]="#cb4b16"       # orange
    [error-strong]="#b52a27"         # Darker red
    [info-subtle]="#35bdb4"          # Lighter cyan
    [info-strong]="#1a7a73"          # Darker cyan
    [error-subtle]="#e35d5b"         # Lighter red
    [warning-subtle]="#dda520"       # Lighter yellow

    # System Colors
    [white]="#ffffff"                # Pure white (for plugin text contrast)
    [black]="#002b36"                # base03 (darkest)
)

export THEME_COLORS
