#!/usr/bin/env bash
# =============================================================================
# Theme: One Dark - Dark Variant (Default)
# Description: A dark syntax theme inspired by Atom
# Source: https://atom.io/themes/one-dark-syntax
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#282c34"               # Black

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#2c323c"             # Cursor grey
    [statusbar-fg]="#abb2bf"             # White

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#61afef"               # Blue (signature OneDark)
    [session-fg]="#282c34"               # Black
    [session-prefix-bg]="#e5c07b"        # Yellow
    [session-copy-bg]="#56b6c2"          # Cyan
    [session-search-bg]="#e5c07b"        # Yellow
    [session-command-bg]="#c678dd"       # Purple

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#c678dd"       # Purple (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#3e4451"     # Visual grey
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#56b6c2"         # Cyan

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#61afef"       # Blue
    [pane-border-inactive]="#3e4451"     # Visual grey

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#3e4451"                  # Visual grey (distinct from statusbar-bg)
    [good-base]="#98c379"                # Green
    [info-base]="#56b6c2"                # Cyan (blue)
    [warning-base]="#e5c07b"             # Yellow
    [error-base]="#e06c75"               # Red
    [disabled-base]="#5c6370"            # Comment grey

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#2c323c"               # Cursor grey
    [message-fg]="#abb2bf"               # White

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#2c323c"                 # Popup background
    [popup-fg]="#abb2bf"                 # Popup foreground
    [popup-border]="#61afef"             # Popup border
    [menu-bg]="#2c323c"                  # Menu background
    [menu-fg]="#abb2bf"                  # Menu foreground
    [menu-selected-bg]="#61afef"         # Menu selected background
    [menu-selected-fg]="#282c34"         # Menu selected foreground
    [menu-border]="#61afef"              # Menu border
)
