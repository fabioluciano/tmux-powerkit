#!/usr/bin/env bash
# =============================================================================
# Theme: Iceberg
# Variant: Light
# Description: Cool blue-gray theme - light variant
# Source: https://cocopon.github.io/iceberg.vim/
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#e8e9ec"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#dcdfe7"             # surface
    [statusbar-fg]="#33374c"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#2d539e"               # blue (signature Iceberg)
    [session-fg]="#e8e9ec"               # background
    [session-prefix-bg]="#c57339"        # orange
    [session-copy-bg]="#7759b4"          # purple
    [session-search-bg]="#c57339"        # orange
    [session-command-bg]="#327698"       # cyan

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#7759b4"       # purple (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#c6c8d1"     # muted surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#327698"         # cyan

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#2d539e"       # blue
    [pane-border-inactive]="#c6c8d1"     # muted surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#8389a3"                  # neutral
    [good-base]="#668e3d"                # green
    [info-base]="#2d539e"                # blue
    [warning-base]="#c57339"             # orange
    [error-base]="#cc517a"               # red
    [disabled-base]="#8389a3"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#dcdfe7"               # surface
    [message-fg]="#33374c"               # text
)
