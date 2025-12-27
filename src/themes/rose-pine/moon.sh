#!/usr/bin/env bash
# =============================================================================
# Theme: Rose Pine
# Variant: Moon
# Description: Darker variant with natural pine vibes
# Source: https://rosepinetheme.com/
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#393552"      # overlay
    [statusbar-fg]="#e0def4"      # text

    # Session (iris = signature Rose Pine purple)
    [session-bg]="#c4a7e7"        # iris
    [session-fg]="#232136"        # base
    [session-prefix-bg]="#f6c177" # gold
    [session-copy-bg]="#3e8fb0"   # pine

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#ea9a97"  # rose
    [window-inactive-base]="#393552" # overlay

    # Pane Borders
    [pane-border-active]="#c4a7e7"  # iris
    [pane-border-inactive]="#393552" # overlay

    # Health States (base colors - variants auto-generated)
    [ok-base]="#2a273f"           # surface
    [good-base]="#9ccfd8"         # foam ✓
    [info-base]="#3e8fb0"         # pine (blue) ✓
    [warning-base]="#f6c177"      # gold (yellow) ✓
    [error-base]="#eb6f92"        # love (red) ✓
    [disabled-base]="#6e6a86"     # muted

    # Messages
    [message-bg]="#393552"        # overlay
    [message-fg]="#e0def4"        # text

)
