#!/usr/bin/env bash
# =============================================================================
# Theme: Catppuccin
# Variant: Macchiato
# Description: Soothing pastel theme - dark variant
# Source: https://github.com/catppuccin/catppuccin
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#363a4f"      # surface0
    [statusbar-fg]="#cad3f5"      # text

    # Session (mauve = signature Catppuccin color)
    [session-bg]="#c6a0f6"        # mauve
    [session-fg]="#24273a"        # base
    [session-prefix-bg]="#f5a97f" # peach
    [session-copy-bg]="#7dc4e4"   # sapphire

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#f5bde6"  # pink
    [window-inactive-base]="#494d64" # surface1

    # Pane Borders
    [pane-border-active]="#c6a0f6"  # mauve
    [pane-border-inactive]="#494d64" # surface1

    # Health States (base colors - variants auto-generated)
    [ok-base]="#363a4f"           # surface0
    [good-base]="#a6da95"         # green ✓
    [info-base]="#8aadf4"         # blue ✓
    [warning-base]="#eed49f"      # yellow ✓
    [error-base]="#ed8796"        # red ✓
    [disabled-base]="#6e738d"     # overlay0

    # Messages
    [message-bg]="#363a4f"        # surface0
    [message-fg]="#cad3f5"        # text

)
