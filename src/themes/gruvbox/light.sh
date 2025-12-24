#!/usr/bin/env bash
# =============================================================================
# Theme: Gruvbox
# Variant: Light
# Description: Retro groove color scheme - light variant
# Source: https://github.com/morhetz/gruvbox
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#ebdbb2"
    [statusbar-fg]="#3c3836"

    # Session
    [session-bg]="#79740e"
    [session-fg]="#fbf1c7"
    [session-prefix-bg]="#b57614"
    [session-copy-bg]="#076678"

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#b57614"
    [window-inactive-base]="#d5c4a1"

    # Pane Borders
    [pane-border-active]="#b57614"
    [pane-border-inactive]="#d5c4a1"

    # Health States (base colors - variants auto-generated)
    [ok-base]="#665c54"
    [good-base]="#79740e"
    [info-base]="#076678"
    [warning-base]="#b57614"
    [error-base]="#9d0006"
    [disabled-base]="#bdae93"

    # Messages
    [message-bg]="#ebdbb2"
    [message-fg]="#3c3836"

)
