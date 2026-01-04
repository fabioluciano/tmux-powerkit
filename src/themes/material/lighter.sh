#!/usr/bin/env bash
# =============================================================================
# Theme: Material
# Variant: Lighter
# Description: Material Design inspired theme - light variant
# Source: https://material-theme.com/
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#fafafa"               # lighter base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#e7e7e8"             # lighter surface
    [statusbar-fg]="#546e7a"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#6182b8"               # blue (darker for light bg)
    [session-fg]="#fafafa"               # background
    [session-prefix-bg]="#f76d47"        # orange
    [session-copy-bg]="#7c4dff"          # purple
    [session-search-bg]="#f9a825"        # yellow
    [session-command-bg]="#39adb5"       # cyan

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#7c4dff"       # purple (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#ccd7da"     # muted surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#39adb5"         # cyan

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#6182b8"       # blue
    [pane-border-inactive]="#ccd7da"     # muted surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#90a4ae"                  # blue grey 300
    [good-base]="#91b859"                # green
    [info-base]="#6182b8"                # blue
    [warning-base]="#f9a825"             # yellow
    [error-base]="#e53935"               # red
    [disabled-base]="#b0bec5"            # blue grey 200

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#e7e7e8"               # lighter surface
    [message-fg]="#546e7a"               # text
)
