#!/usr/bin/env bash
# =============================================================================
# Theme: Flexoki
# Variant: Light
# Description: An inky color scheme for prose and code - light variant
# Source: https://stephango.com/flexoki
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#fffcf0"               # paper

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#f2f0e5"             # base 100
    [statusbar-fg]="#1c1b1a"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#ad8301"               # yellow darker (signature Flexoki)
    [session-fg]="#fffcf0"               # background
    [session-prefix-bg]="#bc5215"        # orange darker
    [session-copy-bg]="#66800b"          # green darker
    [session-search-bg]="#ad8301"        # yellow darker
    [session-command-bg]="#205ea6"       # blue darker

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#bc5215"       # orange darker (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#e6e4d9"     # base 200
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#24837b"         # cyan darker

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#ad8301"       # yellow darker
    [pane-border-inactive]="#e6e4d9"     # base 200

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#b7b5ac"                  # base 400 (distinct from statusbar-bg)
    [good-base]="#66800b"                # green darker
    [info-base]="#205ea6"                # blue darker
    [warning-base]="#ad8301"             # yellow darker
    [error-base]="#af3029"               # red darker
    [disabled-base]="#878580"            # base 500

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#f2f0e5"               # base 100
    [message-fg]="#1c1b1a"               # text
)
