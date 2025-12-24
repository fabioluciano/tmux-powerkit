#!/usr/bin/env bash
# =============================================================================
# Theme: Catppuccin
# Variant: Mocha
# Description: Soothing pastel theme - darkest variant
# Source: https://github.com/catppuccin/catppuccin
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#313244"
    [statusbar-fg]="#cdd6f4"

    # Session
    [session-bg]="#a6e3a1"
    [session-fg]="#1e1e2e"
    [session-prefix-bg]="#f9e2af"
    [session-copy-bg]="#89dceb"

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#cba6f7"
    [window-inactive-base]="#45475a"

    # Pane Borders
    [pane-border-active]="#cba6f7"
    [pane-border-inactive]="#45475a"

    # Health States (base colors - variants auto-generated)
    [ok-base]="#313244"
    [good-base]="#a6e3a1"
    [info-base]="#89dceb"
    [warning-base]="#f9e2af"
    [error-base]="#f38ba8"
    [disabled-base]="#6c7086"

    # Messages
    [message-bg]="#313244"
    [message-fg]="#cdd6f4"

)
