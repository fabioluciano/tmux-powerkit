#!/usr/bin/env bash
# =============================================================================
# Theme: Dracula
# Variant: Dark
# Description: A dark theme for vampires
# Source: https://draculatheme.com/
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#44475a"
    [statusbar-fg]="#f8f8f2"

    # Session
    [session-bg]="#50fa7b"
    [session-fg]="#282a36"
    [session-prefix-bg]="#ffb86c"
    [session-copy-bg]="#8be9fd"

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#bd93f9"
    [window-inactive-base]="#6272a4"

    # Pane Borders
    [pane-border-active]="#bd93f9"
    [pane-border-inactive]="#6272a4"

    # Health States (base colors - variants auto-generated)
    [ok-base]="#44475a"
    [good-base]="#50fa7b"
    [info-base]="#8be9fd"
    [warning-base]="#ffb86c"
    [error-base]="#ff5555"
    [disabled-base]="#6272a4"

    # Messages
    [message-bg]="#44475a"
    [message-fg]="#f8f8f2"

)
