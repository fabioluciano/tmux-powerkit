#!/usr/bin/env bash
# =============================================================================
# Theme: Night Owl
# Variant: Light
# Description: Light theme companion for Night Owl
# Source: https://github.com/sdras/night-owl-vscode-theme
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#fbfbfb"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#f0f0f0"             # surface
    [statusbar-fg]="#403f53"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#4876d6"               # blue (signature Night Owl)
    [session-fg]="#fbfbfb"               # background
    [session-prefix-bg]="#aa0982"        # magenta
    [session-copy-bg]="#994cc3"          # purple
    [session-search-bg]="#c96765"        # orange/red
    [session-command-bg]="#0c969b"       # cyan

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#994cc3"       # purple (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#d9d9d9"     # muted surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#0c969b"         # cyan

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#4876d6"       # blue
    [pane-border-inactive]="#d9d9d9"     # muted surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#93a1a1"                  # neutral
    [good-base]="#08916a"                # green
    [info-base]="#4876d6"                # blue
    [warning-base]="#daaa01"             # yellow
    [error-base]="#de3d3b"               # red
    [disabled-base]="#989fb1"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#f0f0f0"               # surface
    [message-fg]="#403f53"               # text
)
