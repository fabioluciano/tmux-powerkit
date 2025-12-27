#!/usr/bin/env bash
# =============================================================================
# Theme: Dracula
# Variant: Dark
# Description: A dark theme for vampires
# Source: https://draculatheme.com/
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#44475a"      # selection
    [statusbar-fg]="#f8f8f2"      # foreground

    # Session (purple = signature Dracula color)
    [session-bg]="#bd93f9"        # purple
    [session-fg]="#282a36"        # background
    [session-prefix-bg]="#ffb86c" # orange
    [session-copy-bg]="#8be9fd"   # cyan

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#ff79c6"  # pink
    [window-inactive-base]="#6272a4" # comment

    # Pane Borders
    [pane-border-active]="#bd93f9"  # purple
    [pane-border-inactive]="#6272a4" # comment

    # Health States (base colors - variants auto-generated)
    [ok-base]="#44475a"           # selection
    [good-base]="#50fa7b"         # green ✓
    [info-base]="#8be9fd"         # cyan (blue) ✓
    [warning-base]="#f1fa8c"      # yellow ✓
    [error-base]="#ff5555"        # red ✓
    [disabled-base]="#6272a4"     # comment

    # Messages
    [message-bg]="#44475a"        # selection
    [message-fg]="#f8f8f2"        # foreground

)
