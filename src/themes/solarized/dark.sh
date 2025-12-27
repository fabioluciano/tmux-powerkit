#!/usr/bin/env bash
# =============================================================================
# Theme: Solarized
# Variant: Dark
# Description: Precision colors for machines and people
# Source: https://ethanschoonover.com/solarized/
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#073642"      # base02
    [statusbar-fg]="#93a1a1"      # base1

    # Session (blue = signature Solarized accent)
    [session-bg]="#268bd2"        # blue
    [session-fg]="#002b36"        # base03
    [session-prefix-bg]="#cb4b16" # orange
    [session-copy-bg]="#2aa198"   # cyan

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#6c71c4"  # violet
    [window-inactive-base]="#586e75" # base01

    # Pane Borders
    [pane-border-active]="#268bd2"  # blue
    [pane-border-inactive]="#586e75" # base01

    # Health States (base colors - variants auto-generated)
    [ok-base]="#073642"           # base02
    [good-base]="#859900"         # green ✓
    [info-base]="#2aa198"         # cyan (blue) ✓
    [warning-base]="#b58900"      # yellow ✓
    [error-base]="#dc322f"        # red ✓
    [disabled-base]="#586e75"     # base01

    # Messages
    [message-bg]="#073642"        # base02
    [message-fg]="#93a1a1"        # base1

)
