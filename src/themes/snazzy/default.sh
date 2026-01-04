#!/usr/bin/env bash
# =============================================================================
# Theme: Snazzy
# Variant: Default
# Description: Elegant dark theme with vibrant colors
# Source: https://github.com/sindresorhus/hyper-snazzy
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#282a36"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#34353e"             # surface
    [statusbar-fg]="#eff0eb"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#57c7ff"               # blue (signature Snazzy)
    [session-fg]="#282a36"               # background
    [session-prefix-bg]="#ff9f43"        # orange
    [session-copy-bg]="#ff6ac1"          # pink
    [session-search-bg]="#f3f99d"        # yellow
    [session-command-bg]="#9aedfe"       # cyan

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#ff6ac1"       # pink (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#43454f"     # muted surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#9aedfe"         # cyan

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#57c7ff"       # blue
    [pane-border-inactive]="#43454f"     # muted surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#43454f"                  # muted (distinct from statusbar-bg)
    [good-base]="#5af78e"                # green
    [info-base]="#57c7ff"                # blue
    [warning-base]="#f3f99d"             # yellow
    [error-base]="#ff5c57"               # red
    [disabled-base]="#606580"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#34353e"               # surface
    [message-fg]="#eff0eb"               # text
)
