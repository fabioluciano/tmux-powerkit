#!/usr/bin/env bash
# =============================================================================
# Theme: Rose Pine
# Variant: Moon
# Description: Darker variant with natural pine vibes
# Source: https://rosepinetheme.com/
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#232136"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#393552"             # overlay
    [statusbar-fg]="#e0def4"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#c4a7e7"               # iris (signature Rose Pine)
    [session-fg]="#232136"               # base
    [session-prefix-bg]="#f6c177"        # gold
    [session-copy-bg]="#3e8fb0"          # pine
    [session-search-bg]="#f6c177"        # gold
    [session-command-bg]="#ea9a97"       # rose

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#ea9a97"       # rose (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#393552"     # overlay
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
    [pane-border-inactive]="#393552"     # overlay

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#2a273f"                  # surface
    [good-base]="#9ccfd8"                # foam
    [info-base]="#3e8fb0"                # pine
    [warning-base]="#f6c177"             # gold
    [error-base]="#eb6f92"               # love
    [disabled-base]="#6e6a86"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#393552"               # overlay
    [message-fg]="#e0def4"               # text

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#393552"                 # Popup background
    [popup-fg]="#e0def4"                 # Popup foreground
    [popup-border]="#c4a7e7"             # Popup border
    [menu-bg]="#393552"                  # Menu background
    [menu-fg]="#e0def4"                  # Menu foreground
    [menu-selected-bg]="#c4a7e7"         # Menu selected background
    [menu-selected-fg]="#232136"         # Menu selected foreground
    [menu-border]="#c4a7e7"              # Menu border
)
