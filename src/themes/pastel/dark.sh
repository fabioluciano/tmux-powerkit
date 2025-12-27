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

    # Session (pink = signature pastel accent)
    [session-bg]="#e88fb5"        # pastel pink
    [session-fg]="#1a1b26"
    [session-prefix-bg]="#f4e8c1" # pastel cream
    [session-copy-bg]="#9bc5e8"   # pastel blue

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#d4a5ff"  # pastel purple
    [window-inactive-base]="#3b4261"

    # Pane Borders
    [pane-border-active]="#e88fb5"  # pastel pink
    [pane-border-inactive]="#3b4261"

    # Health States (base colors - variants auto-generated)
    [ok-base]="#3b4261"
    [good-base]="#c5e89f"         # pastel green ✓
    [info-base]="#9bc5e8"         # pastel blue ✓
    [warning-base]="#f4e8c1"      # pastel yellow ✓
    [error-base]="#f4a799"        # pastel coral/red ✓
    [disabled-base]="#565f89"

    # Messages
    [message-bg]="#24283b"
    [message-fg]="#c0caf5"

)
