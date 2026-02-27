#!/usr/bin/env bash
# =============================================================================
# Theme: Monochrome
# Description: Clean minimal theme in pure black and white
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#ffffff"               # white

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#c0c0c0"             # color8 - light gray
    [statusbar-fg]="#000000"             # black

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#1a1a1a"              # color4 - near black
    [session-fg]="#ffffff"              # white
    [session-prefix-bg]="#4a4a4a"       # color3 - dark gray
    [session-copy-bg]="#3e3e3e"         # color6 - medium-dark gray
    [session-search-bg]="#3a3a3a"       # color2 - medium gray
    [session-command-bg]="#2e2e2e"      # color5 - dark gray

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#000000"      # pure black
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#6e6e6e"    # accent - mid gray
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#3e3e3e"        # color6 - medium-dark gray

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#1a1a1a"      # near black
    [pane-border-inactive]="#c0c0c0"    # color8 - light gray

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#6e6e6e"                 # accent - mid gray
    [good-base]="#2a2a2a"               # color1 - very dark gray
    [info-base]="#3a3a3a"               # color2 - medium gray
    [warning-base]="#4a4a4a"            # color3 - dark gray
    [error-base]="#000000"              # black (high contrast)
    [disabled-base]="#c0c0c0"           # color8 - light gray

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#c0c0c0"              # color8 - light gray
    [message-fg]="#000000"              # black

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#ffffff"                # white
    [popup-fg]="#000000"                # black
    [popup-border]="#1a1a1a"            # near black
    [menu-bg]="#ffffff"                 # white
    [menu-fg]="#000000"                 # black
    [menu-selected-bg]="#1a1a1a"        # near black
    [menu-selected-fg]="#ffffff"        # white
    [menu-border]="#1a1a1a"             # near black
)
