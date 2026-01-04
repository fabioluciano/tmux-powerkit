#!/usr/bin/env bash
# =============================================================================
# Theme: Vesper
# Variant: Default
# Description: Dark theme with warm orange accents
# Source: https://github.com/raunofreiberg/vesper
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#101010"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#1c1c1c"             # surface
    [statusbar-fg]="#a0a0a0"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#ffc799"               # orange (signature Vesper)
    [session-fg]="#101010"               # background
    [session-prefix-bg]="#ffcc66"        # yellow
    [session-copy-bg]="#99c8ff"          # blue
    [session-search-bg]="#ffcc66"        # yellow
    [session-command-bg]="#8bc2b8"       # teal

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#ffc799"       # orange (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#282828"     # muted surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#99c8ff"         # blue

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#ffc799"       # orange
    [pane-border-inactive]="#282828"     # muted surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#282828"                  # muted (distinct from statusbar-bg)
    [good-base]="#8bc2b8"                # teal
    [info-base]="#99c8ff"                # blue
    [warning-base]="#ffcc66"             # yellow
    [error-base]="#f5a191"               # red/coral
    [disabled-base]="#505050"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#1c1c1c"               # surface
    [message-fg]="#a0a0a0"               # text
)
