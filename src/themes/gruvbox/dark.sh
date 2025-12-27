#!/usr/bin/env bash
# =============================================================================
# Theme: Gruvbox
# Variant: Dark
# Description: Retro groove color scheme - dark variant
# Source: https://github.com/morhetz/gruvbox
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#3c3836"      # bg1
    [statusbar-fg]="#ebdbb2"      # fg1

    # Session (orange = warm Gruvbox signature)
    [session-bg]="#fe8019"        # orange bright
    [session-fg]="#282828"        # bg0
    [session-prefix-bg]="#fabd2f" # yellow bright
    [session-copy-bg]="#83a598"   # blue bright

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#d79921"  # yellow
    [window-inactive-base]="#504945" # bg2

    # Pane Borders
    [pane-border-active]="#fe8019"  # orange bright
    [pane-border-inactive]="#504945" # bg2

    # Health States (base colors - variants auto-generated)
    [ok-base]="#504945"           # bg2
    [good-base]="#b8bb26"         # green bright ✓
    [info-base]="#83a598"         # blue bright ✓
    [warning-base]="#fabd2f"      # yellow bright ✓
    [error-base]="#fb4934"        # red bright ✓
    [disabled-base]="#665c54"     # bg3

    # Messages
    [message-bg]="#3c3836"        # bg1
    [message-fg]="#ebdbb2"        # fg1

)
