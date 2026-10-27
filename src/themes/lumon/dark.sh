#!/usr/bin/env bash
# =============================================================================
# Theme: Lumon - Dark
# Description: Cool blue-toned dark theme inspired by Lumon Industries
# Source: https://github.com/ajh17/lumon
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#16242d"               # background

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#16242d"             # background
    [statusbar-fg]="#f2fcff"             # bright_foreground

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#6fb8e3"               # blue/active_tab_background
    [session-fg]="#16242d"               # background
    [session-prefix-bg]="#6fa4c9"        # yellow
    [session-copy-bg]="#5e95bc"          # green
    [session-search-bg]="#8bc9eb"        # accent
    [session-command-bg]="#8bc9eb"       # magenta

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#8bc9eb"       # accent (distinctive)

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#304860"     # muted

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-zoomed-bg]="#5e95bc"         # green

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#6fb8e3"       # blue
    [pane-border-inactive]="#304860"     # muted

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#304860"                  # muted (distinct from statusbar-bg)
    [good-base]="#5e95bc"                # green
    [info-base]="#b4e4f6"                # cyan
    [warning-base]="#6fa4c9"             # yellow
    [error-base]="#73a6cb"               # bright_red
    [disabled-base]="#243d56"            # selection

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#16242d"               # background
    [message-fg]="#f2fcff"               # bright_foreground

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#16242d"                 # Popup background
    [popup-fg]="#d6e2ee"                 # Popup foreground
    [popup-border]="#6fb8e3"             # Popup border
    [menu-bg]="#16242d"                  # Menu background
    [menu-fg]="#d6e2ee"                  # Menu foreground
    [menu-selected-bg]="#6fb8e3"         # Menu selected background
    [menu-selected-fg]="#16242d"         # Menu selected foreground
    [menu-border]="#6fb8e3"              # Menu border
)

export THEME_COLORS
