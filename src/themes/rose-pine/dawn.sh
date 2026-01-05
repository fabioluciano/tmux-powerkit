#!/usr/bin/env bash
# =============================================================================
# Theme: Rose Pine
# Variant: Dawn
# Description: Light variant with natural pine vibes
# Source: https://rosepinetheme.com/
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#faf4ed"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#f2e9e1"             # overlay
    [statusbar-fg]="#575279"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#907aa9"               # iris (signature Rose Pine)
    [session-fg]="#faf4ed"               # base
    [session-prefix-bg]="#ea9d34"        # gold
    [session-copy-bg]="#286983"          # pine
    [session-search-bg]="#ea9d34"        # gold
    [session-command-bg]="#d7827e"       # rose

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#d7827e"       # rose (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#dfdad9"     # surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#56949f"         # foam

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#907aa9"       # iris
    [pane-border-inactive]="#dfdad9"     # surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#797593"                  # subtle
    [good-base]="#56949f"                # foam
    [info-base]="#286983"                # pine
    [warning-base]="#ea9d34"             # gold
    [error-base]="#b4637a"               # love
    [disabled-base]="#9893a5"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#f2e9e1"               # overlay
    [message-fg]="#575279"               # text

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#f2e9e1"                 # Popup background
    [popup-fg]="#575279"                 # Popup foreground
    [popup-border]="#907aa9"             # Popup border
    [menu-bg]="#f2e9e1"                  # Menu background
    [menu-fg]="#575279"                  # Menu foreground
    [menu-selected-bg]="#907aa9"         # Menu selected background
    [menu-selected-fg]="#faf4ed"         # Menu selected foreground
    [menu-border]="#907aa9"              # Menu border
)
