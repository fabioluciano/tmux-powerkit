#!/usr/bin/env bash
# =============================================================================
# Theme: Tokyo Night
# Variant: Day
# Description: Light theme with vibrant Tokyo Night colors
# Source: https://github.com/folke/tokyonight.nvim
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#c4c8da"
    [statusbar-fg]="#3760bf"

    # Session
    [session-bg]="#587539"
    [session-fg]="#e1e2e7"
    [session-prefix-bg]="#8c6c3e"
    [session-copy-bg]="#007197"
    [session-search-bg]="#587539"
    [session-command-bg]="#9854f1"

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#9854f1"
    [window-inactive-base]="#b7c1e3"
    [window-zoomed-bg]="#007197"

    # Pane Borders
    [pane-border-active]="#9854f1"
    [pane-border-inactive]="#b7c1e3"

    # Health States (base colors - variants auto-generated)
    [ok-base]="#6172b0"
    [good-base]="#587539"
    [info-base]="#007197"
    [warning-base]="#8c6c3e"
    [error-base]="#f52a65"
    [disabled-base]="#a1a6c5"

    # Messages
    [message-bg]="#c4c8da"
    [message-fg]="#3760bf"
    [neutral-base]="#9ca0b8"
    [selection-bg]="#c4c8da"
    [selection-fg]="#3760bf"
    [search-match-bg]="#8c6c3e"
    [search-match-fg]="#e1e2e7"

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#c4c8da"           # Popup background
    [popup-fg]="#3760bf"           # Popup foreground
    [popup-border]="#9854f1"       # Popup border
    [menu-bg]="#c4c8da"            # Menu background
    [menu-fg]="#3760bf"            # Menu foreground
    [menu-selected-bg]="#587539" # Menu selected background
    [menu-selected-fg]="#e1e2e7" # Menu selected foreground
    [menu-border]="#9854f1"        # Menu border

)
