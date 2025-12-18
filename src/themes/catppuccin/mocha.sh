#!/usr/bin/env bash

# Catppuccin Mocha Theme - PowerKit Semantic Color Mapping
# Based on https://github.com/catppuccin/catppuccin
# Soothing pastel theme for the high-spirited!

declare -A THEME_COLORS=(
    # Core System Colors
    [transparent]="NONE"
    [none]="NONE"

    # Background Colors
    [background]="#1e1e2e"           # Base
    [background-alt]="#181825"       # Mantle
    [surface]="#313244"              # Surface0
    [overlay]="#45475a"              # Surface1

    # Text Colors
    [text]="#cdd6f4"                 # Text
    [text-muted]="#a6adc8"           # Subtext0
    [text-disabled]="#6c7086"        # Overlay1

    # Border Colors
    [border]="#45475a"               # Surface1
    [border-subtle]="#313244"        # Surface0
    [border-strong]="#585b70"        # Surface2

    # Semantic Colors (PowerKit Standard)
    [accent]="#cba6f7"               # Mauve - Main accent
    [primary]="#89b4fa"              # Blue - Primary
    [secondary]="#313244"            # Surface0 - Secondary (plugin content bg)
    [secondary-strong]="#1e1e2e"     # Base - Strong secondary (darker)

    # Status Colors (PowerKit Standard)
    [success]="#a6e3a1"              # Green
    [warning]="#f9e2af"              # Yellow - Warning (original catppuccin)
    [error]="#f38ba8"                # Red
    [info]="#89dceb"                 # Sky

    # Interactive States
    [hover]="#313244"                # Surface0 - Hover state
    [active]="#585b70"               # Surface2 - Active state (icon bg, lighter than secondary)
    [focus]="#b4befe"                # Lavender - Focus state
    [disabled]="#6c7086"             # Overlay1 - Disabled state

    # Additional Variants
    [success-subtle]="#b6e8b2"       # Subtle success (18.9% lighter)
    [success-strong]="#5c7e59"       # Strong success (44.2% darker)
    [warning-strong]="#8b7e61"       # Strong warning (44.2% darker)
    [error-strong]="#874d5d"         # Strong error (44.2% darker)
    [info-subtle]="#9fe2ee"          # Subtle info (18.9% lighter)
    [info-strong]="#4c7a83"          # Strong info (44.2% darker)
    [error-subtle]="#f5a0b8"         # Subtle error (18.9% lighter)
    [warning-subtle]="#fae7c0"       # Subtle warning (18.9% lighter)

    # System Colors
    [white]="#ffffff"                # Text
    [black]="#11111b"                # Crust
)

export THEME_COLORS
