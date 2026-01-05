#!/usr/bin/env bash
# =============================================================================
# Theme: Catppuccin - Macchiato Variant
# Description: Soothing pastel theme - dark variant
# Source: https://github.com/catppuccin/catppuccin
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#24273a"               # base

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#363a4f"             # surface0
    [statusbar-fg]="#cad3f5"             # text

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#c6a0f6"               # mauve (signature Catppuccin)
    [session-fg]="#24273a"               # base
    [session-prefix-bg]="#f5a97f"        # peach
    [session-copy-bg]="#7dc4e4"          # sapphire
    [session-search-bg]="#eed49f"        # yellow
    [session-command-bg]="#f5bde6"       # pink

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#f5bde6"       # pink (distinctive)
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#494d64"     # surface1
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#7dc4e4"         # sapphire

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#c6a0f6"       # mauve
    [pane-border-inactive]="#494d64"     # surface1

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#494d64"                  # surface1 (distinct from statusbar-bg)
    [good-base]="#a6da95"                # green
    [info-base]="#8aadf4"                # blue
    [warning-base]="#eed49f"             # yellow
    [error-base]="#ed8796"               # red
    [disabled-base]="#6e738d"            # overlay0

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#363a4f"               # surface0
    [message-fg]="#cad3f5"               # text

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#363a4f"                 # Popup background
    [popup-fg]="#cad3f5"                 # Popup foreground
    [popup-border]="#c6a0f6"             # Popup border
    [menu-bg]="#363a4f"                  # Menu background
    [menu-fg]="#cad3f5"                  # Menu foreground
    [menu-selected-bg]="#c6a0f6"         # Menu selected background
    [menu-selected-fg]="#24273a"         # Menu selected foreground
    [menu-border]="#c6a0f6"              # Menu border
)
