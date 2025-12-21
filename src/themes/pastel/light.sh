#!/usr/bin/env bash
# Pastel Light Theme
# Based on soft pastel color palette

declare -A THEME_COLORS=(
    # Core System Colors
    [transparent]="NONE"
    [none]="NONE"

    # Background Colors
    [background]="#fafafa"
    [background-alt]="#ffffff"
    [surface]="#f0f0f0"
    [overlay]="#e8e8e8"

    # Text Colors
    [text]="#2e3440"
    [text-muted]="#6e7681"
    [text-disabled]="#9da5b3"

    # Border Colors
    [border]="#d8d8d8"
    [border-subtle]="#e8e8e8"
    [border-strong]="#b8b8b8"

    # Semantic Colors
    [accent]="#e88fb5"
    [primary]="#f4a799"
    [secondary]="#e0e0e0"
    [secondary-strong]="#d0d0d0"
    [secondary-subtle]="#e8e8e8"     # Subtle secondary (18.9% lighter)

    # Status Colors
    [success]="#c5e89f"
    [warning]="#f4e8c1"
    [error]="#f4a799"
    [info]="#f4c4a0"

    # Interactive States
    [hover]="#f5f5f5"
    [active]="#d8d8d8"
    [focus]="#e88fb5"
    [disabled]="#c0c0c0"
    [disabled-subtle]="#cfcfcf"      # Subtle disabled (18.9% lighter)
    [disabled-strong]="#6b6b6b"      # Strong disabled (44.2% darker)

    # Subtle Variants
    [primary-subtle]="#fce8f2"
    [success-subtle]="#f2f9e8"
    [warning-subtle]="#fef9ef"
    [error-subtle]="#fef2f0"
    [info-subtle]="#fef5ed"

    # Strong Variants
    [primary-strong]="#b35f73"
    [success-strong]="#95b86f"
    [warning-strong]="#c4b891"
    [error-strong]="#b35f73"
    [info-strong]="#b38470"

    # System Colors
    [white]="#ffffff"
    [black]="#000000"
)

export THEME_COLORS
