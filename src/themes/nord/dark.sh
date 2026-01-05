#!/usr/bin/env bash
# =============================================================================
# Theme: Nord - Dark Variant (Default)
# Description: Arctic, north-bluish color palette
# Source: https://www.nordtheme.com/
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#2e3440"               # nord0 (Polar Night)

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#434c5e"             # nord2
    [statusbar-fg]="#eceff4"             # nord6 (Snow Storm)

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#88c0d0"               # nord8 (Frost - signature Nord)
    [session-fg]="#2e3440"               # nord0
    [session-prefix-bg]="#d08770"        # nord12 (Aurora orange)
    [session-copy-bg]="#5e81ac"          # nord10 (dark blue)
    [session-search-bg]="#ebcb8b"        # nord13 (Aurora yellow)
    [session-command-bg]="#b48ead"       # nord15 (Aurora purple)

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#81a1c1"       # nord9 (Frost blue)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#4c566a"     # nord3
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#5e81ac"         # nord10

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#88c0d0"       # nord8
    [pane-border-inactive]="#4c566a"     # nord3

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#3b4252"                  # nord1
    [good-base]="#a3be8c"                # nord14 (Aurora green)
    [info-base]="#81a1c1"                # nord9 (blue)
    [warning-base]="#ebcb8b"             # nord13 (yellow)
    [error-base]="#bf616a"               # nord11 (red)
    [disabled-base]="#4c566a"            # nord3

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#434c5e"               # nord2
    [message-fg]="#eceff4"               # nord6

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#434c5e"                 # Popup background
    [popup-fg]="#eceff4"                 # Popup foreground
    [popup-border]="#88c0d0"             # Popup border
    [menu-bg]="#434c5e"                  # Menu background
    [menu-fg]="#eceff4"                  # Menu foreground
    [menu-selected-bg]="#88c0d0"         # Menu selected background
    [menu-selected-fg]="#2e3440"         # Menu selected foreground
    [menu-border]="#88c0d0"              # Menu border
)
