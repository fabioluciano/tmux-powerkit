#!/usr/bin/env bash
# =============================================================================
# Theme: Gruvbox - Light Variant
# Description: Retro groove color scheme - light variant
# Source: https://github.com/morhetz/gruvbox
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#fbf1c7"               # light0

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#ebdbb2"             # fg1 (light bg)
    [statusbar-fg]="#3c3836"             # bg1 (dark text)

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#af3a03"               # Orange faded (warm Gruvbox)
    [session-fg]="#fbf1c7"               # light0
    [session-prefix-bg]="#b57614"        # Yellow faded
    [session-copy-bg]="#076678"          # Blue faded
    [session-search-bg]="#b57614"        # Yellow faded
    [session-command-bg]="#8f3f71"       # Purple faded

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#b57614"       # Yellow faded
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#d5c4a1"     # fg2
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#076678"         # Blue faded

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#af3a03"       # Orange faded
    [pane-border-inactive]="#d5c4a1"     # fg2

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#665c54"                  # bg3
    [good-base]="#79740e"                # Green faded
    [info-base]="#076678"                # Blue faded
    [warning-base]="#b57614"             # Yellow faded
    [error-base]="#9d0006"               # Red faded
    [disabled-base]="#bdae93"            # fg3

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#ebdbb2"               # fg1
    [message-fg]="#3c3836"               # bg1

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#ebdbb2"                 # Popup background
    [popup-fg]="#3c3836"                 # Popup foreground
    [popup-border]="#af3a03"             # Popup border
    [menu-bg]="#ebdbb2"                  # Menu background
    [menu-fg]="#3c3836"                  # Menu foreground
    [menu-selected-bg]="#af3a03"         # Menu selected background
    [menu-selected-fg]="#fbf1c7"         # Menu selected foreground
    [menu-border]="#af3a03"              # Menu border
)
