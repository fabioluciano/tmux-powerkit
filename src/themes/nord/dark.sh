#!/usr/bin/env bash
# =============================================================================
# Theme: Nord
# Variant: Dark
# Description: Arctic, north-bluish color palette
# Source: https://www.nordtheme.com/
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#434c5e"
    [statusbar-fg]="#eceff4"

    # Session
    [session-bg]="#a3be8c"
    [session-fg]="#2e3440"
    [session-prefix-bg]="#ebcb8b"
    [session-copy-bg]="#81a1c1"

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#88c0d0"
    [window-inactive-base]="#4c566a"

    # Pane Borders
    [pane-border-active]="#88c0d0"
    [pane-border-inactive]="#4c566a"

    # Health States (base colors - variants auto-generated)
    [ok-base]="#3b4252"
    [good-base]="#a3be8c"
    [info-base]="#81a1c1"
    [warning-base]="#ebcb8b"
    [error-base]="#bf616a"
    [disabled-base]="#4c566a"

    # Messages
    [message-bg]="#434c5e"
    [message-fg]="#eceff4"

)
