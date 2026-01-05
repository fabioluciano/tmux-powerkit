#!/usr/bin/env bash
# =============================================================================
# Theme: Everforest
# Variant: Dark
# Description: Comfortable green-based dark theme
# Source: https://github.com/sainnhe/everforest
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#2d353b"               # bg0

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#343f44"             # bg1
    [statusbar-fg]="#d3c6aa"             # fg

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#a7c080"               # green (signature Everforest)
    [session-fg]="#2d353b"               # bg0
    [session-prefix-bg]="#e69875"        # orange
    [session-copy-bg]="#7fbbb3"          # blue
    [session-search-bg]="#dbbc7f"        # yellow
    [session-command-bg]="#d699b6"       # purple

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#d699b6"       # purple (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#3d484d"     # bg2
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#7fbbb3"         # blue

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#a7c080"       # green
    [pane-border-inactive]="#3d484d"     # bg2

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#475258"                  # bg3
    [good-base]="#a7c080"                # green
    [info-base]="#7fbbb3"                # blue
    [warning-base]="#dbbc7f"             # yellow
    [error-base]="#e67e80"               # red
    [disabled-base]="#7a8478"            # grey0

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#343f44"               # bg1
    [message-fg]="#d3c6aa"               # fg

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#343f44"                 # Popup background
    [popup-fg]="#d3c6aa"                 # Popup foreground
    [popup-border]="#a7c080"             # Popup border
    [menu-bg]="#343f44"                  # Menu background
    [menu-fg]="#d3c6aa"                  # Menu foreground
    [menu-selected-bg]="#a7c080"         # Menu selected background
    [menu-selected-fg]="#2d353b"         # Menu selected foreground
    [menu-border]="#a7c080"              # Menu border
)
