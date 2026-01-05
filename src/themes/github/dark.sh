#!/usr/bin/env bash
# =============================================================================
# Theme: GitHub
# Variant: Dark
# Description: GitHub's Primer design system - Dark Default
# Source: https://primer.style/design
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#0d1117"               # canvas default

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#161b22"             # canvas subtle
    [statusbar-fg]="#e6edf3"             # fg default

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#58a6ff"               # accent blue (signature GitHub)
    [session-fg]="#0d1117"               # canvas default
    [session-prefix-bg]="#d29922"        # attention yellow
    [session-copy-bg]="#a371f7"          # done purple
    [session-search-bg]="#d29922"        # attention yellow
    [session-command-bg]="#f778ba"       # pink

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#a371f7"       # done purple (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#30363d"     # canvas overlay
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#3fb950"         # success green

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#58a6ff"       # accent blue
    [pane-border-inactive]="#30363d"     # canvas overlay

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#21262d"                  # canvas inset
    [good-base]="#3fb950"                # success green
    [info-base]="#58a6ff"                # accent blue
    [warning-base]="#d29922"             # attention yellow
    [error-base]="#f85149"               # danger red
    [disabled-base]="#6e7681"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#161b22"               # canvas subtle
    [message-fg]="#e6edf3"               # fg default

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#161b22"                 # Popup background
    [popup-fg]="#e6edf3"                 # Popup foreground
    [popup-border]="#58a6ff"             # Popup border
    [menu-bg]="#161b22"                  # Menu background
    [menu-fg]="#e6edf3"                  # Menu foreground
    [menu-selected-bg]="#58a6ff"         # Menu selected background
    [menu-selected-fg]="#0d1117"         # Menu selected foreground
    [menu-border]="#58a6ff"              # Menu border
)
