#!/usr/bin/env bash
# =============================================================================
# Theme: Molokai
# Variant: Dark
# Description: Port of the monokai theme for TextMate
# Source: https://github.com/tomasr/molokai
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#1b1d1e"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#232526"             # surface
    [statusbar-fg]="#f8f8f2"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#a6e22e"               # green (signature Molokai)
    [session-fg]="#1b1d1e"               # background
    [session-prefix-bg]="#fd971f"        # orange
    [session-copy-bg]="#66d9ef"          # cyan
    [session-search-bg]="#e6db74"        # yellow
    [session-command-bg]="#ae81ff"       # purple

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#f92672"       # pink (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#3e3d32"     # muted surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#66d9ef"         # cyan

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#a6e22e"       # green
    [pane-border-inactive]="#3e3d32"     # muted surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#3e3d32"                  # muted (distinct from statusbar-bg)
    [good-base]="#a6e22e"                # green
    [info-base]="#66d9ef"                # cyan
    [warning-base]="#e6db74"             # yellow
    [error-base]="#f92672"               # pink/red
    [disabled-base]="#75715e"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#232526"               # surface
    [message-fg]="#f8f8f2"               # text

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#232526"                 # Popup background
    [popup-fg]="#f8f8f2"                 # Popup foreground
    [popup-border]="#a6e22e"             # Popup border
    [menu-bg]="#232526"                  # Menu background
    [menu-fg]="#f8f8f2"                  # Menu foreground
    [menu-selected-bg]="#a6e22e"         # Menu selected background
    [menu-selected-fg]="#1b1d1e"         # Menu selected foreground
    [menu-border]="#a6e22e"              # Menu border
)
