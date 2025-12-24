#!/usr/bin/env bash
# =============================================================================
# Theme: Pastel
# Variant: Dark
# Description: Soft pastel color palette with dark background
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#24283b"
    [statusbar-fg]="#c0caf5"

    # Session
    [session-bg]="#c5e89f"
    [session-fg]="#1a1b26"
    [session-prefix-bg]="#f4e8c1"
    [session-copy-bg]="#f4c4a0"

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#e88fb5"
    [window-inactive-base]="#3b4261"

    # Pane Borders
    [pane-border-active]="#e88fb5"
    [pane-border-inactive]="#3b4261"

    # Health States (base colors - variants auto-generated)
    [ok-base]="#3b4261"
    [good-base]="#c5e89f"
    [info-base]="#f4c4a0"
    [warning-base]="#f4e8c1"
    [error-base]="#f4a799"
    [disabled-base]="#565f89"

    # Messages
    [message-bg]="#24283b"
    [message-fg]="#c0caf5"

)
