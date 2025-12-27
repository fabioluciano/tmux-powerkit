#!/usr/bin/env bash
# =============================================================================
# Theme: GitHub
# Variant: Light
# Description: GitHub's Primer design system - Light Default
# Source: https://primer.style/design
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#eaeef2"      # canvas subtle
    [statusbar-fg]="#24292f"      # fg default

    # Session (blue = signature GitHub accent)
    [session-bg]="#0969da"        # accent blue
    [session-fg]="#ffffff"        # white
    [session-prefix-bg]="#9a6700" # attention yellow
    [session-copy-bg]="#8250df"   # done purple

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#8250df"  # done purple
    [window-inactive-base]="#d0d7de" # canvas inset

    # Pane Borders
    [pane-border-active]="#0969da"  # accent blue
    [pane-border-inactive]="#d0d7de" # canvas inset

    # Health States (base colors - variants auto-generated)
    [ok-base]="#57606a"           # fg muted
    [good-base]="#1a7f37"         # success green ✓
    [info-base]="#0969da"         # accent blue ✓
    [warning-base]="#9a6700"      # attention yellow ✓
    [error-base]="#cf222e"        # danger red ✓
    [disabled-base]="#8c959f"     # muted

    # Messages
    [message-bg]="#eaeef2"        # canvas subtle
    [message-fg]="#24292f"        # fg default

)
