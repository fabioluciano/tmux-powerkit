#!/usr/bin/env bash
# Pastel Dark Theme
# Based on soft pastel color palette with dark background

declare -A THEME_COLORS=(
    # Core System Colors
    [transparent]="NONE"
    [none]="NONE"

    # Background Colors
    [background]="#1a1b26"
    [background-alt]="#16161e"
    [surface]="#24283b"
    [overlay]="#3b4261"

    # Text Colors
    [text]="#c0caf5"
    [text-muted]="#565f89"
    [text-disabled]="#414868"

    # Border Colors
    [border]="#414868"
    [border-subtle]="#32344a"
    [border-strong]="#545c7e"

    # Semantic Colors
    [accent]="#e88fb5"
    [primary]="#f4a799"
    [secondary]="#3b4261"
    [secondary-strong]="#2d3348"
    [secondary-subtle]="#515978"     # Subtle secondary (18.9% lighter)

    # Status Colors
    [success]="#c5e89f"
    [warning]="#f4e8c1"
    [error]="#f4a799"
    [info]="#f4c4a0"

    # Interactive States
    [hover]="#2d3f76"
    [active]="#4d6191"
    [focus]="#e88fb5"
    [disabled]="#565f89"
    [disabled-subtle]="#6f78a0"      # Subtle disabled (18.9% lighter)
    [disabled-strong]="#30354c"      # Strong disabled (44.2% darker)

    # Subtle Variants
    [primary-subtle]="#f8c4b4"
    [success-subtle]="#d4f0b8"
    [warning-subtle]="#f9f0d5"
    [error-subtle]="#f8c4b4"
    [info-subtle]="#f9dac4"

    # Strong Variants
    [primary-strong]="#c4735f"
    [success-strong]="#8fb36f"
    [warning-strong]="#c4b891"
    [error-strong]="#c4735f"
    [info-strong]="#c48470"

    # System Colors
    [white]="#ffffff"
    [black]="#000000"
)

export THEME_COLORS
