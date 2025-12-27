#!/usr/bin/env bash
# =============================================================================
# Theme: GitHub
# Variant: Dark
# Description: GitHub's Primer design system - Dark Default
# Source: https://primer.style/design
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#161b22"      # canvas subtle
    [statusbar-fg]="#e6edf3"      # fg default

    # Session (blue = signature GitHub accent)
    [session-bg]="#58a6ff"        # accent blue
    [session-fg]="#0d1117"        # canvas default
    [session-prefix-bg]="#d29922" # attention yellow
    [session-copy-bg]="#a371f7"   # done purple

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#a371f7"  # done purple
    [window-inactive-base]="#30363d" # canvas overlay

    # Pane Borders
    [pane-border-active]="#58a6ff"  # accent blue
    [pane-border-inactive]="#30363d" # canvas overlay

    # Health States (base colors - variants auto-generated)
    [ok-base]="#30363d"           # canvas overlay
    [good-base]="#3fb950"         # success green ✓
    [info-base]="#58a6ff"         # accent blue ✓
    [warning-base]="#d29922"      # attention yellow ✓
    [error-base]="#f85149"        # danger red ✓
    [disabled-base]="#6e7681"     # muted

    # Messages
    [message-bg]="#161b22"        # canvas subtle
    [message-fg]="#e6edf3"        # fg default

)
