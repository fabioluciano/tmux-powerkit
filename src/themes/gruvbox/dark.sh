#!/usr/bin/env bash
# =============================================================================
# Theme: Gruvbox
# Variant: Dark
# Description: Retro groove color scheme - dark variant
# Source: https://github.com/morhetz/gruvbox
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#3c3836"
    [statusbar-fg]="#ebdbb2"

    # Session
    [session-bg]="#98971a"
    [session-fg]="#282828"
    [session-prefix-bg]="#d79921"
    [session-copy-bg]="#458588"

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#d79921"
    [window-inactive-base]="#504945"

    # Pane Borders
    [pane-border-active]="#d79921"
    [pane-border-inactive]="#504945"

    # Health States (base colors - variants auto-generated)
    [ok-base]="#504945"
    [good-base]="#98971a"
    [info-base]="#458588"
    [warning-base]="#d79921"
    [error-base]="#cc241d"
    [disabled-base]="#665c54"

    # Messages
    [message-bg]="#3c3836"
    [message-fg]="#ebdbb2"

)
