#!/usr/bin/env bash
# =============================================================================
# Theme: Material
# Variant: Ocean
# Description: Material Design inspired theme - darker ocean variant
# Source: https://material-theme.com/
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#0f111a"               # ocean base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#1a1c25"             # ocean surface
    [statusbar-fg]="#8f93a2"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#82aaff"               # blue (signature Material)
    [session-fg]="#0f111a"               # background
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
    [window-inactive-base]="#3b3f51"     # muted surface
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
    [pane-border-inactive]="#3b3f51"     # muted surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#4b526d"                  # muted blue (distinct from statusbar)
    [good-base]="#c3e88d"                # green
    [info-base]="#82aaff"                # blue
    [warning-base]="#ffcb6b"             # yellow
    [error-base]="#ff5370"               # red
    [disabled-base]="#464b5d"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#1a1c25"               # ocean surface
    [message-fg]="#8f93a2"               # text
)
