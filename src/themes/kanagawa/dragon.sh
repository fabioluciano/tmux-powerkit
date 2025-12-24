#!/usr/bin/env bash
# =============================================================================
# Theme: Kanagawa
# Variant: Dragon
# Description: Darker, more muted variant inspired by Katsushika Hokusai
# Source: https://github.com/rebelot/kanagawa.nvim
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#282727"
    [statusbar-fg]="#c5c9c5"

    # Session
    [session-bg]="#87a987"
    [session-fg]="#181616"
    [session-prefix-bg]="#c4b28a"
    [session-copy-bg]="#8ba4b0"

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#8992a7"
    [window-inactive-base]="#393836"

    # Pane Borders
    [pane-border-active]="#8992a7"
    [pane-border-inactive]="#393836"

    # Health States (base colors - variants auto-generated)
    [ok-base]="#223249"
    [good-base]="#87a987"
    [info-base]="#8ba4b0"
    [warning-base]="#c4b28a"
    [error-base]="#c4746e"
    [disabled-base]="#625e5a"

    # Messages
    [message-bg]="#282727"
    [message-fg]="#c5c9c5"

)
