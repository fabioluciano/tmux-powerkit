#!/usr/bin/env bash
# =============================================================================
# Theme: Ayu
# Variant: Dark
# Description: Bright, warm-toned dark theme
# Source: https://github.com/ayu-theme/ayu-colors
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#0b0e14"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#0d1017"             # surface
    [statusbar-fg]="#bfbdb6"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#ffb454"               # orange (signature Ayu)
    [session-fg]="#0b0e14"               # background
    [session-prefix-bg]="#f29668"        # bright orange
    [session-copy-bg]="#d2a6ff"          # purple
    [session-search-bg]="#e6b450"        # yellow
    [session-command-bg]="#73d0ff"       # cyan

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#73d0ff"       # cyan (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#11151c"     # darker surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#d2a6ff"         # purple

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#ffb454"       # orange
    [pane-border-inactive]="#11151c"     # darker surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#131721"                  # neutral surface
    [good-base]="#aad94c"                # green
    [info-base]="#73d0ff"                # cyan
    [warning-base]="#e6b450"             # yellow
    [error-base]="#d95757"               # red
    [disabled-base]="#565b66"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#0d1017"               # surface
    [message-fg]="#bfbdb6"               # text
)
