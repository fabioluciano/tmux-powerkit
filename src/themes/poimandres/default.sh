#!/usr/bin/env bash
# =============================================================================
# Theme: Poimandres
# Variant: Default
# Description: A minimal, dark theme for comfortable coding
# Source: https://github.com/drcmda/poimandres-theme
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#1b1e28"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#252b37"             # surface
    [statusbar-fg]="#a6accd"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#5de4c7"               # teal (signature Poimandres)
    [session-fg]="#1b1e28"               # background
    [session-prefix-bg]="#fcc5e9"        # pink
    [session-copy-bg]="#89ddff"          # cyan
    [session-search-bg]="#fffac2"        # yellow
    [session-command-bg]="#add7ff"       # blue

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#fcc5e9"       # pink (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#303340"     # muted surface
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
    [pane-border-active]="#5de4c7"       # teal
    [pane-border-inactive]="#303340"     # muted surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#303340"                  # muted (distinct from statusbar-bg)
    [good-base]="#5de4c7"                # teal
    [info-base]="#add7ff"                # blue
    [warning-base]="#fffac2"             # yellow
    [error-base]="#d0679d"               # red/magenta
    [disabled-base]="#506477"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#252b37"               # surface
    [message-fg]="#a6accd"               # text
)
