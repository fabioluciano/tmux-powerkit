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
    [secondary]="#3b4252"            # nord1 - Secondary (plugin content bg)
    [secondary-strong]="#2e3440"     # nord0 - Strong secondary (darker)

    # Status Colors (PowerKit Standard)
    [success]="#a3be8c"              # nord14 - Success (aurora green)
    [warning]="#ebcb8b"              # nord13 - Warning (aurora yellow - original)
    [error]="#bf616a"                # nord11 - Error (aurora red)
    [info]="#81a1c1"                 # nord9 - Info (frost blue)

    # Interactive States
    [hover]="#434c5e"                # nord2 - Hover state
    [active]="#4c566a"               # nord3 - Active state (icon bg, lighter than secondary)
    [focus]="#88c0d0"                # nord8 - Focus state
    [disabled]="#4c566a"             # nord3 - Disabled state

    # Additional Variants
    [success-subtle]="#b4caa1"       # Subtle success (18.9% lighter)
    [success-strong]="#5a6a4e"       # Strong success (44.2% darker)
    [warning-strong]="#83714d"       # Strong warning (44.2% darker)
    [error-strong]="#6a363b"         # Strong error (44.2% darker)
    [info-subtle]="#9ecbd8"          # Subtle info (18.9% lighter)
    [info-strong]="#4b6b74"          # Strong info (44.2% darker)
    [error-subtle]="#cb7e86"         # Subtle error (18.9% lighter)
    [warning-subtle]="#efd5a3"       # Subtle warning (18.9% lighter)

    # System Colors
    [white]="#ffffff"                # nord6
    [black]="#2e3440"                # nord0
)

export THEME_COLORS
