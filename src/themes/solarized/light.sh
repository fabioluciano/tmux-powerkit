#!/usr/bin/env bash

# Solarized Light Theme - PowerKit Semantic Color Mapping
# Based on https://ethanschoonover.com/solarized/
# Precision colors for machines and people - Light variant

declare -A THEME_COLORS=(
    # Core System Colors
    [transparent]="NONE"
    [none]="NONE"

    # Background Colors
    [background]="#fdf6e3"           # base3 - Main background
    [background-alt]="#eee8d5"       # base2 - Alternative background
    [surface]="#eee8d5"              # base2 - Surface
    [overlay]="#93a1a1"              # base1 - Overlay

    # Text Colors
    [text]="#657b83"                 # base00 - Primary text
    [text-muted]="#839496"           # base0 - Muted text
    [text-disabled]="#93a1a1"        # base1 - Disabled text

    # Border Colors
    [border]="#eee8d5"               # base2 - Default border
    [border-subtle]="#fdf6e3"        # base3 - Subtle border
    [border-strong]="#586e75"        # base01 - Strong border

    # Semantic Colors (PowerKit Standard)
    [accent]="#268bd2"               # blue - Main accent
    [primary]="#6c71c4"              # violet - Primary
    [secondary]="#eee8d5"            # base2 - Secondary
    [secondary-strong]="#fdf6e3"     # base3 - Strong secondary

    # Status Colors (PowerKit Standard)
    [success]="#859900"              # green
    [warning]="#be971f"              # Yellow (13% lighter)
    [error]="#dc322f"                # red
    [info]="#2aa198"                 # cyan

    # Interactive States
    [hover]="#eee8d5"                # base2 - Hover state
    [active]="#d33682"               # magenta - Active state
    [focus]="#268bd2"                # blue - Focus state
    [disabled]="#93a1a1"             # base1 - Disabled state

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
