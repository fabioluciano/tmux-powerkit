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
    [warning]="#e5c07b"              # Yellow
    [error]="#e06c75"                # Red
    [info]="#56b6c2"                 # Cyan

    # Interactive States
    [hover]="#2c323c"                # Hover state
    [active]="#528bff"               # Active state (accent blue)
    [focus]="#61afef"                # Focus state
    [disabled]="#5c6370"             # Disabled state

    # Additional Variants
    [success-subtle]="#aed095"       # Lighter green
    [success-strong]="#5b7548"       # Strong success (40% darker)
    [warning-strong]="#d19a66"       # Orange (darker warm)
    [error-strong]="#be5046"         # Dark red
    [info-subtle]="#7ec8d3"          # Lighter cyan
    [info-strong]="#3e9ca8"          # Darker cyan
    [error-subtle]="#e88993"         # Lighter red
    [warning-subtle]="#ecd1a0"       # Lighter yellow

    # System Colors
    [white]="#ffffff"                # Pure white
    [black]="#282c34"                # Background
)

export THEME_COLORS
