#!/usr/bin/env bash
# =============================================================================
# Theme: Atom One Dark
# Variant: Dark
# Description: Popular dark theme from Atom editor
# Source: https://github.com/atom/one-dark-syntax
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#282c34"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#21252b"             # surface
    [statusbar-fg]="#abb2bf"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#61afef"               # blue (signature Atom)
    [session-fg]="#282c34"               # background
    [session-prefix-bg]="#d19a66"        # orange
    [session-copy-bg]="#c678dd"          # purple
    [session-search-bg]="#e5c07b"        # yellow
    [session-command-bg]="#56b6c2"       # cyan

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#c678dd"       # purple (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#3e4451"     # muted surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#56b6c2"         # cyan

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#61afef"       # blue
    [pane-border-inactive]="#3e4451"     # muted surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#2c323c"                  # darker surface
    [good-base]="#98c379"                # green
    [info-base]="#61afef"                # blue
    [warning-base]="#e5c07b"             # yellow
    [error-base]="#e06c75"               # red
    [disabled-base]="#5c6370"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#21252b"               # surface
    [message-fg]="#abb2bf"               # text
)
