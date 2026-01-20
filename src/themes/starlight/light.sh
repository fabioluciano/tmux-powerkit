#!/usr/bin/env bash
# =============================================================================
# Theme: Starlight
# Variant: Light
# Description: Celestial light theme with blue accents
# Source: Oasis Starlight Light by uhs-robert
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#f9f7f5"               # core

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#f3efeb"             # mantle
    [statusbar-fg]="#5c5442"             # fg

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#0a70b8"               # strong_primary
    [session-fg]="#f9f7f5"               # core
    [session-prefix-bg]="#a4590f"        # prefix
    [session-copy-bg]="#4d4528"          # indigo
    [session-search-bg]="#696223"        # yellow
    [session-command-bg]="#356a62"       # teal

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#988c1a"       # yellow(secondary))
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#e8e0d8"     # surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#1662ae"         # blue

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#988c1a"       # secondary (yellow-green)
    [pane-border-inactive]="#dacfa4"     # visual

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#dacfa4"                  # visual
    [good-base]="#276746"                # green
    [info-base]="#1662ae"                # blue
    [warning-base]="#696223"             # yellow
    [error-base]="#c21313"               # red
    [disabled-base]="#f3efeb"            # mantle

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#e8e0d8"               # surface
    [message-fg]="#5c5442"               # fg

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#e8e0d8"                 # surface
    [popup-fg]="#5c5442"                 # fg
    [popup-border]="#0a70b8"             # strong_primary
    [menu-bg]="#e8e0d8"                  # surface
    [menu-fg]="#5c5442"                  # fg
    [menu-selected-bg]="#0a70b8"         # strong_primary
    [menu-selected-fg]="#f9f7f5"         # core
    [menu-border]="#0a70b8"              # strong_primary
)
