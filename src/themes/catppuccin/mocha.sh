#!/usr/bin/env bash
# =============================================================================
# Theme: Catppuccin - Mocha Variant
# Description: Soothing pastel theme - darkest variant
# Source: https://github.com/catppuccin/catppuccin
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#1e1e2e"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#313244"             # surface0
    [statusbar-fg]="#cdd6f4"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#cba6f7"               # mauve (signature Catppuccin)
    [session-fg]="#1e1e2e"               # base
    [session-prefix-bg]="#fab387"        # peach
    [session-copy-bg]="#74c7ec"          # sapphire
    [session-search-bg]="#f9e2af"        # yellow
    [session-command-bg]="#f5c2e7"       # pink

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#f5c2e7"       # pink (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#45475a"     # surface1
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#74c7ec"         # sapphire

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#cba6f7"       # mauve
    [pane-border-inactive]="#45475a"     # surface1

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#45475a"                  # surface1 (distinct from statusbar-bg)
    [good-base]="#a6e3a1"                # green
    [info-base]="#89b4fa"                # blue
    [warning-base]="#f9e2af"             # yellow
    [error-base]="#f38ba8"               # red
    [disabled-base]="#6c7086"            # overlay0

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#313244"               # surface0
    [message-fg]="#cdd6f4"               # text

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#313244"                 # Popup background
    [popup-fg]="#cdd6f4"                 # Popup foreground
    [popup-border]="#cba6f7"             # Popup border
    [menu-bg]="#313244"                  # Menu background
    [menu-fg]="#cdd6f4"                  # Menu foreground
    [menu-selected-bg]="#cba6f7"         # Menu selected background
    [menu-selected-fg]="#1e1e2e"         # Menu selected foreground
    [menu-border]="#cba6f7"              # Menu border
)
