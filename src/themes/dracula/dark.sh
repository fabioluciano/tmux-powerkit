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
    [warning]="#ffc07d"              # Orange (13% lighter)
    [error]="#ff5555"                # Red
    [info]="#8be9fd"                 # Cyan

    # Interactive States
    [hover]="#44475a"                # Current Line
    [active]="#ff79c6"               # Pink
    [focus]="#bd93f9"                # Purple
    [disabled]="#6272a4"             # Comment

    # Additional Variants
    [success-subtle]="#71fa93"       # Subtle success (18.9% lighter)
    [success-strong]="#2c8b44"       # Strong success (44.2% darker)
    [warning-strong]="#8e6b45"       # Strong warning (44.2% darker)
    [error-strong]="#8e2f2f"         # Strong error (44.2% darker)
    [info-subtle]="#a0edfd"          # Subtle info (18.9% lighter)
    [info-strong]="#4d828d"          # Strong info (44.2% darker)
    [error-subtle]="#ff7575"         # Subtle error (18.9% lighter)
    [warning-subtle]="#ffcb95"       # Subtle warning (18.9% lighter)

    # System Colors
    [white]="#ffffff"                # Foreground
    [black]="#282a36"                # Background
)

export THEME_COLORS
