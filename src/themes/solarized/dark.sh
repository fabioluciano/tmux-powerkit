#!/usr/bin/env bash
# =============================================================================
# Theme: Solarized
# Variant: Dark
# Description: Precision colors for machines and people
# Source: https://ethanschoonover.com/solarized/
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#002b36"               # base03

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#073642"             # base02
    [statusbar-fg]="#93a1a1"             # base1

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#268bd2"               # blue (signature Solarized)
    [session-fg]="#002b36"               # base03
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
    [window-inactive-base]="#586e75"     # base01
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
    [pane-border-inactive]="#586e75"     # base01

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#586e75"                  # base01 (distinct from statusbar-bg)
    [good-base]="#859900"                # green
    [info-base]="#2aa198"                # cyan
    [warning-base]="#b58900"             # yellow
    [error-base]="#dc322f"               # red
    [disabled-base]="#586e75"            # base01

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#073642"               # base02
    [message-fg]="#93a1a1"               # base1

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#073642"                 # Popup background
    [popup-fg]="#93a1a1"                 # Popup foreground
    [popup-border]="#268bd2"             # Popup border
    [menu-bg]="#073642"                  # Menu background
    [menu-fg]="#93a1a1"                  # Menu foreground
    [menu-selected-bg]="#268bd2"         # Menu selected background
    [menu-selected-fg]="#002b36"         # Menu selected foreground
    [menu-border]="#268bd2"              # Menu border
)
