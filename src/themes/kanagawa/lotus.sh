#!/usr/bin/env bash
# =============================================================================
# Theme: Kanagawa
# Variant: Lotus
# Description: Light theme inspired by Katsushika Hokusai
# Source: https://github.com/rebelot/kanagawa.nvim
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#e4d794"      # lotusWhite5
    [statusbar-fg]="#545464"      # lotusInk1

    # Session (lotusPink = signature accent)
    [session-bg]="#b35b79"        # lotusPink
    [session-fg]="#f2ecbc"        # lotusWhite3
    [session-prefix-bg]="#cc6d00" # lotusOrange
    [session-copy-bg]="#4e8ca2"   # lotusBlue2

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#43436c"  # lotusInk2
    [window-inactive-base]="#c9cbd1" # (muted surface)

    # Pane Borders
    [pane-border-active]="#b35b79"  # lotusPink
    [pane-border-inactive]="#c9cbd1" # (muted surface)

    # Health States (base colors - variants auto-generated)
    [ok-base]="#716e61"           # (muted)
    [good-base]="#6f894e"         # lotusGreen ✓
    [info-base]="#4e8ca2"         # lotusBlue2 ✓
    [warning-base]="#77713f"      # lotusYellow ✓
    [error-base]="#c84053"        # lotusRed ✓
    [disabled-base]="#8a8980"     # (disabled)

    # Messages
    [message-bg]="#e4d794"        # lotusWhite5
    [message-fg]="#545464"        # lotusInk1

)
