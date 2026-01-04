#!/usr/bin/env bash
# =============================================================================
# Theme: Darcula
# Variant: Default
# Description: Classic JetBrains IDE dark theme
# Source: https://github.com/dracula/jetbrains
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#2b2b2b"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#3c3f41"             # surface
    [statusbar-fg]="#a9b7c6"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#6897bb"               # blue (signature Darcula)
    [session-fg]="#2b2b2b"               # background
    [session-prefix-bg]="#cc7832"        # orange
    [session-copy-bg]="#9876aa"          # purple
    [session-search-bg]="#bbb529"        # yellow
    [session-command-bg]="#629755"       # green

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#9876aa"       # purple (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#45494a"     # muted surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#629755"         # green

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#6897bb"       # blue
    [pane-border-inactive]="#45494a"     # muted surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#606366"                  # muted (distinct from statusbar)
    [good-base]="#6a8759"                # green
    [info-base]="#6897bb"                # blue
    [warning-base]="#bbb529"             # yellow
    [error-base]="#ff6b68"               # red
    [disabled-base]="#606366"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#3c3f41"               # surface
    [message-fg]="#a9b7c6"               # text
)
