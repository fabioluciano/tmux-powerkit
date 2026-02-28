#!/usr/bin/env bash
# =============================================================================
# Theme: Monochrome Dark
# Description: Clean minimal theme in pure black and white - dark variant
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#0d0d0d"               # background - near black

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#1a1a1a"             # slightly above background
    [statusbar-fg]="#ececec"             # color7 - off white

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#ffffff"              # white - máximo contraste
    [session-fg]="#0d0d0d"              # background - near black
    [session-prefix-bg]="#cecece"       # color3/11 - light gray
    [session-copy-bg]="#b0b0b0"         # color6/14 - medium gray
    [session-search-bg]="#b6b6b6"       # color2/10 - medium gray
    [session-command-bg]="#9b9b9b"      # color5/13 - mid gray

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#ffffff"      # foreground - pure white
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#8d8d8d"    # accent - mid gray
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#b0b0b0"        # color6 - medium gray

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#ffffff"      # foreground - white
    [pane-border-inactive]="#8d8d8d"    # accent - mid gray

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#8d8d8d"                 # accent - mid gray
    [good-base]="#ececec"               # color7 - off white
    [info-base]="#b6b6b6"               # color2 - medium gray
    [warning-base]="#cecece"            # color3 - light gray
    [error-base]="#ffffff"              # white (máximo destaque)
    [disabled-base]="#a4a4a4"           # color1/9 - dark-mid gray

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#1a1a1a"              # slightly above background
    [message-fg]="#ececec"              # color7 - off white

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#0d0d0d"                # background - near black
    [popup-fg]="#ffffff"                # foreground - white
    [popup-border]="#8d8d8d"            # accent - mid gray
    [menu-bg]="#0d0d0d"                 # background - near black
    [menu-fg]="#ffffff"                 # foreground - white
    [menu-selected-bg]="#ffffff"        # selection_background - white
    [menu-selected-fg]="#0d0d0d"        # selection_foreground - near black
    [menu-border]="#8d8d8d"             # accent - mid gray
)
