#!/usr/bin/env bash
# =============================================================================
# Theme: Retro 82 - Dark
# Description: Retro-teal dark theme inspired by the Retro 82 palette
# Source: https://github.com/retro82/retro82
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#05182e"               # background

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#05182e"             # background
    [statusbar-fg]="#f6dcac"             # bright_foreground

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#faa968"               # accent/orange
    [session-fg]="#05182e"               # background
    [session-prefix-bg]="#e97b3c"        # yellow
    [session-copy-bg]="#028391"          # green
    [session-search-bg]="#f85525"        # red
    [session-command-bg]="#8cbfb8"       # cyan

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#faa968"       # accent (distinctive)

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#2a6b78"     # muted

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-zoomed-bg]="#028391"         # green

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#faa968"       # accent
    [pane-border-inactive]="#2a6b78"     # muted

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#2a6b78"                  # muted (distinct from statusbar-bg)
    [good-base]="#028391"                # green
    [info-base]="#8cbfb8"                # cyan
    [warning-base]="#e97b3c"             # yellow
    [error-base]="#f85525"               # red
    [disabled-base]="#134e5a"            # selection

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#05182e"               # background
    [message-fg]="#f6dcac"               # bright_foreground

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#05182e"                 # Popup background
    [popup-fg]="#a7c9c6"                 # Popup foreground
    [popup-border]="#faa968"             # Popup border
    [menu-bg]="#05182e"                  # Menu background
    [menu-fg]="#a7c9c6"                  # Menu foreground
    [menu-selected-bg]="#faa968"         # Menu selected background
    [menu-selected-fg]="#05182e"         # Menu selected foreground
    [menu-border]="#faa968"              # Menu border
)

export THEME_COLORS
