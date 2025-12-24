#!/usr/bin/env bash
# =============================================================================
# Theme: Kiribyte
# Variant: Light
# Description: Soft paper-like light theme with pastel accents
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#e0dfd9"
    [statusbar-fg]="#3b3d4a"

    # Session
    [session-bg]="#6a8c4f"
    [session-fg]="#f5f4f0"
    [session-prefix-bg]="#9a7d4d"
    [session-copy-bg]="#4a8fa8"

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#9b7fc9"
    [window-inactive-base]="#d4d3cc"

    # Pane Borders
    [pane-border-active]="#9b7fc9"
    [pane-border-inactive]="#d4d3cc"

    # Health States (base colors - variants auto-generated)
    [ok-base]="#6d7187"
    [good-base]="#6a8c4f"
    [info-base]="#4a8fa8"
    [warning-base]="#9a7d4d"
    [error-base]="#c94d66"
    [disabled-base]="#8a8fb5"

    # Messages
    [message-bg]="#e0dfd9"
    [message-fg]="#3b3d4a"

)
