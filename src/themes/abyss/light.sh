#!/usr/bin/env bash
# =============================================================================
# Theme: Abyss
# Variant: Light
# Description: Clean light theme with warm accents
# Source: Oasis Abyss Light by uhs-robert
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
    [statusbar-fg]="#5c534b"             # fg

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#9c2525"               # strong_primary
    [session-fg]="#f9f7f5"               # core
    [session-prefix-bg]="#3e756c"        # prefix
    [session-copy-bg]="#5a3824"          # orange
    [session-search-bg]="#8f5215"        # orange
    [session-command-bg]="#356a62"       # teal

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#a4590f"       # secondary
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
    [pane-border-active]="#8f5215"       # orange
    [pane-border-inactive]="#e8e0d8"     # surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#978e88"                  # surface
    [good-base]="#276746"                # green
    [info-base]="#1662ae"                # blue
    [warning-base]="#696223"             # yellow
    [error-base]="#9c2525"               # strong_primary
    [disabled-base]="#f3efeb"            # mantle

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#e8e0d8"               # surface
    [message-fg]="#5c534b"               # fg

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#e8e0d8"                 # surface
    [popup-fg]="#5c534b"                 # fg
    [popup-border]="#9c2525"             # strong_primary
    [menu-bg]="#e8e0d8"                  # surface
    [menu-fg]="#5c534b"                  # fg
    [menu-selected-bg]="#9c2525"         # strong_primary
    [menu-selected-fg]="#f9f7f5"         # core
    [menu-border]="#9c2525"              # strong_primary
)
