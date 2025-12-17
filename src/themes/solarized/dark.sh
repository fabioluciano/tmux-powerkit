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
    [warning]="#be971f"              # Yellow (13% lighter)
    [error]="#dc322f"                # red
    [info]="#2aa198"                 # cyan

    # Interactive States
    [hover]="#073642"                # base02 - Hover state
    [active]="#d33682"               # magenta - Active state
    [focus]="#268bd2"                # blue - Focus state
    [disabled]="#586e75"             # base01 - Disabled state

    # Additional Variants
    [success-subtle]="#9cac30"       # Subtle success (18.9% lighter)
    [success-strong]="#4a5500"       # Strong success (44.2% darker)
    [warning-strong]="#6a5411"       # Strong warning (44.2% darker)
    [error-strong]="#7a1b1a"         # Strong error (44.2% darker)
    [info-subtle]="#4fa0da"          # Subtle info (18.9% lighter)
    [info-strong]="#154d75"          # Strong info (44.2% darker)
    [error-subtle]="#e25856"         # Subtle error (18.9% lighter)
    [warning-subtle]="#caaa49"       # Subtle warning (18.9% lighter)

    # System Colors
    [white]="#ffffff"                # Pure white (for plugin text contrast)
    [black]="#002b36"                # base03 (darkest)
)

export THEME_COLORS
