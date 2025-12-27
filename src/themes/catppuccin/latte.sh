#!/usr/bin/env bash
# =============================================================================
# Theme: Catppuccin
# Variant: Latte
# Description: Soothing pastel theme - light variant
# Source: https://github.com/catppuccin/catppuccin
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#ccd0da"      # surface0
    [statusbar-fg]="#4c4f69"      # text

    # Session (mauve = signature Catppuccin color)
    [session-bg]="#8839ef"        # mauve
    [session-fg]="#eff1f5"        # base
    [session-prefix-bg]="#fe640b" # peach
    [session-copy-bg]="#209fb5"   # sapphire

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#ea76cb"  # pink
    [window-inactive-base]="#bcc0cc" # surface1

    # Pane Borders
    [pane-border-active]="#8839ef"  # mauve
    [pane-border-inactive]="#bcc0cc" # surface1

    # Health States (base colors - variants auto-generated)
    [ok-base]="#6c6f85"           # subtext0
    [good-base]="#40a02b"         # green ✓
    [info-base]="#1e66f5"         # blue ✓
    [warning-base]="#df8e1d"      # yellow ✓
    [error-base]="#d20f39"        # red ✓
    [disabled-base]="#9ca0b0"     # overlay0

    # Messages
    [message-bg]="#ccd0da"        # surface0
    [message-fg]="#4c4f69"        # text

)
