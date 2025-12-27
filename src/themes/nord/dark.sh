#!/usr/bin/env bash
# =============================================================================
# Theme: Nord
# Variant: Dark
# Description: Arctic, north-bluish color palette
# Source: https://www.nordtheme.com/
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#434c5e"      # nord2
    [statusbar-fg]="#eceff4"      # nord6

    # Session (Frost blues = signature Nord colors)
    [session-bg]="#88c0d0"        # nord8 (frost)
    [session-fg]="#2e3440"        # nord0
    [session-prefix-bg]="#d08770" # nord12 (orange)
    [session-copy-bg]="#5e81ac"   # nord10 (dark blue)

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#81a1c1"  # nord9 (blue)
    [window-inactive-base]="#4c566a" # nord3

    # Pane Borders
    [pane-border-active]="#88c0d0"  # nord8
    [pane-border-inactive]="#4c566a" # nord3

    # Health States (base colors - variants auto-generated)
    [ok-base]="#3b4252"           # nord1
    [good-base]="#a3be8c"         # nord14 (green) ✓
    [info-base]="#81a1c1"         # nord9 (blue) ✓
    [warning-base]="#ebcb8b"      # nord13 (yellow) ✓
    [error-base]="#bf616a"        # nord11 (red) ✓
    [disabled-base]="#4c566a"     # nord3

    # Messages
    [message-bg]="#434c5e"        # nord2
    [message-fg]="#eceff4"        # nord6

)
