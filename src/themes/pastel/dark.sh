#!/usr/bin/env bash
# =============================================================================
# Theme: Pastel
# Variant: Dark
# Description: Soft pastel color palette with dark background
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#1a1b26"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#24283b"             # surface
    [statusbar-fg]="#c0caf5"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#e88fb5"               # pastel pink (signature)
    [session-fg]="#1a1b26"               # base
    [session-prefix-bg]="#f4e8c1"        # pastel cream
    [session-copy-bg]="#9bc5e8"          # pastel blue
    [session-search-bg]="#f4e8c1"        # pastel cream
    [session-command-bg]="#d4a5ff"       # pastel purple

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#d4a5ff"       # pastel purple (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#3b4261"     # muted
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#9bc5e8"         # pastel blue

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#e88fb5"       # pastel pink
    [pane-border-inactive]="#3b4261"     # muted

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#2d3250"                  # darker neutral
    [good-base]="#c5e89f"                # pastel green
    [info-base]="#9bc5e8"                # pastel blue
    [warning-base]="#f4e8c1"             # pastel cream/yellow
    [error-base]="#f4a799"               # pastel coral
    [disabled-base]="#565f89"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#24283b"               # surface
    [message-fg]="#c0caf5"               # text

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#24283b"                 # Popup background
    [popup-fg]="#c0caf5"                 # Popup foreground
    [popup-border]="#e88fb5"             # Popup border
    [menu-bg]="#24283b"                  # Menu background
    [menu-fg]="#c0caf5"                  # Menu foreground
    [menu-selected-bg]="#e88fb5"         # Menu selected background
    [menu-selected-fg]="#1a1b26"         # Menu selected foreground
    [menu-border]="#e88fb5"              # Menu border
)
