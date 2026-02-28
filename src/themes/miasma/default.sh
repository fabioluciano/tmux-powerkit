#!/usr/bin/env bash
# =============================================================================
# Theme: Miasma
# Description: Dark earthy theme with muted greens, oranges and warm tones
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#222222"               # background - dark gray

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#2e2e2e"             # slightly above background
    [statusbar-fg]="#c2c2b0"             # foreground - warm off-white

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#78824b"              # accent - muted olive green
    [session-fg]="#222222"              # background - dark
    [session-prefix-bg]="#b36d43"       # color3 - burnt orange
    [session-copy-bg]="#5f875f"         # color2 - muted green
    [session-search-bg]="#c9a554"       # color6 - warm yellow
    [session-command-bg]="#bb7744"      # color5 - orange-brown

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#d7c483"      # color7 - warm sandy yellow
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#666666"    # color8 - mid gray
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#5f875f"        # color2 - muted green

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#78824b"      # accent - olive green
    [pane-border-inactive]="#666666"    # color8 - mid gray

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#78824b"                 # accent - olive green
    [good-base]="#5f875f"               # color2 - muted green
    [info-base]="#c9a554"               # color6 - warm yellow
    [warning-base]="#b36d43"            # color3 - burnt orange
    [error-base]="#bb7744"              # color5 - orange-brown
    [disabled-base]="#666666"           # color8 - mid gray

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#685742"              # color1 - dark brown
    [message-fg]="#c2c2b0"              # foreground - warm off-white

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#222222"                # background
    [popup-fg]="#c2c2b0"                # foreground - warm off-white
    [popup-border]="#78824b"            # accent - olive green
    [menu-bg]="#222222"                 # background
    [menu-fg]="#c2c2b0"                 # foreground - warm off-white
    [menu-selected-bg]="#78824b"        # selection_background - olive green
    [menu-selected-fg]="#c2c2b0"        # selection_foreground - warm off-white
    [menu-border]="#78824b"             # accent - olive green
)
