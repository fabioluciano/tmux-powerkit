#!/usr/bin/env bash
# =============================================================================
# Theme: Moonlight
# Variant: Default
# Description: A dark theme with neon colors
# Source: https://github.com/atomiks/moonlight-vscode-theme
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#212337"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#2b2f44"             # surface
    [statusbar-fg]="#c8d3f5"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#82aaff"               # blue (signature Moonlight)
    [session-fg]="#212337"               # background
    [session-prefix-bg]="#ff966c"        # orange
    [session-copy-bg]="#c099ff"          # purple
    [session-search-bg]="#ffc777"        # yellow
    [session-command-bg]="#86e1fc"       # cyan

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#c099ff"       # purple (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#3b4063"     # muted surface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#86e1fc"         # cyan

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#82aaff"       # blue
    [pane-border-inactive]="#3b4063"     # muted surface

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#3b4063"                  # muted (distinct from statusbar-bg)
    [good-base]="#c3e88d"                # green
    [info-base]="#82aaff"                # blue
    [warning-base]="#ffc777"             # yellow
    [error-base]="#ff757f"               # red
    [disabled-base]="#444a73"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#2b2f44"               # surface
    [message-fg]="#c8d3f5"               # text
)
