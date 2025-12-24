#!/usr/bin/env bash
# =============================================================================
# Theme: One Dark
# Variant: Dark
# Description: A dark syntax theme inspired by Atom
# Source: https://atom.io/themes/one-dark-syntax
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#2c323c"
    [statusbar-fg]="#abb2bf"

    # Session
    [session-bg]="#98c379"
    [session-fg]="#282c34"
    [session-prefix-bg]="#d19a66"
    [session-copy-bg]="#56b6c2"

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#61afef"
    [window-inactive-base]="#3e4451"

    # Pane Borders
    [pane-border-active]="#61afef"
    [pane-border-inactive]="#3e4451"

    # Health States (base colors - variants auto-generated)
    [ok-base]="#2c323c"
    [good-base]="#98c379"
    [info-base]="#56b6c2"
    [warning-base]="#d19a66"
    [error-base]="#e06c75"
    [disabled-base]="#5c6370"

    # Messages
    [message-bg]="#2c323c"
    [message-fg]="#abb2bf"

)
