#!/usr/bin/env bash
# =============================================================================
# Theme: Everforest
# Variant: Light
# Description: Soft, paper-like light theme
# Source: https://github.com/sainnhe/everforest
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#fdf6e3"               # bg0

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#efebd4"             # bg2
    [statusbar-fg]="#5c6a72"             # fg

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#8da101"               # green (signature Everforest)
    [session-fg]="#fdf6e3"               # bg0
    [session-prefix-bg]="#f57d26"        # orange
    [session-copy-bg]="#3a94c5"          # blue
    [session-search-bg]="#dfa000"        # yellow
    [session-command-bg]="#df69ba"       # purple

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#df69ba"       # purple (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#e6e2cc"     # bg3
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#3a94c5"         # blue

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#8da101"       # green
    [pane-border-inactive]="#e6e2cc"     # bg3

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#829181"                  # grey2
    [good-base]="#8da101"                # green
    [info-base]="#3a94c5"                # blue
    [warning-base]="#dfa000"             # yellow
    [error-base]="#f85552"               # red
    [disabled-base]="#939f91"            # grey1

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#efebd4"               # bg2
    [message-fg]="#5c6a72"               # fg

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#efebd4"                 # Popup background
    [popup-fg]="#5c6a72"                 # Popup foreground
    [popup-border]="#8da101"             # Popup border
    [menu-bg]="#efebd4"                  # Menu background
    [menu-fg]="#5c6a72"                  # Menu foreground
    [menu-selected-bg]="#8da101"         # Menu selected background
    [menu-selected-fg]="#fdf6e3"         # Menu selected foreground
    [menu-border]="#8da101"              # Menu border
)
