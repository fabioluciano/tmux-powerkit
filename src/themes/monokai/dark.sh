#!/usr/bin/env bash
# =============================================================================
# Theme: Monokai - Dark Variant
# Description: Classic Monokai Pro dark colorscheme
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
    [background]="#2d2a2e"               # Terminal/main background color

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#403e41"             # Status bar background
    [statusbar-fg]="#fcfcfa"             # Status bar text color

    # =========================================================================
    # SESSION (status-left)
    # =========================================================================
    [session-bg]="#a9dc76"               # Session normal background (green)
    [session-fg]="#2d2a2e"               # Session text color
    [session-prefix-bg]="#fc9867"        # Session prefix mode background (orange)
    [session-copy-bg]="#78dce8"          # Session copy mode background (blue)
    [session-search-bg]="#ffd866"        # Session search mode background (yellow)
    [session-command-bg]="#ab9df2"       # Session command mode background (purple)

    # =========================================================================
    # WINDOW (active)
    # Variants auto-generated: -lighter (index bg), -darker (text contrast)
    # =========================================================================
    [window-active-base]="#ff6188"       # Active window base color (pink/red)
    [window-active-style]="bold"         # Active window text style (bold, dim, italics, none)

    # =========================================================================
    # WINDOW (inactive)
    # Variants auto-generated: -lighter (index bg), -darker (text contrast)
    # =========================================================================
    [window-inactive-base]="#5b595c"     # Inactive window base color (gray)
    [window-inactive-style]="none"       # Inactive window text style (bold, dim, italics, none)

    # =========================================================================
    # WINDOW STATE (activity, bell, zoomed)
    # =========================================================================
    [window-activity-style]="italics"    # Window activity text style (bold, dim, italics, none)
    [window-bell-style]="bold"           # Window bell text style (bold, dim, italics, none)
    [window-zoomed-bg]="#78dce8"         # Window zoomed indicator (blue)

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#ff6188"       # Active pane border (pink)
    [pane-border-inactive]="#5b595c"     # Inactive pane border

    # =========================================================================
    # STATUS COLORS (health/state-based for plugins)
    # Variants auto-generated: -lighter (icon bg), -darker (contrast)
    # =========================================================================
    [ok-base]="#5b595c"                  # OK state base color (muted - distinct from statusbar-bg)
    [good-base]="#a9dc76"                # Good state base color (green)
    [info-base]="#78dce8"                # Info state base color (blue)
    [warning-base]="#fc9867"             # Warning state base color (orange)
    [error-base]="#ff6188"               # Error state base color (pink/red)
    [disabled-base]="#727072"            # Disabled state base color (dim gray)

    # =========================================================================
    # MESSAGE COLORS
    # =========================================================================
    [message-bg]="#403e41"               # Message background
    [message-fg]="#fcfcfa"               # Message text color
)

# Export for PowerKit
export THEME_COLORS
