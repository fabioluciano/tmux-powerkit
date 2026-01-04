#!/usr/bin/env bash
# =============================================================================
# Theme: Slack
# Variant: Dark
# Description: Slack's dark theme color palette
# Source: https://slack.com
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#1a1d21"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#222529"             # surface
    [statusbar-fg]="#d1d2d3"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#36c5f0"               # blue (signature Slack)
    [session-fg]="#1a1d21"               # background
    [session-prefix-bg]="#e9a820"        # yellow
    [session-copy-bg]="#ecb22e"          # yellow
    [session-search-bg]="#e9a820"        # yellow
    [session-command-bg]="#2eb67d"       # green

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#e01e5a"       # red/magenta (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#363942"     # muted surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#2eb67d"         # green

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#36c5f0"       # blue
    [pane-border-inactive]="#363942"     # muted surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#363942"                  # muted (distinct from statusbar-bg)
    [good-base]="#2eb67d"                # green
    [info-base]="#36c5f0"                # blue
    [warning-base]="#ecb22e"             # yellow
    [error-base]="#e01e5a"               # red
    [disabled-base]="#616061"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#222529"               # surface
    [message-fg]="#d1d2d3"               # text
)
