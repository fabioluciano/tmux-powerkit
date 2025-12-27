#!/usr/bin/env bash
# =============================================================================
# Theme: Catppuccin
# Variant: Frappe
# Description: Soothing pastel theme - medium-dark variant
# Source: https://github.com/catppuccin/catppuccin
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#414559"      # surface0
    [statusbar-fg]="#c6d0f5"      # text

    # Session (mauve = signature Catppuccin color)
    [session-bg]="#ca9ee6"        # mauve
    [session-fg]="#303446"        # base
    [session-prefix-bg]="#ef9f76" # peach
    [session-copy-bg]="#85c1dc"   # sapphire

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#f4b8e4"  # pink
    [window-inactive-base]="#51576d" # surface1

    # Pane Borders
    [pane-border-active]="#ca9ee6"  # mauve
    [pane-border-inactive]="#51576d" # surface1

    # Health States (base colors - variants auto-generated)
    [ok-base]="#414559"           # surface0
    [good-base]="#a6d189"         # green ✓
    [info-base]="#8caaee"         # blue ✓
    [warning-base]="#e5c890"      # yellow ✓
    [error-base]="#e78284"        # red ✓
    [disabled-base]="#737994"     # overlay0

    # Messages
    [message-bg]="#414559"        # surface0
    [message-fg]="#c6d0f5"        # text

)
