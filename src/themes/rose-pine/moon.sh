#!/usr/bin/env bash

# Rosé Pine Moon Theme - PowerKit Semantic Color Mapping
# Based on https://rosepinetheme.com/
# Darker variant - All natural pine, faux fur and a bit of soho vibes

declare -A THEME_COLORS=(
    # Core System Colors
    [transparent]="NONE"
    [none]="NONE"

    # Background Colors
    [background]="#232136"           # Base
    [background-alt]="#2a273f"       # Surface
    [surface]="#393552"              # Overlay
    [overlay]="#44415a"              # Muted

    # Text Colors
    [text]="#e0def4"                 # Text
    [text-muted]="#908caa"           # Subtle
    [text-disabled]="#6e6a86"        # Muted

    # Border Colors
    [border]="#393552"               # Overlay
    [border-subtle]="#2a273f"        # Surface
    [border-strong]="#56526e"        # Highlight Med

    # Semantic Colors (PowerKit Standard)
    [accent]="#c4a7e7"               # Iris - Main accent
    [primary]="#ea9a97"              # Rose - Primary
    [secondary]="#393552"            # Overlay - Secondary
    [secondary-strong]="#2a273f"     # Surface - Strong secondary

    # Status Colors (PowerKit Standard)
    [success]="#9ccfd8"              # Foam
    [warning]="#f6c177"              # Gold
    [error]="#eb6f92"                # Love
    [info]="#3e8fb0"                 # Pine

    # Interactive States
    [hover]="#2a273f"                # Surface - Hover state
    [active]="#ea9a97"               # Rose - Active state
    [focus]="#c4a7e7"                # Iris - Focus state
    [disabled]="#6e6a86"             # Muted - Disabled state

    # Additional Variants
    [success-subtle]="#b3e1e8"       # Lighter foam
    [success-strong]="#5e7c82"       # Strong success (40% darker)
    [warning-strong]="#ea9d34"       # Darker gold
    [error-strong]="#d84f76"         # Darker love
    [info-subtle]="#5aadcb"          # Lighter pine
    [info-strong]="#2d7a95"          # Darker pine
    [error-subtle]="#f092ad"         # Lighter love
    [warning-subtle]="#f8d5a8"       # Lighter gold

    # System Colors
    [white]="#ffffff"                # Text
    [black]="#232136"                # Base
)

export THEME_COLORS
