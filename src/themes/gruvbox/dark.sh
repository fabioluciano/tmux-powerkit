#!/usr/bin/env bash
# =============================================================================
# Theme: Gruvbox - Dark Variant
# Description: Retro groove color scheme - dark variant
# Source: https://github.com/morhetz/gruvbox
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#282828"               # bg0

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#3c3836"             # bg1
    [statusbar-fg]="#ebdbb2"             # fg1

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#fe8019"               # Orange bright (warm Gruvbox signature)
    [session-fg]="#282828"               # bg0
    [session-prefix-bg]="#fabd2f"        # Yellow bright
    [session-copy-bg]="#83a598"          # Blue bright
    [session-search-bg]="#fabd2f"        # Yellow bright
    [session-command-bg]="#d3869b"       # Purple bright

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#d79921"       # Yellow (distinctive warm)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#504945"     # bg2
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#83a598"         # Blue bright

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#fe8019"       # Orange bright
    [pane-border-inactive]="#504945"     # bg2

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#665c54"                  # bg3 (distinct from statusbar)
    [good-base]="#b8bb26"                # Green bright
    [info-base]="#83a598"                # Blue bright
    [warning-base]="#fabd2f"             # Yellow bright
    [error-base]="#fb4934"               # Red bright
    [disabled-base]="#665c54"            # bg3

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#3c3836"               # bg1
    [message-fg]="#ebdbb2"               # fg1

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#3c3836"                 # Popup background
    [popup-fg]="#ebdbb2"                 # Popup foreground
    [popup-border]="#fe8019"             # Popup border
    [menu-bg]="#3c3836"                  # Menu background
    [menu-fg]="#ebdbb2"                  # Menu foreground
    [menu-selected-bg]="#fe8019"         # Menu selected background
    [menu-selected-fg]="#282828"         # Menu selected foreground
    [menu-border]="#fe8019"              # Menu border
)
