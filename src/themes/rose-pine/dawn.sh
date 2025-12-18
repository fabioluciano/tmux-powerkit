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
    [border]="#dfdad9"               # Muted (inactive window content bg)
    [border-subtle]="#cecacd"        # Highlight Med (inactive window index bg - visible on surface)
    [border-strong]="#9893a5"        # Muted text - Strong border

    # Semantic Colors (PowerKit Standard)
    [accent]="#907aa9"               # Iris - Main accent
    [primary]="#d7827e"              # Rose - Primary
    [secondary]="#797593"            # Subtle - Secondary (dark for white text)
    [secondary-strong]="#575279"     # Text - Strong secondary (darker)

    # Status Colors (PowerKit Standard)
    [success]="#56949f"              # Foam
    [warning]="#ea9d34"              # Gold (original rose-pine)
    [error]="#b4637a"                # Love
    [info]="#286983"                 # Pine

    # Interactive States
    [hover]="#fffaf3"                # Surface - Hover state
    [active]="#6e6a86"               # Highlight High - Active state (icon bg)
    [focus]="#907aa9"                # Iris - Focus state
    [disabled]="#9893a5"             # Muted - Disabled state

    # Additional Variants
    [success-subtle]="#75a8b1"       # Subtle success (18.9% lighter)
    [success-strong]="#2f5258"       # Strong success (44.2% darker)
    [warning-strong]="#835d2a"       # Strong warning (44.2% darker)
    [error-strong]="#643744"         # Strong error (44.2% darker)
    [info-subtle]="#75a8b1"          # Subtle info (18.9% lighter)
    [info-strong]="#2f5258"          # Strong info (44.2% darker)
    [error-subtle]="#c28093"         # Subtle error (18.9% lighter)
    [warning-subtle]="#efb86e"       # Subtle warning (18.9% lighter)

    # System Colors
    [white]="#ffffff"                # Base (lightest in light theme)
    [black]="#575279"                # Text (darkest in light theme)
)

export THEME_COLORS
