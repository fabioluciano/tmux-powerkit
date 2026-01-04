#!/usr/bin/env bash
# =============================================================================
# Theme: Night Owl
# Variant: Default
# Description: Dark theme for night owls by Sarah Drasner
# Source: https://github.com/sdras/night-owl-vscode-theme
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#011627"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#0b2942"             # surface
    [statusbar-fg]="#d6deeb"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#82aaff"               # blue (signature Night Owl)
    [session-fg]="#011627"               # background
    [session-prefix-bg]="#f78c6c"        # orange
    [session-copy-bg]="#c792ea"          # purple
    [session-search-bg]="#ecc48d"        # yellow
    [session-command-bg]="#7fdbca"       # cyan

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#c792ea"       # purple (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#1d3b53"     # muted surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#7fdbca"         # cyan

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#82aaff"       # blue
    [pane-border-inactive]="#1d3b53"     # muted surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#1d3b53"                  # muted (distinct from statusbar-bg)
    [good-base]="#addb67"                # green
    [info-base]="#82aaff"                # blue
    [warning-base]="#ecc48d"             # yellow
    [error-base]="#ff5874"               # red
    [disabled-base]="#637777"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#0b2942"               # surface
    [message-fg]="#d6deeb"               # text
)
