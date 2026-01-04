#!/usr/bin/env bash
# =============================================================================
# Theme: Spacegray
# Variant: Dark
# Description: A hyperminimal UI theme with flat design
# Source: https://github.com/kkga/spacegray
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#2b303b"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#343d46"             # surface
    [statusbar-fg]="#c0c5ce"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#96b5b4"               # cyan (signature Spacegray)
    [session-fg]="#2b303b"               # background
    [session-prefix-bg]="#d08770"        # orange
    [session-copy-bg]="#b48ead"          # purple
    [session-search-bg]="#ebcb8b"        # yellow
    [session-command-bg]="#8fa1b3"       # blue

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#8fa1b3"       # blue (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#4f5b66"     # muted surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#96b5b4"         # cyan

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#96b5b4"       # cyan
    [pane-border-inactive]="#4f5b66"     # muted surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#4f5b66"                  # muted (distinct from statusbar-bg)
    [good-base]="#a3be8c"                # green
    [info-base]="#8fa1b3"                # blue
    [warning-base]="#ebcb8b"             # yellow
    [error-base]="#bf616a"               # red
    [disabled-base]="#65737e"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#343d46"               # surface
    [message-fg]="#c0c5ce"               # text
)
