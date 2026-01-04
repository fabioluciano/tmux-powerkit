#!/usr/bin/env bash
# =============================================================================
# Theme: Ayu
# Variant: Mirage
# Description: Medium-dark variant with softer contrast
# Source: https://github.com/ayu-theme/ayu-colors
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#1f2430"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#242936"             # surface
    [statusbar-fg]="#cccac2"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#ffd580"               # orange (signature Ayu)
    [session-fg]="#1f2430"               # background
    [session-prefix-bg]="#ffad66"        # bright orange
    [session-copy-bg]="#d4bfff"          # purple
    [session-search-bg]="#ffd173"        # yellow
    [session-command-bg]="#73d0ff"       # cyan

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#73d0ff"       # cyan (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#33415e"     # muted surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#d4bfff"         # purple

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#ffd580"       # orange
    [pane-border-inactive]="#33415e"     # muted surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#2d3447"                  # neutral surface
    [good-base]="#d5ff80"                # green
    [info-base]="#73d0ff"                # cyan
    [warning-base]="#ffd173"             # yellow
    [error-base]="#ff6666"               # red
    [disabled-base]="#707a8c"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#242936"               # surface
    [message-fg]="#cccac2"               # text
)
