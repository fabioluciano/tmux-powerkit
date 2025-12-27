#!/usr/bin/env bash
# =============================================================================
# Theme: Kanagawa
# Variant: Dragon
# Description: Darker, more muted variant inspired by Katsushika Hokusai
# Source: https://github.com/rebelot/kanagawa.nvim
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#282727"      # dragonBlack4
    [statusbar-fg]="#c5c9c5"      # dragonWhite

    # Session (dragonViolet = signature muted purple)
    [session-bg]="#8992a7"        # dragonViolet
    [session-fg]="#181616"        # dragonBlack3
    [session-prefix-bg]="#b6927b" # dragonOrange
    [session-copy-bg]="#8ba4b0"   # dragonBlue2

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#a292a3"  # dragonPink
    [window-inactive-base]="#393836" # dragonBlack5

    # Pane Borders
    [pane-border-active]="#8992a7"  # dragonViolet
    [pane-border-inactive]="#393836" # dragonBlack5

    # Health States (base colors - variants auto-generated)
    [ok-base]="#282727"           # dragonBlack4
    [good-base]="#87a987"         # dragonGreen ✓
    [info-base]="#8ba4b0"         # dragonBlue2 ✓
    [warning-base]="#c4b28a"      # dragonYellow ✓
    [error-base]="#c4746e"        # dragonRed ✓
    [disabled-base]="#625e5a"     # (muted)

    # Messages
    [message-bg]="#282727"        # dragonBlack4
    [message-fg]="#c5c9c5"        # dragonWhite

)
