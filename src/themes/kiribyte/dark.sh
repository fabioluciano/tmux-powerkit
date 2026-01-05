#!/usr/bin/env bash
# =============================================================================
# Theme: Kiribyte
# Variant: Dark
# Description: Soft pastel theme with purple-lavender accents
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#2a2b3d"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#3b3f5c"             # surface
    [statusbar-fg]="#ffffff"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#a9c98c"               # green (signature)
    [session-fg]="#2a2b3d"               # base
    [session-prefix-bg]="#e3caa6"        # cream
    [session-copy-bg]="#ade5ff"          # blue
    [session-search-bg]="#e3caa6"        # cream
    [session-command-bg]="#d4c5ff"       # lavender

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#d4c5ff"       # lavender (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#4d5270"     # muted
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#ade5ff"         # blue

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#d4c5ff"       # lavender
    [pane-border-inactive]="#4d5270"     # muted

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#687aa3"                  # neutral blue
    [good-base]="#a9c98c"                # green
    [info-base]="#ade5ff"                # blue
    [warning-base]="#e3caa6"             # cream
    [error-base]="#ff6b85"               # coral
    [disabled-base]="#8a8fb5"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#3b3f5c"               # surface
    [message-fg]="#ffffff"               # text

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#3b3f5c"                 # Popup background
    [popup-fg]="#ffffff"                 # Popup foreground
    [popup-border]="#d4c5ff"             # Popup border
    [menu-bg]="#3b3f5c"                  # Menu background
    [menu-fg]="#ffffff"                  # Menu foreground
    [menu-selected-bg]="#a9c98c"         # Menu selected background
    [menu-selected-fg]="#2a2b3d"         # Menu selected foreground
    [menu-border]="#d4c5ff"              # Menu border
)
