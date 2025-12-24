#!/usr/bin/env bash
# =============================================================================
# Theme: Kanagawa
# Variant: Lotus
# Description: Light theme inspired by Katsushika Hokusai
# Source: https://github.com/rebelot/kanagawa.nvim
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#e4d794"
    [statusbar-fg]="#545464"

    # Session
    [session-bg]="#6f894e"
    [session-fg]="#f2ecbc"
    [session-prefix-bg]="#77713f"
    [session-copy-bg]="#4e8ca2"

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#b35b79"
    [window-inactive-base]="#c9cbd1"

    # Pane Borders
    [pane-border-active]="#b35b79"
    [pane-border-inactive]="#c9cbd1"

    # Health States (base colors - variants auto-generated)
    [ok-base]="#716e61"
    [good-base]="#6f894e"
    [info-base]="#4e8ca2"
    [warning-base]="#77713f"
    [error-base]="#c84053"
    [disabled-base]="#8a8980"

    # Messages
    [message-bg]="#e4d794"
    [message-fg]="#545464"

)
