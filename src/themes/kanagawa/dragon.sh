#!/usr/bin/env bash
# =============================================================================
# Theme: Kanagawa
# Variant: Dragon
# Description: Darker, more muted variant inspired by Katsushika Hokusai
# Source: https://github.com/rebelot/kanagawa.nvim
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#181616"               # dragonBlack3

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#282727"             # dragonBlack4
    [statusbar-fg]="#c5c9c5"             # dragonWhite

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#8992a7"               # dragonViolet (signature)
    [session-fg]="#181616"               # dragonBlack3
    [session-prefix-bg]="#b6927b"        # dragonOrange
    [session-copy-bg]="#8ba4b0"          # dragonBlue2
    [session-search-bg]="#c4b28a"        # dragonYellow
    [session-command-bg]="#a292a3"       # dragonPink

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#a292a3"       # dragonPink (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#393836"     # dragonBlack5
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#8ba4b0"         # dragonBlue2

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#8992a7"       # dragonViolet
    [pane-border-inactive]="#393836"     # dragonBlack5

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#54546d"                  # dragonGray (distinct from statusbar)
    [good-base]="#87a987"                # dragonGreen
    [info-base]="#8ba4b0"                # dragonBlue2
    [warning-base]="#c4b28a"             # dragonYellow
    [error-base]="#c4746e"               # dragonRed
    [disabled-base]="#625e5a"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#282727"               # dragonBlack4
    [message-fg]="#c5c9c5"               # dragonWhite

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#282727"                 # Popup background
    [popup-fg]="#c5c9c5"                 # Popup foreground
    [popup-border]="#8992a7"             # Popup border
    [menu-bg]="#282727"                  # Menu background
    [menu-fg]="#c5c9c5"                  # Menu foreground
    [menu-selected-bg]="#8992a7"         # Menu selected background
    [menu-selected-fg]="#181616"         # Menu selected foreground
    [menu-border]="#8992a7"              # Menu border
)
