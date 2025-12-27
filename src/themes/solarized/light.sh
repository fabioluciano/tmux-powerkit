#!/usr/bin/env bash
# =============================================================================
# Theme: Solarized
# Variant: Light
# Description: Precision colors for machines and people - light variant
# Source: https://ethanschoonover.com/solarized/
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#eee8d5"      # base2
    [statusbar-fg]="#073642"      # base02

    # Session (blue = signature Solarized accent)
    [session-bg]="#268bd2"        # blue
    [session-fg]="#fdf6e3"        # base3
    [session-prefix-bg]="#cb4b16" # orange
    [session-copy-bg]="#2aa198"   # cyan

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#6c71c4"  # violet
    [window-inactive-base]="#93a1a1" # base1

    # Pane Borders
    [pane-border-active]="#268bd2"  # blue
    [pane-border-inactive]="#93a1a1" # base1

    # Health States (base colors - variants auto-generated)
    [ok-base]="#586e75"           # base01
    [good-base]="#859900"         # green ✓
    [info-base]="#2aa198"         # cyan (blue) ✓
    [warning-base]="#b58900"      # yellow ✓
    [error-base]="#dc322f"        # red ✓
    [disabled-base]="#93a1a1"     # base1

    # Messages
    [message-bg]="#eee8d5"        # base2
    [message-fg]="#073642"        # base02

)
