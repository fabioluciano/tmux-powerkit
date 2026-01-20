#!/usr/bin/env bash
# =============================================================================
# Theme: Lagoon
# Variant: Light
# Description: Clean ocean theme with blue accents
# Source: Oasis Lagoon Light by uhs-robert
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#f9fafb"               # core

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#f0f2f5"             # mantle
    [statusbar-fg]="#40577a"             # fg

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#0970b8"               # strong_primary
    [session-fg]="#f9fafb"               # core
    [session-prefix-bg]="#ab0707"        # prefix
    [session-copy-bg]="#dde3e9"          # surface
    [session-search-bg]="#6a6423"        # yellow
    [session-command-bg]="#366c63"       # teal

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#a4590f"       # secondary
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#dde3e9"     # surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#1663b1"         # blue

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#a4590f"       # secondary
    [pane-border-inactive]="#9fcae0"     # visual

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#617784"                  # muted
    [good-base]="#286947"                # green
    [info-base]="#1663b1"                # blue
    [warning-base]="#6a6423"             # yellow
    [error-base]="#c51414"               # red
    [disabled-base]="#f0f2f5"            # mantle

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#dde3e9"               # surface
    [message-fg]="#40577a"               # fg

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#dde3e9"                 # surface
    [popup-fg]="#40577a"                 # fg
    [popup-border]="#0970b8"             # strong_primary
    [menu-bg]="#dde3e9"                  # surface
    [menu-fg]="#40577a"                  # fg
    [menu-selected-bg]="#0970b8"         # strong_primary
    [menu-selected-fg]="#f9fafb"         # core
    [menu-border]="#0970b8"              # strong_primary
)
