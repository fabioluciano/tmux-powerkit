#!/usr/bin/env bash
# =============================================================================
# Theme: Everforest
# Variant: Dark
# Description: Comfortable green-based dark theme
# Source: https://github.com/sainnhe/everforest
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#343f44"      # bg1
    [statusbar-fg]="#d3c6aa"      # fg

    # Session (green = signature Everforest color)
    [session-bg]="#a7c080"        # green
    [session-fg]="#2d353b"        # bg0
    [session-prefix-bg]="#e69875" # orange
    [session-copy-bg]="#7fbbb3"   # blue

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#d699b6"  # purple
    [window-inactive-base]="#3d484d" # bg2

    # Pane Borders
    [pane-border-active]="#a7c080"  # green
    [pane-border-inactive]="#3d484d" # bg2

    # Health States (base colors - variants auto-generated)
    [ok-base]="#475258"           # bg3
    [good-base]="#a7c080"         # green ✓
    [info-base]="#7fbbb3"         # blue ✓
    [warning-base]="#dbbc7f"      # yellow ✓
    [error-base]="#e67e80"        # red ✓
    [disabled-base]="#7a8478"     # grey0

    # Messages
    [message-bg]="#343f44"        # bg1
    [message-fg]="#d3c6aa"        # fg

)
