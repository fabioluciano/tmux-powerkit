#!/usr/bin/env bash
# =============================================================================
# Theme: Everforest
# Variant: Light
# Description: Soft, paper-like light theme
# Source: https://github.com/sainnhe/everforest
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#efebd4"      # bg2
    [statusbar-fg]="#5c6a72"      # fg

    # Session (green = signature Everforest color)
    [session-bg]="#8da101"        # green
    [session-fg]="#fdf6e3"        # bg0
    [session-prefix-bg]="#f57d26" # orange
    [session-copy-bg]="#3a94c5"   # blue

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#df69ba"  # purple
    [window-inactive-base]="#e6e2cc" # bg3

    # Pane Borders
    [pane-border-active]="#8da101"  # green
    [pane-border-inactive]="#e6e2cc" # bg3

    # Health States (base colors - variants auto-generated)
    [ok-base]="#829181"           # grey2
    [good-base]="#8da101"         # green ✓
    [info-base]="#3a94c5"         # blue ✓
    [warning-base]="#dfa000"      # yellow ✓
    [error-base]="#f85552"        # red ✓
    [disabled-base]="#939f91"     # grey1

    # Messages
    [message-bg]="#efebd4"        # bg2
    [message-fg]="#5c6a72"        # fg

)
