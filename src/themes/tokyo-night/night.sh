#!/usr/bin/env bash
# =============================================================================
# Theme: Tokyo Night - Night Variant
# Description: Neo-Tokyo inspired dark theme
# =============================================================================
# Theme colors use SEMANTIC names that indicate WHERE they are used.
# Universal colors (transparent, none, white, black) are in color_generator.sh
#
# COLOR VARIANT SYSTEM:
# For colors listed in POWERKIT_COLORS_WITH_VARIANTS, the system auto-generates:
#   - {color}-lighter: +18.9% brightness (used for index/icon backgrounds)
#   - {color}-darker:  -44.2% brightness (used for text/contrast)
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE (terminal background - used for transparent mode separators)
    # =========================================================================
    [background]="#1a1b26"               # Terminal/main background color

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#292e42"             # Status bar background
    [statusbar-fg]="#c0caf5"             # Status bar text color

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#9ece6a"               # Session normal background
    [session-fg]="#292e42"               # Session text color
    [session-prefix-bg]="#e0af68"        # Session prefix mode background
    [session-copy-bg]="#7dcfff"          # Session copy mode background
    [session-search-bg]="#9ece6a"        # Session search mode background
    [session-command-bg]="#bb9af7"       # Session command mode background

    # =========================================================================
    # WINDOW (active)
    # Variants auto-generated: -lighter (index bg), -darker (text contrast)
    # =========================================================================
    [window-active-base]="#9d7cd8"       # Active window base color
    [window-active-style]="bold"         # Active window text style (bold, dim, italics, none)

    # =========================================================================
    # WINDOW (inactive)
    # Variants auto-generated: -lighter (index bg), -darker (text contrast)
    # =========================================================================
    [window-inactive-base]="#3b4261"     # Inactive window base color
    [window-inactive-style]="none"       # Inactive window text style (bold, dim, italics, none)

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"    # Window activity text style (bold, dim, italics, none)
    [window-bell-style]="bold"           # Window bell text style (bold, dim, italics, none)
    [window-zoomed-bg]="#7dcfff"         # Window zoomed indicator

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#7aa2f7"       # Active pane border
    [pane-border-inactive]="#3b4261"     # Inactive pane border

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # Variants auto-generated: -lighter (icon bg), -darker (contrast)
    # =========================================================================
    [ok-base]="#394b70"                  # OK state base color
    [good-base]="#9ece6a"                # Good state base color (better than ok)
    [info-base]="#7dcfff"                # Info state base color
    [warning-base]="#e0af68"             # Warning state base color
    [error-base]="#f7768e"               # Error state base color
    [disabled-base]="#565f89"            # Disabled state base color

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#292e42"               # Message background
    [message-fg]="#c0caf5"               # Message text color

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#292e42"                 # Popup background
    [popup-fg]="#c0caf5"                 # Popup foreground
    [popup-border]="#7aa2f7"             # Popup border
    [menu-bg]="#292e42"                  # Menu background
    [menu-fg]="#c0caf5"                  # Menu foreground
    [menu-selected-bg]="#9ece6a"         # Menu selected background
    [menu-selected-fg]="#292e42"         # Menu selected foreground
    [menu-border]="#7aa2f7"              # Menu border
)
