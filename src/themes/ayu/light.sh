#!/usr/bin/env bash
# =============================================================================
# Theme: Ayu
# Variant: Light
# Description: Bright, warm-toned light theme
# Source: https://github.com/ayu-theme/ayu-colors
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#fafafa"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#f3f3f3"             # surface
    [statusbar-fg]="#5c6166"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#ff9940"               # orange (signature Ayu)
    [session-fg]="#fafafa"               # background
    [session-prefix-bg]="#f2ae49"        # light orange
    [session-copy-bg]="#a37acc"          # purple
    [session-search-bg]="#f2ae49"        # yellow
    [session-command-bg]="#55b4d4"       # cyan

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#55b4d4"       # cyan (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#d8d8d8"     # muted surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#a37acc"         # purple

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#ff9940"       # orange
    [pane-border-inactive]="#d8d8d8"     # muted surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#8a9199"                  # neutral
    [good-base]="#86b300"                # green
    [info-base]="#55b4d4"                # cyan
    [warning-base]="#f2ae49"             # yellow
    [error-base]="#f51818"               # red
    [disabled-base]="#abb0b6"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#f3f3f3"               # surface
    [message-fg]="#5c6166"               # text
)
