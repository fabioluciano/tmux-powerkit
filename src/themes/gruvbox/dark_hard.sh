#!/usr/bin/env bash
# =============================================================================
# Theme: Gruvbox - Dark Hard Variant
# Description: Retro groove color scheme - dark hard variant
# Source: https://github.com/morhetz/gruvbox
# =============================================================================

declare -gA THEME_COLORS=(
		# =========================================================================
		# CORE (terminal background - used for transparent mode separators)
		# =========================================================================
		[background]="#1d2021" # bg0_hard

		# =========================================================================
		# STATUS BAR
		# =========================================================================
		[statusbar-bg]="#3c3836" # bg1
		[statusbar-fg]="#ebdbb2" # fg1

		# =========================================================================
		# SESSION (status-left)
		# =========================================================================
		[session-bg]="#d65d0e"           # Orange
		[session-fg]="#282828"           # bg0
		[session-prefix-bg]="#d79921"  # Yellow
		[session-copy-bg]="#458588"    # Blue
		[session-search-bg]="#d79921"  # Yellow
		[session-command-bg]="#b16286" # Purple

		# =========================================================================
		# WINDOW (active)
		# =========================================================================
		[window-active-base]="#d79921" # Yellow
		[window-active-style]="bold"

		# =========================================================================
		# WINDOW (inactive)
		# =========================================================================
		[window-inactive-base]="#504945" # bg2
		[window-inactive-style]="none"

		# =========================================================================
		# WINDOW STATE (activity, bell, zoomed)
		# =========================================================================
		[window-activity-style]="italics"
		[window-bell-style]="bold"
		[window-zoomed-bg]="#458588" # Blue

		# =========================================================================
		# PANE
		# =========================================================================
		[pane-border-active]="#d65d0e"   # Orange
		[pane-border-inactive]="#504945" # bg2

		# =========================================================================
		# STATUS COLORS (health/state-based for plugins)
		# =========================================================================
		[ok-base]="#665c54"       # bg3 (distinct from statusbar)
		[good-base]="#98971a"     # Green
		[info-base]="#458588"     # Blue
		[warning-base]="#d79921"  # Yellow
		[error-base]="#cc241d"    # Red
		[disabled-base]="#665c54" # bg3

		# =========================================================================
		# MESSAGE COLORS
		# =========================================================================
		[message-bg]="#3c3836" # bg1
		[message-fg]="#ebdbb2" # fg1

		# =========================================================================
		# POPUP & MENU
		# =========================================================================
		[popup-bg]="#3c3836"           # Popup background
		[popup-fg]="#ebdbb2"           # Popup foreground
		[popup-border]="#d65d0e"       # Popup border
		[menu-bg]="#3c3836"            # Menu background
		[menu-fg]="#ebdbb2"            # Menu foreground
		[menu-selected-bg]="#d65d0e" # Menu selected background
		[menu-selected-fg]="#282828" # Menu selected foreground
		[menu-border]="#d65d0e"        # Menu border
)
