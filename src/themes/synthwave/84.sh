#!/usr/bin/env bash
# =============================================================================
# Theme: SynthWave
# Variant: '84
# Description: Retro synthwave aesthetic with neon colors
# Source: https://github.com/robb0wen/synthwave-vscode
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#262335"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#34294f"             # surface
    [statusbar-fg]="#ffffff"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#ff7edb"               # pink (signature SynthWave)
    [session-fg]="#262335"               # background
    [session-prefix-bg]="#ff8b39"        # orange
    [session-copy-bg]="#cf68e1"          # purple
    [session-search-bg]="#fede5d"        # yellow
    [session-command-bg]="#36f9f6"       # cyan

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#36f9f6"       # cyan (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#495495"     # muted surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#cf68e1"         # purple

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#ff7edb"       # pink
    [pane-border-inactive]="#495495"     # muted surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#495495"                  # muted (distinct from statusbar-bg)
    [good-base]="#72f1b8"                # green
    [info-base]="#36f9f6"                # cyan
    [warning-base]="#fede5d"             # yellow
    [error-base]="#fe4450"               # red
    [disabled-base]="#848bbd"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#34294f"               # surface
    [message-fg]="#ffffff"               # text
)
