#!/usr/bin/env bash
# =============================================================================
# Theme: Solarized
# Variant: Dark
# Description: Precision colors for machines and people
# Source: https://ethanschoonover.com/solarized/
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#073642"
    [statusbar-fg]="#93a1a1"

    # Session
    [session-bg]="#859900"
    [session-fg]="#002b36"
    [session-prefix-bg]="#b58900"
    [session-copy-bg]="#2aa198"

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#268bd2"
    [window-inactive-base]="#586e75"

    # Pane Borders
    [pane-border-active]="#268bd2"
    [pane-border-inactive]="#586e75"

    # Health States (base colors - variants auto-generated)
    [ok-base]="#073642"
    [good-base]="#859900"
    [info-base]="#2aa198"
    [warning-base]="#b58900"
    [error-base]="#dc322f"
    [disabled-base]="#586e75"

    # Messages
    [message-bg]="#073642"
    [message-fg]="#93a1a1"

)
