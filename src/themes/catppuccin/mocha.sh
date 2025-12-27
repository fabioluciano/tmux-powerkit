#!/usr/bin/env bash
# =============================================================================
# Theme: Catppuccin
# Variant: Mocha
# Description: Soothing pastel theme - darkest variant
# Source: https://github.com/catppuccin/catppuccin
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#313244"      # surface0
    [statusbar-fg]="#cdd6f4"      # text

    # Session (mauve = signature Catppuccin color)
    [session-bg]="#cba6f7"        # mauve
    [session-fg]="#1e1e2e"        # base
    [session-prefix-bg]="#fab387" # peach
    [session-copy-bg]="#74c7ec"   # sapphire

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#f5c2e7"  # pink
    [window-inactive-base]="#45475a" # surface1

    # Pane Borders
    [pane-border-active]="#cba6f7"  # mauve
    [pane-border-inactive]="#45475a" # surface1

    # Health States (base colors - variants auto-generated)
    [ok-base]="#313244"           # surface0
    [good-base]="#a6e3a1"         # green ✓
    [info-base]="#89b4fa"         # blue ✓
    [warning-base]="#f9e2af"      # yellow ✓
    [error-base]="#f38ba8"        # red ✓
    [disabled-base]="#6c7086"     # overlay0

    # Messages
    [message-bg]="#313244"        # surface0
    [message-fg]="#cdd6f4"        # text

)
