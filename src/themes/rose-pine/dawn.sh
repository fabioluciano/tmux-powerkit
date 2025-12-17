#!/usr/bin/env bash

# Rosé Pine Dawn Theme - PowerKit Semantic Color Mapping
# Based on https://rosepinetheme.com/
# Light variant - All natural pine, faux fur and a bit of soho vibes

declare -A THEME_COLORS=(
    # Core System Colors
    [transparent]="NONE"
    [none]="NONE"

    # Background Colors
    [background]="#faf4ed"           # Base
    [background-alt]="#fffaf3"       # Surface
    [surface]="#f2e9e1"              # Overlay
    [overlay]="#dfdad9"              # Muted

    # Text Colors
    [text]="#575279"                 # Text
    [text-muted]="#797593"           # Subtle
    [text-disabled]="#9893a5"        # Muted

    # Border Colors
    [border]="#f2e9e1"               # Overlay
    [border-subtle]="#fffaf3"        # Surface
    [border-strong]="#cecacd"        # Highlight Med

    # Semantic Colors (PowerKit Standard)
    [accent]="#907aa9"               # Iris - Main accent
    [primary]="#d7827e"              # Rose - Primary
    [secondary]="#f2e9e1"            # Overlay - Secondary
    [secondary-strong]="#fffaf3"     # Surface - Strong secondary

    # Status Colors (PowerKit Standard)
    [success]="#56949f"              # Foam
    [warning]="#ea9d34"              # Gold
    [error]="#b4637a"                # Love
    [info]="#286983"                 # Pine

    # Interactive States
    [hover]="#fffaf3"                # Surface - Hover state
    [active]="#d7827e"               # Rose - Active state
    [focus]="#907aa9"                # Iris - Focus state
    [disabled]="#9893a5"             # Muted - Disabled state

    # Additional Variants
    [success-subtle]="#6bb0bc"       # Lighter foam
    [success-strong]="#34595f"       # Strong success (40% darker)
    [warning-strong]="#c77f20"       # Darker gold
    [error-strong]="#9a4f64"         # Darker love
    [info-subtle]="#3a8aa6"          # Lighter pine
    [info-strong]="#1d5469"          # Darker pine
    [error-subtle]="#c87d8e"         # Lighter love
    [warning-subtle]="#f0b85b"       # Lighter gold

    # System Colors
    [white]="#ffffff"                # Base (lightest in light theme)
    [black]="#575279"                # Text (darkest in light theme)
)

export THEME_COLORS
