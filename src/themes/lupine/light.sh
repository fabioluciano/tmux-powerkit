#!/usr/bin/env bash
# =============================================================================
# Theme: Lupine - Light
# Description: Clean light theme inspired by the Lupine palette
# Source: https://github.com/lupine-dev
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#fafafa"               # background

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#fafafa"             # background
    [statusbar-fg]="#212121"             # foreground

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#3264eb"               # accent/blue
    [session-fg]="#fafafa"               # background (contrast)
    [session-prefix-bg]="#026fde"        # yellow
    [session-copy-bg]="#4a2fd0"          # green
    [session-search-bg]="#3264eb"        # accent
    [session-command-bg]="#8a4ad7"       # magenta

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#8a4ad7"       # magenta (distinctive)

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#dedede"     # darker_background (lighter contrast)

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-zoomed-bg]="#0c67de"         # cyan

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#3264eb"       # accent/blue
    [pane-border-inactive]="#d0d0d0"     # selection

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # =========================================================================
    [ok-base]="#d0d0d0"                  # selection (distinct from statusbar-bg)
    [good-base]="#4a2fd0"                # green
    [info-base]="#0c67de"                # cyan
    [warning-base]="#026fde"             # yellow
    [error-base]="#c900c4"               # red
    [disabled-base]="#9e9e9e"            # muted

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#fafafa"               # background
    [message-fg]="#212121"               # foreground

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#fafafa"                 # Popup background
    [popup-fg]="#212121"                 # Popup foreground
    [popup-border]="#3264eb"             # Popup border
    [menu-bg]="#fafafa"                  # Menu background
    [menu-fg]="#212121"                  # Menu foreground
    [menu-selected-bg]="#3264eb"         # Menu selected background
    [menu-selected-fg]="#fafafa"         # Menu selected foreground
    [menu-border]="#3264eb"              # Menu border
)

export THEME_COLORS
