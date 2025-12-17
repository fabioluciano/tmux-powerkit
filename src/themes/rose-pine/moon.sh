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
    [warning]="#f6c887"              # Gold (13% lighter)
    [error]="#eb6f92"                # Love
    [info]="#3e8fb0"                 # Pine

    # Interactive States
    [hover]="#2a273f"                # Surface - Hover state
    [active]="#ea9a97"               # Rose - Active state
    [focus]="#c4a7e7"                # Iris - Focus state
    [disabled]="#6e6a86"             # Muted - Disabled state

    # Additional Variants
    [success-subtle]="#aed8df"       # Subtle success (18.9% lighter)
    [success-strong]="#577378"       # Strong success (44.2% darker)
    [warning-strong]="#896f4b"       # Strong warning (44.2% darker)
    [error-strong]="#833d51"         # Strong error (44.2% darker)
    [info-subtle]="#aed8df"          # Subtle info (18.9% lighter)
    [info-strong]="#577378"          # Strong info (44.2% darker)
    [error-subtle]="#ee8aa6"         # Subtle error (18.9% lighter)
    [warning-subtle]="#f7d29d"       # Subtle warning (18.9% lighter)

    # System Colors
    [white]="#ffffff"                # Text
    [black]="#232136"                # Base
)

export THEME_COLORS
