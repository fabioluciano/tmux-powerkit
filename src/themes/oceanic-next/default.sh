#!/usr/bin/env bash
# =============================================================================
# Theme: Oceanic Next
# Variant: Default
# Description: Dark theme with oceanic blue palette
# Source: https://github.com/voronianski/oceanic-next-color-scheme
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#1b2b34"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#343d46"             # surface
    [statusbar-fg]="#d8dee9"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#6699cc"               # blue (signature Oceanic)
    [session-fg]="#1b2b34"               # background
    [session-prefix-bg]="#f99157"        # orange
    [session-copy-bg]="#c594c5"          # purple
    [session-search-bg]="#fac863"        # yellow
    [session-command-bg]="#5fb3b3"       # cyan

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#c594c5"       # purple (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#4f5b66"     # grey
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#5fb3b3"         # cyan

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#6699cc"       # blue
    [pane-border-inactive]="#4f5b66"     # grey

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#4f5b66"                  # muted (distinct from statusbar-bg)
    [good-base]="#99c794"                # green
    [info-base]="#6699cc"                # blue
    [warning-base]="#fac863"             # yellow
    [error-base]="#ec5f67"               # red
    [disabled-base]="#65737e"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#343d46"               # surface
    [message-fg]="#d8dee9"               # text
)
