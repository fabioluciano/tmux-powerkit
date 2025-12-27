#!/usr/bin/env bash
# =============================================================================
# Theme: Rose Pine
# Variant: Main
# Description: All natural pine, faux fur and a bit of soho vibes
# Source: https://rosepinetheme.com/
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#26233a"      # overlay
    [statusbar-fg]="#e0def4"      # text

    # Session (iris = signature Rose Pine purple)
    [session-bg]="#c4a7e7"        # iris
    [session-fg]="#191724"        # base
    [session-prefix-bg]="#f6c177" # gold
    [session-copy-bg]="#31748f"   # pine

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#ebbcba"  # rose
    [window-inactive-base]="#26233a" # overlay

    # Pane Borders
    [pane-border-active]="#c4a7e7"  # iris
    [pane-border-inactive]="#26233a" # overlay

    # Health States (base colors - variants auto-generated)
    [ok-base]="#1f1d2e"           # surface
    [good-base]="#9ccfd8"         # foam ✓
    [info-base]="#31748f"         # pine (blue) ✓
    [warning-base]="#f6c177"      # gold (yellow) ✓
    [error-base]="#eb6f92"        # love (red) ✓
    [disabled-base]="#6e6a86"     # muted

    # Messages
    [message-bg]="#26233a"        # overlay
    [message-fg]="#e0def4"        # text

)
