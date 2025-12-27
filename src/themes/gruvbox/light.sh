#!/usr/bin/env bash
# =============================================================================
# Theme: Gruvbox
# Variant: Light
# Description: Retro groove color scheme - light variant
# Source: https://github.com/morhetz/gruvbox
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar
    [statusbar-bg]="#ebdbb2"      # fg1 (light bg)
    [statusbar-fg]="#3c3836"      # bg1 (dark text)

    # Session (orange = warm Gruvbox signature)
    [session-bg]="#af3a03"        # orange faded
    [session-fg]="#fbf1c7"        # light0
    [session-prefix-bg]="#b57614" # yellow faded
    [session-copy-bg]="#076678"   # blue faded

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#b57614"  # yellow faded
    [window-inactive-base]="#d5c4a1" # fg2

    # Pane Borders
    [pane-border-active]="#af3a03"  # orange faded
    [pane-border-inactive]="#d5c4a1" # fg2

    # Health States (base colors - variants auto-generated)
    [ok-base]="#665c54"           # bg3
    [good-base]="#79740e"         # green faded ✓
    [info-base]="#076678"         # blue faded ✓
    [warning-base]="#b57614"      # yellow faded ✓
    [error-base]="#9d0006"        # red faded ✓
    [disabled-base]="#bdae93"     # fg3

    # Messages
    [message-bg]="#ebdbb2"        # fg1
    [message-fg]="#3c3836"        # bg1

)
