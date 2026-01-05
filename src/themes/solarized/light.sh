#!/usr/bin/env bash
# =============================================================================
# Theme: Solarized
# Variant: Light
# Description: Precision colors for machines and people - light variant
# Source: https://ethanschoonover.com/solarized/
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#fdf6e3"               # base3

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#eee8d5"             # base2
    [statusbar-fg]="#073642"             # base02

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#268bd2"               # blue (signature Solarized)
    [session-fg]="#fdf6e3"               # base3
    [session-prefix-bg]="#cb4b16"        # orange
    [session-copy-bg]="#2aa198"          # cyan
    [session-search-bg]="#b58900"        # yellow
    [session-command-bg]="#d33682"       # magenta

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#6c71c4"       # violet (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#93a1a1"     # base1
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#2aa198"         # cyan

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#268bd2"       # blue
    [pane-border-inactive]="#93a1a1"     # base1

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#586e75"                  # base01
    [good-base]="#859900"                # green
    [info-base]="#2aa198"                # cyan
    [warning-base]="#b58900"             # yellow
    [error-base]="#dc322f"               # red
    [disabled-base]="#93a1a1"            # base1

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#eee8d5"               # base2
    [message-fg]="#073642"               # base02

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#eee8d5"                 # Popup background
    [popup-fg]="#073642"                 # Popup foreground
    [popup-border]="#268bd2"             # Popup border
    [menu-bg]="#eee8d5"                  # Menu background
    [menu-fg]="#073642"                  # Menu foreground
    [menu-selected-bg]="#268bd2"         # Menu selected background
    [menu-selected-fg]="#fdf6e3"         # Menu selected foreground
    [menu-border]="#268bd2"              # Menu border
)
