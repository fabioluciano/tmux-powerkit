#!/usr/bin/env bash
# =============================================================================
# Theme: GitHub
# Variant: Light
# Description: GitHub's Primer design system - Light Default
# Source: https://primer.style/design
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#ffffff"               # canvas default

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#eaeef2"             # canvas subtle
    [statusbar-fg]="#24292f"             # fg default

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#0969da"               # accent blue (signature GitHub)
    [session-fg]="#ffffff"               # white
    [session-prefix-bg]="#9a6700"        # attention yellow
    [session-copy-bg]="#8250df"          # done purple
    [session-search-bg]="#9a6700"        # attention yellow
    [session-command-bg]="#bf3989"       # pink

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#8250df"       # done purple (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#d0d7de"     # canvas inset
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#1a7f37"         # success green

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#0969da"       # accent blue
    [pane-border-inactive]="#d0d7de"     # canvas inset

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#57606a"                  # fg muted
    [good-base]="#1a7f37"                # success green
    [info-base]="#0969da"                # accent blue
    [warning-base]="#9a6700"             # attention yellow
    [error-base]="#cf222e"               # danger red
    [disabled-base]="#8c959f"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#eaeef2"               # canvas subtle
    [message-fg]="#24292f"               # fg default

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#eaeef2"                 # Popup background
    [popup-fg]="#24292f"                 # Popup foreground
    [popup-border]="#0969da"             # Popup border
    [menu-bg]="#eaeef2"                  # Menu background
    [menu-fg]="#24292f"                  # Menu foreground
    [menu-selected-bg]="#0969da"         # Menu selected background
    [menu-selected-fg]="#ffffff"         # Menu selected foreground
    [menu-border]="#0969da"              # Menu border
)
