#!/usr/bin/env bash
# =============================================================================
# Theme: Monokai - Light Variant
# Description: Monokai Pro Light colorscheme
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
    [background]="#fafafa"               # Terminal/main background color

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#e3e2e1"             # Status bar background
    [statusbar-fg]="#2d2a2e"             # Status bar text color

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#7fb539"               # Session normal background (green)
    [session-fg]="#fafafa"               # Session text color
    [session-prefix-bg]="#f47e4a"        # Session prefix mode background (orange)
    [session-copy-bg]="#36a3d9"          # Session copy mode background (blue)
    [session-search-bg]="#e8b93e"        # Session search mode background (yellow)
    [session-command-bg]="#9975d4"       # Session command mode background (purple)

    # =========================================================================
    # WINDOW (active)
    # Variants auto-generated: -lighter (index bg), -darker (text contrast)
    # =========================================================================
    [window-active-base]="#e53b6a"       # Active window base color (pink/red)
    [window-active-style]="bold"         # Active window text style (bold, dim, italics, none)

    # =========================================================================
    # WINDOW (inactive)
    # Variants auto-generated: -lighter (index bg), -darker (text contrast)
    # =========================================================================
    [window-inactive-base]="#b8b6b4"     # Inactive window base color (gray)
    [window-inactive-style]="none"       # Inactive window text style (bold, dim, italics, none)

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"    # Window activity text style (bold, dim, italics, none)
    [window-bell-style]="bold"           # Window bell text style (bold, dim, italics, none)
    [window-zoomed-bg]="#36a3d9"         # Window zoomed indicator (blue)

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#e53b6a"       # Active pane border (pink)
    [pane-border-inactive]="#d0cfce"     # Inactive pane border

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # Variants auto-generated: -lighter (icon bg), -darker (contrast)
    # =========================================================================
    [ok-base]="#9a9897"                  # OK state base color (darker - distinct from window-inactive)
    [good-base]="#7fb539"                # Good state base color (green)
    [info-base]="#36a3d9"                # Info state base color (blue)
    [warning-base]="#f47e4a"             # Warning state base color (orange)
    [error-base]="#e53b6a"               # Error state base color (pink/red)
    [disabled-base]="#a5a3a2"            # Disabled state base color (dim gray)

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#e3e2e1"               # Message background
    [message-fg]="#2d2a2e"               # Message text color
)

# Export for PowerKit
export THEME_COLORS
