#!/usr/bin/env bash
# =============================================================================
# Theme: Kanagawa
# Variant: Lotus
# Description: Light theme inspired by Katsushika Hokusai
# Source: https://github.com/rebelot/kanagawa.nvim
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#f2ecbc"               # lotusWhite3

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#e4d794"             # lotusWhite5
    [statusbar-fg]="#545464"             # lotusInk1

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#b35b79"               # lotusPink (signature)
    [session-fg]="#f2ecbc"               # lotusWhite3
    [session-prefix-bg]="#cc6d00"        # lotusOrange
    [session-copy-bg]="#4e8ca2"          # lotusBlue2
    [session-search-bg]="#77713f"        # lotusYellow
    [session-command-bg]="#624c83"       # lotusViolet

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#43436c"       # lotusInk2 (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#c9cbd1"     # muted surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#4e8ca2"         # lotusBlue2

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#b35b79"       # lotusPink
    [pane-border-inactive]="#c9cbd1"     # muted surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#716e61"                  # muted
    [good-base]="#6f894e"                # lotusGreen
    [info-base]="#4e8ca2"                # lotusBlue2
    [warning-base]="#77713f"             # lotusYellow
    [error-base]="#c84053"               # lotusRed
    [disabled-base]="#8a8980"            # disabled

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#e4d794"               # lotusWhite5
    [message-fg]="#545464"               # lotusInk1

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#e4d794"                 # Popup background
    [popup-fg]="#545464"                 # Popup foreground
    [popup-border]="#b35b79"             # Popup border
    [menu-bg]="#e4d794"                  # Menu background
    [menu-fg]="#545464"                  # Menu foreground
    [menu-selected-bg]="#b35b79"         # Menu selected background
    [menu-selected-fg]="#f2ecbc"         # Menu selected foreground
    [menu-border]="#b35b79"              # Menu border
)
