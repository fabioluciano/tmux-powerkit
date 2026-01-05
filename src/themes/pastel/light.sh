#!/usr/bin/env bash
# =============================================================================
# Theme: Pastel
# Variant: Light
# Description: Soft pastel color palette with light background
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#fafafa"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#f0f0f0"             # surface
    [statusbar-fg]="#2e3440"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#d87a9e"               # pastel pink (signature)
    [session-fg]="#fafafa"               # base
    [session-prefix-bg]="#c4b891"        # pastel cream
    [session-copy-bg]="#6a9ec5"          # pastel blue
    [session-search-bg]="#c4a050"        # pastel yellow
    [session-command-bg]="#b086d0"       # pastel purple

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#b086d0"       # pastel purple (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#d8d8d8"     # muted
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#6a9ec5"         # pastel blue

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#d87a9e"       # pastel pink
    [pane-border-inactive]="#d8d8d8"     # muted

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#a0a0a0"                  # neutral
    [good-base]="#6a9e4f"                # pastel green
    [info-base]="#6a9ec5"                # pastel blue
    [warning-base]="#c4a050"             # pastel yellow
    [error-base]="#b35f73"               # pastel red
    [disabled-base]="#c0c0c0"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#f0f0f0"               # surface
    [message-fg]="#2e3440"               # text

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#f0f0f0"                 # Popup background
    [popup-fg]="#2e3440"                 # Popup foreground
    [popup-border]="#d87a9e"             # Popup border
    [menu-bg]="#f0f0f0"                  # Menu background
    [menu-fg]="#2e3440"                  # Menu foreground
    [menu-selected-bg]="#d87a9e"         # Menu selected background
    [menu-selected-fg]="#fafafa"         # Menu selected foreground
    [menu-border]="#d87a9e"              # Menu border
)
