#!/usr/bin/env bash
# =============================================================================
# Theme: Starlight
# Variant: Dark
# Description: Celestial dark theme with blue accents
# Source: Oasis Starlight Dark by uhs-robert
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#000000"               # core

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#080808"             # mantle
    [statusbar-fg]="#faf7f0"             # fg

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#3aacfd"               # strong_primary
    [session-fg]="#000000"               # core
    [session-prefix-bg]="#f8b471"        # prefix
    [session-copy-bg]="#4d4528"          # indigo
    [session-search-bg]="#f0e68c"        # yellow
    [session-command-bg]="#8fd1c7"       # teal

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#f8b471"       # orange
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#1a1a1a"     # surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#71b8ff"         # blue

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#f0e68c"       # secondary (yellow)
    [pane-border-inactive]="#1a1a1a"     # surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#1a1a1a"                  # surface
    [good-base]="#34cb7d"                # green
    [info-base]="#71b8ff"                # blue
    [warning-base]="#f0e68c"             # yellow
    [error-base]="#ff7979"               # red
    [disabled-base]="#080808"            # mantle

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#1a1a1a"               # surface
    [message-fg]="#faf7f0"               # fg

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#1a1a1a"                 # surface
    [popup-fg]="#faf7f0"                 # fg
    [popup-border]="#3aacfd"             # strong_primary
    [menu-bg]="#1a1a1a"                  # surface
    [menu-fg]="#faf7f0"                  # fg
    [menu-selected-bg]="#3aacfd"         # strong_primary
    [menu-selected-fg]="#000000"         # core
    [menu-border]="#3aacfd"              # strong_primary
)
