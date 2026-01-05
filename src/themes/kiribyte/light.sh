#!/usr/bin/env bash
# =============================================================================
# Theme: Kiribyte
# Variant: Light
# Description: Soft paper-like light theme with pastel accents
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#f5f4f0"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#e0dfd9"             # surface
    [statusbar-fg]="#3b3d4a"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#6a8c4f"               # green (signature)
    [session-fg]="#f5f4f0"               # base
    [session-prefix-bg]="#9a7d4d"        # brown/cream
    [session-copy-bg]="#4a8fa8"          # blue
    [session-search-bg]="#9a7d4d"        # brown/cream
    [session-command-bg]="#9b7fc9"       # purple

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#9b7fc9"       # purple (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#d4d3cc"     # muted
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#4a8fa8"         # blue

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#9b7fc9"       # purple
    [pane-border-inactive]="#d4d3cc"     # muted

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#6d7187"                  # neutral
    [good-base]="#6a8c4f"                # green
    [info-base]="#4a8fa8"                # blue
    [warning-base]="#9a7d4d"             # brown/yellow
    [error-base]="#c94d66"               # red
    [disabled-base]="#8a8fb5"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#e0dfd9"               # surface
    [message-fg]="#3b3d4a"               # text

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#e0dfd9"                 # Popup background
    [popup-fg]="#3b3d4a"                 # Popup foreground
    [popup-border]="#9b7fc9"             # Popup border
    [menu-bg]="#e0dfd9"                  # Menu background
    [menu-fg]="#3b3d4a"                  # Menu foreground
    [menu-selected-bg]="#6a8c4f"         # Menu selected background
    [menu-selected-fg]="#f5f4f0"         # Menu selected foreground
    [menu-border]="#9b7fc9"              # Menu border
)
