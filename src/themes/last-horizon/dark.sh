#!/usr/bin/env bash
# =============================================================================
# Theme: Last Horizon - Dark
# Description: Calm dark theme inspired by the Last Horizon palette
# Source: https://github.com/neapsix/last-horizon
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#0c0b0c"               # background

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#0c0b0c"             # background
    [statusbar-fg]="#e2dddc"             # bright_foreground

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#b59790"               # accent/blue
    [session-fg]="#0c0b0c"               # background
    [session-prefix-bg]="#6B5E73"        # yellow
    [session-copy-bg]="#87a9b0"          # green
    [session-search-bg]="#6B5E73"        # yellow
    [session-command-bg]="#c4d8e2"       # magenta

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#c4d8e2"       # magenta (distinctive)

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#584e51"     # muted

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-zoomed-bg]="#87a9b0"         # green

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#b59790"       # accent/blue
    [pane-border-inactive]="#584e51"     # muted

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#584e51"                  # muted (distinct from statusbar-bg)
    [good-base]="#87a9b0"                # green
    [info-base]="#a5a0b6"                # cyan
    [warning-base]="#6B5E73"             # yellow
    [error-base]="#c38b7b"               # red
    [disabled-base]="#584e51"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#0c0b0c"               # background
    [message-fg]="#e2dddc"               # bright_foreground

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#0c0b0c"                 # Popup background
    [popup-fg]="#cfd3cd"                 # Popup foreground
    [popup-border]="#b59790"             # Popup border
    [menu-bg]="#0c0b0c"                  # Menu background
    [menu-fg]="#cfd3cd"                  # Menu foreground
    [menu-selected-bg]="#b59790"         # Menu selected background
    [menu-selected-fg]="#0c0b0c"         # Menu selected foreground
    [menu-border]="#b59790"              # Menu border
)

export THEME_COLORS
