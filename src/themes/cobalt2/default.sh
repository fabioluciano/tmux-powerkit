#!/usr/bin/env bash
# =============================================================================
# Theme: Cobalt2
# Variant: Default
# Description: Classic blue theme by Wes Bos
# Source: https://github.com/wesbos/cobalt2-vscode
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#193549"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#15232d"             # surface
    [statusbar-fg]="#ffffff"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#ffc600"               # yellow (signature Cobalt2)
    [session-fg]="#193549"               # background
    [session-prefix-bg]="#ff9d00"        # orange
    [session-copy-bg]="#ff628c"          # pink
    [session-search-bg]="#ffc600"        # yellow
    [session-command-bg]="#0088ff"       # blue

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#0088ff"       # blue (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#0d3a58"     # muted surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#9effff"         # cyan

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#ffc600"       # yellow
    [pane-border-inactive]="#0d3a58"     # muted surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#4d6a7a"                  # muted (distinct from statusbar)
    [good-base]="#3ad900"                # green
    [info-base]="#0088ff"                # blue
    [warning-base]="#ffc600"             # yellow
    [error-base]="#ff628c"               # pink/red
    [disabled-base]="#4d6a7a"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#15232d"               # surface
    [message-fg]="#ffffff"               # text
)
