#!/usr/bin/env bash
# =============================================================================
# Theme: Lagoon
# Variant: Dark
# Description: Deep ocean theme with blue accents
# Source: Oasis Lagoon Dark by uhs-robert
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#101825"               # core

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#1a283f"             # mantle
    [statusbar-fg]="#d9e6fa"             # fg

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#1ca0fd"               # strong_primary
    [session-fg]="#101825"               # core
    [session-prefix-bg]="#ffa0a0"        # prefix
    [session-copy-bg]="#22385c"          # surface
    [session-search-bg]="#f0e68c"        # yellow
    [session-command-bg]="#8fd1c7"       # teal

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#f8b471"       # secondary
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#22385c"     # surface
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
    [pane-border-active]="#f8b471"       # secondary
    [pane-border-inactive]="#22385c"     # surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#22385c"                  # surface
    [good-base]="#53d390"                # green
    [info-base]="#71b8ff"                # blue
    [warning-base]="#f0e68c"             # yellow
    [error-base]="#ff7979"               # red
    [disabled-base]="#1a283f"            # mantle

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#22385c"               # surface
    [message-fg]="#d9e6fa"               # fg

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#22385c"                 # surface
    [popup-fg]="#d9e6fa"                 # fg
    [popup-border]="#1ca0fd"             # strong_primary
    [menu-bg]="#22385c"                  # surface
    [menu-fg]="#d9e6fa"                  # fg
    [menu-selected-bg]="#1ca0fd"         # strong_primary
    [menu-selected-fg]="#101825"         # core
    [menu-border]="#1ca0fd"              # strong_primary
)
