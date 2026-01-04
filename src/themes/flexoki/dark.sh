#!/usr/bin/env bash
# =============================================================================
# Theme: Flexoki
# Variant: Dark
# Description: An inky color scheme for prose and code
# Source: https://stephango.com/flexoki
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#100f0f"               # black

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#1c1b1a"             # base 950
    [statusbar-fg]="#cecdc3"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#d0a215"               # yellow (signature Flexoki)
    [session-fg]="#100f0f"               # background
    [session-prefix-bg]="#da702c"        # orange
    [session-copy-bg]="#879a39"          # green
    [session-search-bg]="#d0a215"        # yellow
    [session-command-bg]="#4385be"       # blue

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#da702c"       # orange (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#343331"     # base 850
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#3aa99f"         # cyan

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#d0a215"       # yellow
    [pane-border-inactive]="#343331"     # base 850

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#343331"                  # base 850 (distinct from statusbar-bg)
    [good-base]="#879a39"                # green
    [info-base]="#4385be"                # blue
    [warning-base]="#d0a215"             # yellow
    [error-base]="#d14d41"               # red
    [disabled-base]="#575653"            # base 700

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#1c1b1a"               # base 950
    [message-fg]="#cecdc3"               # text
)
