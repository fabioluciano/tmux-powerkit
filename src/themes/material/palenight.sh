#!/usr/bin/env bash
# =============================================================================
# Theme: Material
# Variant: Palenight
# Description: Material Design inspired theme - purple palenight variant
# Source: https://material-theme.com/
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#292d3e"               # palenight base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#34394f"             # palenight surface
    [statusbar-fg]="#a6accd"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#82aaff"               # blue (signature Material)
    [session-fg]="#292d3e"               # background
    [session-prefix-bg]="#f78c6c"        # orange
    [session-copy-bg]="#c792ea"          # purple
    [session-search-bg]="#ffcb6b"        # yellow
    [session-command-bg]="#89ddff"       # cyan

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#c792ea"       # purple (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#4e5579"     # muted surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#89ddff"         # cyan

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#82aaff"       # blue
    [pane-border-inactive]="#4e5579"     # muted surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#676e95"                  # muted purple (distinct from statusbar)
    [good-base]="#c3e88d"                # green
    [info-base]="#82aaff"                # blue
    [warning-base]="#ffcb6b"             # yellow
    [error-base]="#ff5370"               # red
    [disabled-base]="#676e95"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#34394f"               # palenight surface
    [message-fg]="#a6accd"               # text
)
