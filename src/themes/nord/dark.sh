#!/usr/bin/env bash

# Nord Theme - PowerKit Semantic Color Mapping
# Based on https://www.nordtheme.com/
# Arctic, north-bluish color palette

declare -A THEME_COLORS=(
    # Core System Colors
    [transparent]="NONE"
    [none]="NONE"

    # Background Colors (Polar Night)
    [background]="#2e3440"           # nord0 - Main background
    [background-alt]="#3b4252"       # nord1 - Alternative background
    [surface]="#434c5e"              # nord2 - Surface/card background
    [overlay]="#4c566a"              # nord3 - Overlay/modal background

    # Text Colors (Snow Storm)
    [text]="#eceff4"                 # nord6 - Primary text (brightest)
    [text-muted]="#d8dee9"           # nord4 - Muted text
    [text-disabled]="#4c566a"        # nord3 - Disabled text

    # Border Colors
    [border]="#4c566a"               # nord3 - Default border
    [border-subtle]="#434c5e"        # nord2 - Subtle border
    [border-strong]="#d8dee9"        # nord4 - Strong border

    # Semantic Colors (PowerKit Standard)
    [accent]="#88c0d0"               # nord8 - Main accent (frost cyan)
    [primary]="#5e81ac"              # nord10 - Primary (deep blue)
    [secondary]="#4c566a"            # nord3 - Secondary
    [secondary-strong]="#3b4252"     # nord1 - Strong secondary

    # Status Colors (PowerKit Standard)
    [success]="#a3be8c"              # nord14 - Success (aurora green)
    [warning]="#ebcb8b"              # nord13 - Warning (aurora yellow)
    [error]="#bf616a"                # nord11 - Error (aurora red)
    [info]="#81a1c1"                 # nord9 - Info (frost blue)

    # Interactive States
    [hover]="#434c5e"                # nord2 - Hover state
    [active]="#5e81ac"               # nord10 - Active state
    [focus]="#88c0d0"                # nord8 - Focus state
    [disabled]="#4c566a"             # nord3 - Disabled state

    # Additional Variants
    [success-subtle]="#8fbcbb"       # nord7 - Subtle success
    [success-strong]="#627254"       # Strong success (40% darker) (frost teal)
    [warning-strong]="#d08770"       # nord12 - Strong warning (aurora orange)
    [error-strong]="#a54a52"         # Darker red
    [info-subtle]="#b48ead"          # nord15 - Subtle info (aurora purple)
    [info-strong]="#5e81ac"          # nord10 - Strong info
    [error-subtle]="#d57a82"         # Lighter red
    [warning-subtle]="#f0d9a8"       # Lighter yellow

    # System Colors
    [white]="#ffffff"                # nord6
    [black]="#2e3440"                # nord0
)

export THEME_COLORS
