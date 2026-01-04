#!/usr/bin/env bash
# =============================================================================
# Theme: Iceberg
# Variant: Dark
# Description: Cool blue-gray theme with balanced contrast
# Source: https://cocopon.github.io/iceberg.vim/
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#161821"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#1e2132"             # surface
    [statusbar-fg]="#c6c8d1"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#84a0c6"               # blue (signature Iceberg)
    [session-fg]="#161821"               # background
    [session-prefix-bg]="#e2a478"        # orange
    [session-copy-bg]="#a093c7"          # purple
    [session-search-bg]="#e2a478"        # yellow/orange
    [session-command-bg]="#89b8c2"       # cyan

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#a093c7"       # purple (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#2e313f"     # muted surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#89b8c2"         # cyan

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#84a0c6"       # blue
    [pane-border-inactive]="#2e313f"     # muted surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#6b7089"                  # muted (distinct from statusbar)
    [good-base]="#b4be82"                # green
    [info-base]="#84a0c6"                # blue
    [warning-base]="#e2a478"             # orange
    [error-base]="#e27878"               # red
    [disabled-base]="#6b7089"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#1e2132"               # surface
    [message-fg]="#c6c8d1"               # text
)
