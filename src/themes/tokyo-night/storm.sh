#!/usr/bin/env bash
# =============================================================================
# Theme: Tokyo Night
# Variant: Storm
# Description: Slightly lighter background than Night variant
# Source: https://github.com/folke/tokyonight.nvim
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#292e42"
    [statusbar-fg]="#c0caf5"

    # Session
    [session-bg]="#9ece6a"
    [session-fg]="#24283b"
    [session-prefix-bg]="#e0af68"
    [session-copy-bg]="#7dcfff"

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#bb9af7"
    [window-inactive-base]="#3b4261"

    # Pane Borders
    [pane-border-active]="#7aa2f7"
    [pane-border-inactive]="#3b4261"

    # Health States (base colors - variants auto-generated)
    [ok-base]="#394b70"
    [good-base]="#9ece6a"
    [info-base]="#7dcfff"
    [warning-base]="#e0af68"
    [error-base]="#f7768e"
    [disabled-base]="#565f89"

    # Messages
    [message-bg]="#292e42"
    [message-fg]="#c0caf5"

)
