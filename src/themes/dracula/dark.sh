#!/usr/bin/env bash
# =============================================================================
# Theme: Dracula - Dark Variant (Default)
# Description: A dark theme for vampires
# Source: https://draculatheme.com/
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#282a36"               # Background

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#44475a"             # Selection
    [statusbar-fg]="#f8f8f2"             # Foreground

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#bd93f9"               # Purple (signature Dracula)
    [session-fg]="#282a36"               # Background
    [session-prefix-bg]="#ffb86c"        # Orange
    [session-copy-bg]="#8be9fd"          # Cyan
    [session-search-bg]="#f1fa8c"        # Yellow
    [session-command-bg]="#ff79c6"       # Pink

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#ff79c6"       # Pink (distinctive Dracula)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#6272a4"     # Comment
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#8be9fd"         # Cyan

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#bd93f9"       # Purple
    [pane-border-inactive]="#6272a4"     # Comment

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#3a3d4e"                  # Darker selection
    [good-base]="#50fa7b"                # Green
    [info-base]="#8be9fd"                # Cyan (blue)
    [warning-base]="#f1fa8c"             # Yellow
    [error-base]="#ff5555"               # Red
    [disabled-base]="#545977"            # Muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#44475a"               # Selection
    [message-fg]="#f8f8f2"               # Foreground

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#44475a"                 # Popup background
    [popup-fg]="#f8f8f2"                 # Popup foreground
    [popup-border]="#bd93f9"             # Popup border
    [menu-bg]="#44475a"                  # Menu background
    [menu-fg]="#f8f8f2"                  # Menu foreground
    [menu-selected-bg]="#bd93f9"         # Menu selected background
    [menu-selected-fg]="#282a36"         # Menu selected foreground
    [menu-border]="#bd93f9"              # Menu border
)
