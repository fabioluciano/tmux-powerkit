#!/usr/bin/env bash
# =============================================================================
# Theme: Catppuccin - Latte Variant
# Description: Soothing pastel theme - light variant
# Source: https://github.com/catppuccin/catppuccin
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#eff1f5"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#ccd0da"             # surface0
    [statusbar-fg]="#4c4f69"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#8839ef"               # mauve (signature Catppuccin)
    [session-fg]="#eff1f5"               # base
    [session-prefix-bg]="#fe640b"        # peach
    [session-copy-bg]="#209fb5"          # sapphire
    [session-search-bg]="#df8e1d"        # yellow
    [session-command-bg]="#ea76cb"       # pink

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#ea76cb"       # pink (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#bcc0cc"     # surface1
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#209fb5"         # sapphire

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#8839ef"       # mauve
    [pane-border-inactive]="#bcc0cc"     # surface1

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#6c6f85"                  # subtext0
    [good-base]="#40a02b"                # green
    [info-base]="#1e66f5"                # blue
    [warning-base]="#df8e1d"             # yellow
    [error-base]="#d20f39"               # red
    [disabled-base]="#9ca0b0"            # overlay0

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#ccd0da"               # surface0
    [message-fg]="#4c4f69"               # text

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#ccd0da"                 # Popup background
    [popup-fg]="#4c4f69"                 # Popup foreground
    [popup-border]="#8839ef"             # Popup border
    [menu-bg]="#ccd0da"                  # Menu background
    [menu-fg]="#4c4f69"                  # Menu foreground
    [menu-selected-bg]="#8839ef"         # Menu selected background
    [menu-selected-fg]="#eff1f5"         # Menu selected foreground
    [menu-border]="#8839ef"              # Menu border
)
