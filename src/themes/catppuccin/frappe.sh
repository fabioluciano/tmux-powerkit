#!/usr/bin/env bash
# =============================================================================
# Theme: Catppuccin - Frappé Variant
# Description: Soothing pastel theme - medium-dark variant
# Source: https://github.com/catppuccin/catppuccin
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#303446"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#414559"             # surface0
    [statusbar-fg]="#c6d0f5"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#ca9ee6"               # mauve (signature Catppuccin)
    [session-fg]="#303446"               # base
    [session-prefix-bg]="#ef9f76"        # peach
    [session-copy-bg]="#85c1dc"          # sapphire
    [session-search-bg]="#e5c890"        # yellow
    [session-command-bg]="#f4b8e4"       # pink

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#f4b8e4"       # pink (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#51576d"     # surface1
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#85c1dc"         # sapphire

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#ca9ee6"       # mauve
    [pane-border-inactive]="#51576d"     # surface1

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#51576d"                  # surface1 (distinct from statusbar-bg)
    [good-base]="#a6d189"                # green
    [info-base]="#8caaee"                # blue
    [warning-base]="#e5c890"             # yellow
    [error-base]="#e78284"               # red
    [disabled-base]="#737994"            # overlay0

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#414559"               # surface0
    [message-fg]="#c6d0f5"               # text

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#414559"                 # Popup background
    [popup-fg]="#c6d0f5"                 # Popup foreground
    [popup-border]="#ca9ee6"             # Popup border
    [menu-bg]="#414559"                  # Menu background
    [menu-fg]="#c6d0f5"                  # Menu foreground
    [menu-selected-bg]="#ca9ee6"         # Menu selected background
    [menu-selected-fg]="#303446"         # Menu selected foreground
    [menu-border]="#ca9ee6"              # Menu border
)
