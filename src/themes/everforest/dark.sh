#!/usr/bin/env bash
# =============================================================================
# Theme: Everforest
# Variant: Dark
# Description: Comfortable green-based dark theme
# Source: https://github.com/sainnhe/everforest
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#343f44"
    [statusbar-fg]="#d3c6aa"

    # Session
    [session-bg]="#a7c080"
    [session-fg]="#2d353b"
    [session-prefix-bg]="#dbbc7f"
    [session-copy-bg]="#83c092"

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#d699b6"
    [window-inactive-base]="#3d484d"

    # Pane Borders
    [pane-border-active]="#d699b6"
    [pane-border-inactive]="#3d484d"

    # Health States (base colors - variants auto-generated)
    [ok-base]="#475258"
    [good-base]="#a7c080"
    [info-base]="#83c092"
    [warning-base]="#dbbc7f"
    [error-base]="#e67e80"
    [disabled-base]="#7a8478"

    # Messages
    [message-bg]="#343f44"
    [message-fg]="#d3c6aa"

)
