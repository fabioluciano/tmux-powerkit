#!/usr/bin/env bash
# =============================================================================
# Theme: Pastel
# Variant: Light
# Description: Soft pastel color palette with light background
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#f0f0f0"
    [statusbar-fg]="#2e3440"

    # Session
    [session-bg]="#95b86f"
    [session-fg]="#fafafa"
    [session-prefix-bg]="#c4b891"
    [session-copy-bg]="#b38470"

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#e88fb5"
    [window-inactive-base]="#d8d8d8"

    # Pane Borders
    [pane-border-active]="#e88fb5"
    [pane-border-inactive]="#d8d8d8"

    # Health States (base colors - variants auto-generated)
    [ok-base]="#e0e0e0"
    [good-base]="#95b86f"
    [info-base]="#b38470"
    [warning-base]="#c4b891"
    [error-base]="#b35f73"
    [disabled-base]="#c0c0c0"

    # Messages
    [message-bg]="#f0f0f0"
    [message-fg]="#2e3440"

)
