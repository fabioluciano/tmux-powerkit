#!/usr/bin/env bash
# =============================================================================
# Theme: Material
# Variant: Default
# Description: Material Design inspired theme - default variant
# Source: https://material-theme.com/
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#263238"               # blue grey 900

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#37474f"             # blue grey 800
    [statusbar-fg]="#eeffff"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#82aaff"               # blue (signature Material)
    [session-fg]="#263238"               # background
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
    [window-inactive-base]="#546e7a"     # blue grey 600
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
    [pane-border-inactive]="#546e7a"     # blue grey 600

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#607d8b"                  # blue grey 500 (distinct from statusbar)
    [good-base]="#c3e88d"                # green
    [info-base]="#82aaff"                # blue
    [warning-base]="#ffcb6b"             # yellow
    [error-base]="#ff5370"               # red
    [disabled-base]="#546e7a"            # blue grey 600

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#37474f"               # blue grey 800
    [message-fg]="#eeffff"               # text
)
