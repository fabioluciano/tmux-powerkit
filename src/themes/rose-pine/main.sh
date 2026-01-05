#!/usr/bin/env bash
# =============================================================================
# Theme: Rose Pine
# Variant: Main
# Description: All natural pine, faux fur and a bit of soho vibes
# Source: https://rosepinetheme.com/
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#191724"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#26233a"             # overlay
    [statusbar-fg]="#e0def4"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#c4a7e7"               # iris (signature Rose Pine)
    [session-fg]="#191724"               # base
    [session-prefix-bg]="#f6c177"        # gold
    [session-copy-bg]="#31748f"          # pine
    [session-search-bg]="#f6c177"        # gold
    [session-command-bg]="#ebbcba"       # rose

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#ebbcba"       # rose (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#26233a"     # overlay
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#9ccfd8"         # foam

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#c4a7e7"       # iris
    [pane-border-inactive]="#26233a"     # overlay

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#1f1d2e"                  # surface
    [good-base]="#9ccfd8"                # foam
    [info-base]="#31748f"                # pine
    [warning-base]="#f6c177"             # gold
    [error-base]="#eb6f92"               # love
    [disabled-base]="#6e6a86"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#26233a"               # overlay
    [message-fg]="#e0def4"               # text

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#26233a"                 # Popup background
    [popup-fg]="#e0def4"                 # Popup foreground
    [popup-border]="#c4a7e7"             # Popup border
    [menu-bg]="#26233a"                  # Menu background
    [menu-fg]="#e0def4"                  # Menu foreground
    [menu-selected-bg]="#c4a7e7"         # Menu selected background
    [menu-selected-fg]="#191724"         # Menu selected foreground
    [menu-border]="#c4a7e7"              # Menu border
)
