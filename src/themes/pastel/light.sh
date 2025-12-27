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

    # Session (pink = signature pastel accent)
    [session-bg]="#d87a9e"        # pastel pink (darker for light bg)
    [session-fg]="#fafafa"
    [session-prefix-bg]="#c4b891" # pastel cream
    [session-copy-bg]="#6a9ec5"   # pastel blue (darker for light bg)

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#b086d0"  # pastel purple
    [window-inactive-base]="#d8d8d8"

    # Pane Borders
    [pane-border-active]="#d87a9e"  # pastel pink
    [pane-border-inactive]="#d8d8d8"

    # Health States (base colors - variants auto-generated)
    [ok-base]="#a0a0a0"
    [good-base]="#6a9e4f"         # pastel green (darker) ✓
    [info-base]="#6a9ec5"         # pastel blue ✓
    [warning-base]="#c4a050"      # pastel yellow (darker) ✓
    [error-base]="#b35f73"        # pastel red ✓
    [disabled-base]="#c0c0c0"

    # Messages
    [message-bg]="#f0f0f0"
    [message-fg]="#2e3440"

)
