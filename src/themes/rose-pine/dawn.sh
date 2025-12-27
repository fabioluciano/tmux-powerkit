#!/usr/bin/env bash
# =============================================================================
# Theme: Rose Pine
# Variant: Dawn
# Description: Light variant with natural pine vibes
# Source: https://rosepinetheme.com/
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#f2e9e1"      # overlay
    [statusbar-fg]="#575279"      # text (approximation)

    # Session (iris = signature Rose Pine purple)
    [session-bg]="#907aa9"        # iris
    [session-fg]="#faf4ed"        # base
    [session-prefix-bg]="#ea9d34" # gold
    [session-copy-bg]="#286983"   # pine

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#d7827e"  # rose
    [window-inactive-base]="#dfdad9" # surface (approximation)

    # Pane Borders
    [pane-border-active]="#907aa9"  # iris
    [pane-border-inactive]="#dfdad9" # surface

    # Health States (base colors - variants auto-generated)
    [ok-base]="#797593"           # subtle
    [good-base]="#56949f"         # foam ✓
    [info-base]="#286983"         # pine (blue) ✓
    [warning-base]="#ea9d34"      # gold (yellow) ✓
    [error-base]="#b4637a"        # love (red) ✓
    [disabled-base]="#9893a5"     # muted

    # Messages
    [message-bg]="#f2e9e1"        # overlay
    [message-fg]="#575279"        # text

)
