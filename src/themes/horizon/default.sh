#!/usr/bin/env bash
# =============================================================================
# Theme: Horizon
# Variant: Default
# Description: Warm dark theme with vibrant colors
# Source: https://horizontheme.netlify.app/
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#1c1e26"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#232530"             # surface
    [statusbar-fg]="#cbced0"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#e95678"               # red (signature Horizon)
    [session-fg]="#1c1e26"               # background
    [session-prefix-bg]="#fab795"        # peach
    [session-copy-bg]="#b877db"          # purple
    [session-search-bg]="#fab795"        # yellow/peach
    [session-command-bg]="#25b2bc"       # cyan

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#b877db"       # purple (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#2e303e"     # muted surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#25b2bc"         # cyan

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#e95678"       # red
    [pane-border-inactive]="#2e303e"     # muted surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#6c6f93"                  # muted (distinct from statusbar)
    [good-base]="#09f7a0"                # green
    [info-base]="#26bbd9"                # blue
    [warning-base]="#fab795"             # peach
    [error-base]="#e95678"               # red
    [disabled-base]="#6c6f93"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#232530"               # surface
    [message-fg]="#cbced0"               # text
)
