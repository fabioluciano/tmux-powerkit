#!/usr/bin/env bash

# Rosé Pine Theme - PowerKit Semantic Color Mapping
# Based on https://rosepinetheme.com/
# All natural pine, faux fur and a bit of soho vibes

declare -A THEME_COLORS=(
    # Core System Colors
    [transparent]="NONE"
    [none]="NONE"

    # Background Colors
    [background]="#191724"           # Base
    [background-alt]="#1f1d2e"       # Surface
    [surface]="#26233a"              # Overlay
    [overlay]="#403d52"              # Muted

    # Text Colors
    [text]="#e0def4"                 # Text
    [text-muted]="#908caa"           # Subtle
    [text-disabled]="#6e6a86"        # Muted

    # Border Colors
    [border]="#26233a"               # Overlay
    [border-subtle]="#1f1d2e"        # Surface
    [border-strong]="#524f67"        # Highlight Med

    # Semantic Colors (PowerKit Standard)
    [accent]="#c4a7e7"               # Iris - Main accent
    [primary]="#ebbcba"              # Rose - Primary
    [secondary]="#26233a"            # Overlay - Secondary
    [secondary-strong]="#1f1d2e"     # Surface - Strong secondary

    # Status Colors (PowerKit Standard)
    [success]="#9ccfd8"              # Foam
    [warning]="#f6c177"              # Gold
    [error]="#eb6f92"                # Love
    [info]="#31748f"                 # Pine

    # Interactive States
    [hover]="#1f1d2e"                # Surface - Hover state
    [active]="#ebbcba"               # Rose - Active state
    [focus]="#c4a7e7"                # Iris - Focus state
    [disabled]="#6e6a86"             # Muted - Disabled state

    # Additional Variants
    [success-subtle]="#b3e1e8"       # Lighter foam
    [success-strong]="#5e7c82"       # Strong success (40% darker)
    [warning-strong]="#ea9d34"       # Darker gold
    [error-strong]="#d84f76"         # Darker love
    [info-subtle]="#4a95b0"          # Lighter pine
    [info-strong]="#286983"          # Darker pine
    [error-subtle]="#f092ad"         # Lighter love
    [warning-subtle]="#f8d5a8"       # Lighter gold

    # System Colors
    [white]="#ffffff"                # Text
    [black]="#191724"                # Base
)

export THEME_COLORS
