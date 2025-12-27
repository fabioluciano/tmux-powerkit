#!/usr/bin/env bash
# =============================================================================
# Theme: One Dark
# Variant: Dark
# Description: A dark syntax theme inspired by Atom
# Source: https://atom.io/themes/one-dark-syntax
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#2c323c"      # cursor grey
    [statusbar-fg]="#abb2bf"      # white

    # Session (blue = signature OneDark color)
    [session-bg]="#61afef"        # blue
    [session-fg]="#282c34"        # black
    [session-prefix-bg]="#e5c07b" # yellow
    [session-copy-bg]="#56b6c2"   # cyan

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#c678dd"  # purple
    [window-inactive-base]="#3e4451" # visual grey

    # Pane Borders
    [pane-border-active]="#61afef"  # blue
    [pane-border-inactive]="#3e4451" # visual grey

    # Health States (base colors - variants auto-generated)
    [ok-base]="#2c323c"           # cursor grey
    [good-base]="#98c379"         # green ✓
    [info-base]="#56b6c2"         # cyan (blue) ✓
    [warning-base]="#e5c07b"      # yellow ✓
    [error-base]="#e06c75"        # red ✓
    [disabled-base]="#5c6370"     # comment grey

    # Messages
    [message-bg]="#2c323c"        # cursor grey
    [message-fg]="#abb2bf"        # white

)
