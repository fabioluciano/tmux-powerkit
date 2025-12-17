#!/usr/bin/env bash

# Dracula Theme - PowerKit Semantic Color Mapping
# Based on https://draculatheme.com/
# A dark theme for vampires

declare -A THEME_COLORS=(
    # Core System Colors
    [transparent]="NONE"
    [none]="NONE"

    # Background Colors
    [background]="#282a36"           # Background
    [background-alt]="#21222c"       # Darker background
    [surface]="#44475a"              # Current Line
    [overlay]="#6272a4"              # Comment (used for overlays)

    # Text Colors
    [text]="#f8f8f2"                 # Foreground
    [text-muted]="#6272a4"           # Comment
    [text-disabled]="#44475a"        # Current Line (dimmed)

    # Border Colors
    [border]="#44475a"               # Current Line
    [border-subtle]="#6272a4"        # Comment
    [border-strong]="#bd93f9"        # Purple

    # Semantic Colors (PowerKit Standard)
    [accent]="#bd93f9"               # Purple - Main accent
    [primary]="#ff79c6"              # Pink - Primary
    [secondary]="#44475a"            # Current Line - Secondary
    [secondary-strong]="#21222c"     # Darker background

    # Status Colors (PowerKit Standard)
    [success]="#50fa7b"              # Green
    [warning]="#ffb86c"              # Orange
    [error]="#ff5555"                # Red
    [info]="#8be9fd"                 # Cyan

    # Interactive States
    [hover]="#44475a"                # Current Line
    [active]="#ff79c6"               # Pink
    [focus]="#bd93f9"                # Purple
    [disabled]="#6272a4"             # Comment

    # Additional Variants
    [success-subtle]="#69ff94"       # Lighter green
    [success-strong]="#30964a"       # Strong success (40% darker)
    [warning-strong]="#ff9e64"       # Darker orange
    [error-strong]="#ff3333"         # Darker red
    [info-subtle]="#a4ffff"          # Lighter cyan
    [info-strong]="#59c2c6"          # Darker cyan
    [error-subtle]="#ff7777"         # Lighter red
    [warning-subtle]="#ffcc99"       # Lighter orange

    # System Colors
    [white]="#ffffff"                # Foreground
    [black]="#282a36"                # Background
)

export THEME_COLORS
