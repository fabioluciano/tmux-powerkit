#!/usr/bin/env bash
# =============================================================================
# Theme: Solitude - Dark
# Description: Serene monochrome dark theme inspired by the Solitude palette
# Source: https://github.com/solitude-theme/solitude
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#101315"               # background

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#101315"             # background
    [statusbar-fg]="#a5aeb4"             # bright_foreground

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#798186"               # accent/blue
    [session-fg]="#101315"               # background
    [session-prefix-bg]="#c9c2b4"        # bright_yellow
    [session-copy-bg]="#9fa5a9"          # green
    [session-search-bg]="#de6145"        # bright_red
    [session-command-bg]="#aeaeae"       # magenta

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#798186"       # accent (distinctive)

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#4b4e55"     # muted

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-zoomed-bg]="#9fa5a9"         # green

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#798186"       # accent
    [pane-border-inactive]="#4b4e55"     # muted

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#4b4e55"                  # muted (distinct from statusbar-bg)
    [good-base]="#9fa5a9"                # green
    [info-base]="#aeaeae"                # magenta
    [warning-base]="#c9c2b4"             # bright_yellow
    [error-base]="#de6145"               # bright_red
    [disabled-base]="#343d41"            # selection

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#101315"               # background
    [message-fg]="#a5aeb4"               # bright_foreground

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#101315"                 # Popup background
    [popup-fg]="#cacccc"                 # Popup foreground
    [popup-border]="#798186"             # Popup border
    [menu-bg]="#101315"                  # Menu background
    [menu-fg]="#cacccc"                  # Menu foreground
    [menu-selected-bg]="#798186"         # Menu selected background
    [menu-selected-fg]="#101315"         # Menu selected foreground
    [menu-border]="#798186"              # Menu border
)

export THEME_COLORS
