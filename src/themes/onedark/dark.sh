#!/usr/bin/env bash

# One Dark Theme - PowerKit Semantic Color Mapping
# Based on Atom's One Dark theme
# A dark syntax theme inspired by Atom

declare -A THEME_COLORS=(
    # Core System Colors
    [transparent]="NONE"
    [none]="NONE"

    # Background Colors
    [background]="#282c34"           # Main background
    [background-alt]="#21252b"       # Darker background
    [surface]="#2c323c"              # Surface/card background
    [overlay]="#3e4451"              # Overlay/modal background

    # Text Colors
    [text]="#abb2bf"                 # Primary text
    [text-muted]="#5c6370"           # Comment/muted text
    [text-disabled]="#4b5263"        # Disabled text

    # Border Colors
    [border]="#3e4451"               # Default border
    [border-subtle]="#2c323c"        # Subtle border
    [border-strong]="#5c6370"        # Strong border

    # Semantic Colors (PowerKit Standard)
    [accent]="#61afef"               # Blue - Main accent
    [primary]="#c678dd"              # Magenta - Primary
    [secondary]="#3e4451"            # Gray - Secondary
    [secondary-strong]="#2c323c"     # Darker gray

    # Status Colors (PowerKit Standard)
    [success]="#98c379"              # Green
    [warning]="#e7c78b"              # Yellow (13% lighter)
    [error]="#e06c75"                # Red
    [info]="#56b6c2"                 # Cyan

    # Interactive States
    [hover]="#2c323c"                # Hover state
    [active]="#528bff"               # Active state (accent blue)
    [focus]="#61afef"                # Focus state
    [disabled]="#5c6370"             # Disabled state

    # Additional Variants
    [success-subtle]="#abce92"       # Subtle success (18.9% lighter)
    [success-strong]="#546c43"       # Strong success (44.2% darker)
    [warning-strong]="#806f4d"       # Strong warning (44.2% darker)
    [error-strong]="#7c3c41"         # Strong error (44.2% darker)
    [info-subtle]="#75c3cd"          # Subtle info (18.9% lighter)
    [info-strong]="#2f656c"          # Strong info (44.2% darker)
    [error-subtle]="#e5878f"         # Subtle error (18.9% lighter)
    [warning-subtle]="#ebd1a0"       # Subtle warning (18.9% lighter)

    # System Colors
    [white]="#ffffff"                # Pure white
    [black]="#282c34"                # Background
)

export THEME_COLORS
