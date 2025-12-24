#!/usr/bin/env bash
# =============================================================================
# Theme: Solarized
# Variant: Light
# Description: Precision colors for machines and people - light variant
# Source: https://ethanschoonover.com/solarized/
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#eee8d5"
    [statusbar-fg]="#073642"

    # Session
    [session-bg]="#859900"
    [session-fg]="#fdf6e3"
    [session-prefix-bg]="#b58900"
    [session-copy-bg]="#2aa198"

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#268bd2"
    [window-inactive-base]="#93a1a1"

    # Pane Borders
    [pane-border-active]="#268bd2"
    [pane-border-inactive]="#93a1a1"

    # Health States (base colors - variants auto-generated)
    [ok-base]="#586e75"
    [good-base]="#859900"
    [info-base]="#2aa198"
    [warning-base]="#b58900"
    [error-base]="#dc322f"
    [disabled-base]="#93a1a1"

    # Messages
    [message-bg]="#eee8d5"
    [message-fg]="#073642"

)
