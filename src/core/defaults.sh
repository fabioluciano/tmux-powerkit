#!/usr/bin/env bash
# =============================================================================
# PowerKit Core: Defaults Configuration
# =============================================================================
# Description: All default values for PowerKit configuration options
#
# This file defines all default values that users can override via tmux.conf.
# Each option is documented with its purpose, valid values, and examples.
#
# Override syntax in tmux.conf:
#   set -g @powerkit_<option> "value"
#   set -g @powerkit_plugin_<plugin>_<option> "value"
#
# shellcheck disable=SC2034
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "defaults" && return 0

# =============================================================================
# BASE DEFAULTS (Internal - reused across plugins for DRY)
# =============================================================================
# These are internal defaults used to maintain consistency across plugins.
# They are not directly configurable by users.

_DEFAULT_CACHE_DIRECTORY="tmux-powerkit"

# Semantic color names (resolved from theme)
_DEFAULT_ACCENT="ok-bg"
_DEFAULT_ACCENT_ICON="ok-icon-bg"
_DEFAULT_INFO="info-bg"
_DEFAULT_INFO_ICON="info-icon-bg"
_DEFAULT_WARNING="warning-bg"
_DEFAULT_WARNING_ICON="warning-icon-bg"
_DEFAULT_ERROR="error-bg"
_DEFAULT_ERROR_ICON="error-icon-bg"

# Default thresholds for plugins with warning/critical levels
_DEFAULT_WARNING_THRESHOLD="70"
_DEFAULT_CRITICAL_THRESHOLD="90"

# Common display values
_DEFAULT_SEPARATOR=" | "
_DEFAULT_MAX_LENGTH="40"
_DEFAULT_POPUP_SIZE="50%"

# Timeouts and TTLs (in seconds)
_DEFAULT_TIMEOUT_SHORT="5"
_DEFAULT_TIMEOUT_MEDIUM="10"
_DEFAULT_TIMEOUT_LONG="30"
_DEFAULT_CACHE_TTL_SHORT="60"         # 1 minute
_DEFAULT_CACHE_TTL_MEDIUM="300"       # 5 minutes
_DEFAULT_CACHE_TTL_LONG="3600"        # 1 hour
_DEFAULT_CACHE_TTL_DAY="86400"        # 24 hours

# Toast/Display timeouts (in milliseconds)
_DEFAULT_TOAST_SHORT="3000"           # 3 seconds
_DEFAULT_TOAST_MEDIUM="5000"          # 5 seconds
_DEFAULT_TOAST_LONG="10000"           # 10 seconds

# =============================================================================
# THEME CONFIGURATION
# =============================================================================
# @powerkit_theme - Theme name
# Available themes (32 total):
#   atom, ayu, catppuccin, cobalt2, darcula, dracula, everforest, flexoki,
#   github, gruvbox, horizon, iceberg, kanagawa, kiribyte, material, molokai,
#   monokai, moonlight, night-owl, nord, oceanic-next, onedark, pastel,
#   poimandres, rose-pine, slack, snazzy, solarized, spacegray, synthwave,
#   tokyo-night, vesper
POWERKIT_DEFAULT_THEME="catppuccin"

# @powerkit_theme_variant - Theme variant (depends on selected theme)
# Variants per theme:
#   atom: dark
#   ayu: dark, mirage, light
#   catppuccin: mocha, macchiato, frappe, latte
#   cobalt2: default
#   darcula: default
#   dracula: dark
#   everforest: dark, light
#   flexoki: dark, light
#   github: dark, light
#   gruvbox: dark, light
#   horizon: default
#   iceberg: dark, light
#   kanagawa: dragon, lotus
#   kiribyte: dark, light
#   material: default, ocean, palenight, lighter
#   molokai: dark
#   monokai: dark, light
#   moonlight: default
#   night-owl: default, light
#   nord: dark
#   oceanic-next: default, darker
#   onedark: dark
#   pastel: dark, light
#   poimandres: default
#   rose-pine: main, moon, dawn
#   slack: dark
#   snazzy: default
#   solarized: dark, light
#   spacegray: dark
#   synthwave: 84
#   tokyo-night: night, storm, day
#   vesper: default
POWERKIT_DEFAULT_THEME_VARIANT="mocha"

# @powerkit_custom_theme_path - Path to custom theme file
# When set, overrides theme/variant settings
# Must point to a valid theme file with THEME_COLORS array
# Example: "~/.config/tmux/my-theme.sh"
POWERKIT_DEFAULT_CUSTOM_THEME_PATH=""

# @powerkit_transparent - Enable transparent backgrounds
# Values: "true", "false"
# When true, uses terminal background color for status bar
POWERKIT_DEFAULT_TRANSPARENT="false"

# =============================================================================
# PLUGIN CONFIGURATION
# =============================================================================
# @powerkit_plugins - Comma-separated list of plugins to enable
# Available plugins (42 total):
#   System Monitoring:
#     battery, cpu, disk, fan, gpu, iops, loadavg, memory, temperature, uptime,
#     volume, brightness
#   Network:
#     external_ip, netspeed, ping, vpn, weather, wifi, ssh
#   Development:
#     git, github, gitlab, bitbucket, jira, kubernetes, terraform, cloud
#   Media:
#     nowplaying, audiodevices, camera, microphone
#   Productivity:
#     datetime, timezones, pomodoro, smartkey, bitwarden
#   Financial:
#     crypto, stocks
#   Services:
#     cloudstatus, packages, bluetooth, hostname
#
# Plugin Groups:
#   Use group(...) syntax to visually group plugins with a shared background:
#     group(cpu,memory)           - Groups plugins with automatic group color
#     group(git,github,gitlab)    - Another group with next color from palette
#
#   Example with groups:
#     set -g @powerkit_plugins "group(cpu,memory),group(git,github),datetime"
#
#   Groups are colored automatically using @powerkit_plugin_group_colors palette.
#   Each group gets the next color from the palette in order.
POWERKIT_DEFAULT_PLUGINS="datetime,battery,cpu,memory,hostname,git"

# @powerkit_plugin_group_colors - Color palette for plugin groups
# Comma-separated list of theme colors or hex values
# Groups are assigned colors in order from this palette
# Colors are applied to the background between plugins in the same group
# Values: theme color names (with -darker variant) or hex colors
# Default palette uses theme colors for visual harmony:
#   info-base-darker          - Blue tones (network, info plugins)
#   window-active-base-darker - Purple tones (development plugins)
#   ok-base-darker            - Green tones (status, success plugins)
#   warning-base-darker       - Yellow tones (alert plugins)
#   error-base-darker         - Red tones (critical plugins)
#   disabled-base             - Gray tones (neutral plugins)
POWERKIT_DEFAULT_PLUGIN_GROUP_COLORS="info-base-darker,window-active-base-darker,ok-base-darker,warning-base-darker,error-base-darker,disabled-base"

# =============================================================================
# STATUS BAR CONFIGURATION
# =============================================================================
# @powerkit_status_interval - Refresh interval in seconds
# Values: any positive integer
# Lower values = more responsive but higher CPU usage
# Recommended: 5 (balanced), 2 (responsive), 10 (low CPU)
POWERKIT_DEFAULT_STATUS_INTERVAL="5"

# @powerkit_status_position - Status bar position
# Values: "top", "bottom"
POWERKIT_DEFAULT_STATUS_POSITION="top"

# @powerkit_status_justify - Window list alignment
# Values: "left", "centre", "right"
POWERKIT_DEFAULT_STATUS_JUSTIFY="left"

# Internal: Maximum length for status-left and status-right
POWERKIT_DEFAULT_STATUS_LEFT_LENGTH="100"
POWERKIT_DEFAULT_STATUS_RIGHT_LENGTH="500"

# @powerkit_bar_layout - Status bar layout mode
# Values:
#   "single" - Traditional single status line (default)
#   "double" - Two status lines: Line 0 = Session + Windows, Line 1 = Plugins
POWERKIT_DEFAULT_BAR_LAYOUT="single"

# @powerkit_status_order - Element order in status bar
# Comma-separated list of: session, windows, plugins
#
# 2-element orders (auto-expanded with windows):
#   "session,plugins" - Session+windows LEFT, plugins RIGHT (default)
#   "plugins,session" - Plugins LEFT, windows+session RIGHT
#
# 3-element orders (enables CENTERED layout):
#   "session,windows,plugins" - Session LEFT, windows CENTER, plugins RIGHT
#   "plugins,windows,session" - Plugins LEFT, windows CENTER, session RIGHT
#   "session,plugins,windows" - Session LEFT, plugins CENTER, windows RIGHT
#
# Any element in the middle position will be centered in the status bar
POWERKIT_DEFAULT_STATUS_ORDER="session,plugins"

# =============================================================================
# LAZY LOADING (Stale-While-Revalidate)
# =============================================================================
# PowerKit uses a stale-while-revalidate caching strategy for fast UI response.
# When data is "stale" (older than TTL but within the stale window), cached data
# is shown immediately with visual indication while fresh data is fetched.
#
# Cache State Flow:
#   FRESH (age <= TTL)           -> Return cache, stale=0 (normal colors)
#   STALE (TTL < age <= TTL*M)   -> Return cache + bg refresh, stale=1 (darker colors)
#   VERY OLD (age > TTL*M)       -> Synchronous refresh (blocking), stale=0
#   COLLECTION FAILED            -> Return previous cache, stale=1 (darker colors)
#
# Where M = stale_multiplier

# @powerkit_lazy_loading - Enable stale-while-revalidate pattern
# Values: "true", "false"
# When enabled, stale cache data is returned immediately while fresh data
# is fetched in background. This prevents UI blocking on slow operations.
POWERKIT_DEFAULT_LAZY_LOADING="true"

# @powerkit_stale_multiplier - Maximum staleness as multiple of TTL
# Values: any positive integer
# Example: TTL=300s, multiplier=3 -> data up to 900s old can be returned
# After TTL * multiplier, synchronous (blocking) refresh is forced
POWERKIT_DEFAULT_STALE_MULTIPLIER="3"

# @powerkit_stale_color_variant - Visual indicator for stale data
# Values: "-darker", "-darkest", "-lighter", "-lightest"
# Applied to plugin background colors when displaying cached/stale data
# This provides visual feedback that data shown may be outdated
POWERKIT_DEFAULT_STALE_COLOR_VARIANT="-darkest"

# =============================================================================
# SEPARATOR CONFIGURATION
# =============================================================================
# @powerkit_separator_style - Main separator style between segments
# Values:
#   "normal"    - Solid powerline arrows ()
#   "rounded"   - Rounded powerline ()
#   "slant"     - Slanted diagonal ()
#   "slantup"   - Upward slant ()
#   "trapezoid" - Trapezoid shape ()
#   "flame"     - Flame/fire style ()
#   "pixel"     - Pixelated blocks ()
#   "honeycomb" - Hexagonal pattern ()
#   "none"      - No separators
POWERKIT_DEFAULT_SEPARATOR_STYLE="normal"

# @powerkit_edge_separator_style - Style for external edge separators
# Values:
#   "same"         - Use main separator_style (no special treatment)
#   "rounded"      - Rounded at standard edge points only
#   "rounded:all"  - Rounded at ALL external edges (session start/end, first/last window)
#   "flame:all"    - Flame at ALL external edges
#   ...any style (normal, rounded, slant, flame, etc.) with optional :all suffix
# The :all suffix applies the edge style to ALL external boundaries.
POWERKIT_DEFAULT_EDGE_SEPARATOR_STYLE="rounded"

# Powerline glyphs (using \U format for codes > 0xFF)
POWERKIT_SEP_SOLID_RIGHT=$'\U0000e0b0'
POWERKIT_SEP_SOLID_LEFT=$'\U0000e0b2'
POWERKIT_SEP_ROUND_RIGHT=$'\U0000e0b4'
POWERKIT_SEP_ROUND_LEFT=$'\U0000e0b6'
POWERKIT_SEP_SLANT_RIGHT=$'\U0000e0b8'
POWERKIT_SEP_SLANT_LEFT=$'\U0000e0ba'
POWERKIT_SEP_SLANT_UP_RIGHT=$'\U0000e0bc'
POWERKIT_SEP_SLANT_UP_LEFT=$'\U0000e0be'
POWERKIT_SEP_TRAPEZOID_RIGHT=$'\U0000e0c8'
POWERKIT_SEP_TRAPEZOID_LEFT=$'\U0000e0ca'
POWERKIT_SEP_FLAME_RIGHT=$'\U0000e0c0'
POWERKIT_SEP_FLAME_LEFT=$'\U0000e0c2'
POWERKIT_SEP_PIXEL_RIGHT=$'\U0000e0c4'
POWERKIT_SEP_PIXEL_LEFT=$'\U0000e0c6'
POWERKIT_SEP_HONEYCOMB_RIGHT=$'\U0000e0cc'
POWERKIT_SEP_HONEYCOMB_LEFT=$'\U0000e0cd'

# List of available separator styles (for validation)
POWERKIT_SEPARATOR_STYLES="normal rounded slant slantup trapezoid flame pixel honeycomb none"

# @powerkit_elements_spacing - Add gaps between status bar elements
# Values:
#   "false"   - No spacing (connected segments) - default
#   "true"    - Spacing everywhere
#   "both"    - Same as true
#   "windows" - Spacing only between windows
#   "plugins" - Spacing only between plugins
POWERKIT_DEFAULT_ELEMENTS_SPACING="false"

# @powerkit_icon_padding - Padding around plugin icons
# Controls spacing on each side of the icon within its segment.
# Helps normalize visual spacing for icons with different widths.
# Values:
#   1 - Minimal padding (1 space each side) - compact look
#   2 - Standard padding (2 spaces each side) - default, reduces width variation
#   3 - Wide padding (3 spaces each side) - very generous spacing
# Tip: If icons look inconsistently spaced, try increasing this value.
POWERKIT_DEFAULT_ICON_PADDING="1"

# Figure space character (U+2007) - same width as digits in most fonts
# Used for more consistent icon padding when standard spaces vary
POWERKIT_FIGURE_SPACE=$'\U00002007'

# =============================================================================
# SESSION CONFIGURATION
# =============================================================================
# @powerkit_session_icon - Session segment icon
# Values:
#   "auto" - Auto-detect OS icon (Apple for macOS, Tux for Linux, etc.)
#   Any Nerd Font icon character
POWERKIT_DEFAULT_SESSION_ICON="auto"

# @powerkit_session_prefix_icon - Icon when prefix key is pressed
POWERKIT_DEFAULT_SESSION_PREFIX_ICON=$'\U0000f11c'    # nf-fa-keyboard

# @powerkit_session_copy_icon - Icon in copy mode
POWERKIT_DEFAULT_SESSION_COPY_ICON=$'\U0000f0c5'      # nf-fa-copy

# Session segment colors (semantic names from theme)
# @powerkit_session_prefix_color - Background when prefix is pressed
# @powerkit_session_copy_mode_color - Background in copy mode
# @powerkit_session_normal_color - Background in normal mode
# Values: theme color names like "session-bg", "session-prefix-bg", etc.
POWERKIT_DEFAULT_SESSION_PREFIX_COLOR="session-prefix-bg"
POWERKIT_DEFAULT_SESSION_COPY_MODE_COLOR="session-copy-bg"
POWERKIT_DEFAULT_SESSION_NORMAL_COLOR="session-bg"

# =============================================================================
# WINDOW CONFIGURATION
# =============================================================================
# @powerkit_active_window_icon - Icon for active window
POWERKIT_DEFAULT_ACTIVE_WINDOW_ICON=$'\U0000e795'     # nf-dev-terminal

# @powerkit_inactive_window_icon - Icon for inactive windows
POWERKIT_DEFAULT_INACTIVE_WINDOW_ICON=$'\U0000f489'   # nf-oct-terminal

# @powerkit_zoomed_window_icon - Icon indicator for zoomed pane
POWERKIT_DEFAULT_ZOOMED_WINDOW_ICON=$'\U0000f531'     # nf-mdi-fullscreen

# @powerkit_window_activity_icon - Icon for windows with activity
# Shown when monitor-activity is on and activity is detected
POWERKIT_DEFAULT_WINDOW_ACTIVITY_ICON=$'\U000f006e'   # nf-md-bell_ring

# @powerkit_window_bell_icon - Icon for windows with bell alert
POWERKIT_DEFAULT_WINDOW_BELL_ICON=$'\U000f009a'       # nf-md-bell_alert

# @powerkit_window_marked_icon - Icon for marked windows (M flag)
POWERKIT_DEFAULT_WINDOW_MARKED_ICON=$'\U000f0306'     # nf-md-bookmark

# @powerkit_pane_synchronized_icon - Icon for synchronized panes
POWERKIT_DEFAULT_PANE_SYNCHRONIZED_ICON=$'\U00002735'

# @powerkit_active_window_title - Title format for active window
# @powerkit_inactive_window_title - Title format for inactive windows
# Values: tmux format strings
#   #W - window name
#   #I - window index
#   #F - window flags
#   #{b:pane_current_path} - basename of current path
POWERKIT_DEFAULT_ACTIVE_WINDOW_TITLE="#W"
POWERKIT_DEFAULT_INACTIVE_WINDOW_TITLE="#W"

# @powerkit_window_index_style - Style for window index display
# Values: "text", "numeric", "box", "box_outline", "box_multiple", "box_multiple_outline", "circle", "circle_outline"
# Styles:
#   text                  - Plain numbers: 0, 1, 2, 3...
#   numeric               - Nerd Font numeric icons: 󰬹, 󰬺, 󰬻, 󰬼...
#   box                   - Numbers in filled boxes: 󰎡, 󰎤, 󰎧, 󰎪...
#   box_outline           - Numbers in outlined boxes: 󰎣, 󰎦, 󰎩, 󰎬...
#   box_multiple          - Multiple filled boxes: 󰼎, 󰼏, 󰼐, 󰼑...
#   box_multiple_outline  - Multiple outlined boxes: 󰎢, 󰎥, 󰎨, 󰎫...
#   circle                - Numbers in filled circles: 󰲞, 󰲠, 󰲢, 󰲤...
#   circle_outline        - Numbers in outlined circles: 󰲟, 󰲡, 󰲣, 󰲥...
# Note: Multi-digit indices (10+) are built by combining single digit icons
POWERKIT_DEFAULT_WINDOW_INDEX_STYLE="text"

# Note: Window colors are derived automatically from theme base colors:
# - window-active-base: content bg (index bg = -lighter, text = -darker)
# - window-inactive-base: content bg (index bg = -lighter, text = -darker)

# =============================================================================
# PANE CONFIGURATION
# =============================================================================
# @powerkit_pane_border_lines - Pane border line style
# Values: "single", "double", "heavy", "simple", "number"
POWERKIT_DEFAULT_PANE_BORDER_LINES="single"

# @powerkit_pane_border_unified - Use single color for all pane borders
# Values: "true", "false"
# When true, removes the two-color effect when panes meet
POWERKIT_DEFAULT_PANE_BORDER_UNIFIED="false"

# @powerkit_pane_border_color - Unified pane border color (when unified=true)
# Values: theme color name or hex color
# Examples: "pane-border-active", "statusbar-bg", "#3b4261"
POWERKIT_DEFAULT_PANE_BORDER_COLOR="pane-border-active"

# @powerkit_active_pane_border_color - Active pane border color (when unified=false)
# @powerkit_inactive_pane_border_color - Inactive pane border color (when unified=false)
POWERKIT_DEFAULT_ACTIVE_PANE_BORDER_COLOR="pane-border-active"
POWERKIT_DEFAULT_INACTIVE_PANE_BORDER_COLOR="pane-border-inactive"

# @powerkit_pane_border_status - Show pane status line
# Values: "off", "top", "bottom"
# When enabled, shows formatted text at pane borders with theme colors
POWERKIT_DEFAULT_PANE_BORDER_STATUS="off"

# @powerkit_pane_border_status_bg - Background color for the pane status line
# Values: theme color name, hex color, or "none" for transparent
# Examples: "accent", "statusbar-bg", "#3b4261", "none"
# Note: This only affects the status line itself, not the border lines
POWERKIT_DEFAULT_PANE_BORDER_STATUS_BG="none"

# @powerkit_pane_border_format - Pane status format string
# Available placeholders:
#   {index}      - Pane index number
#   {title}      - Pane title
#   {command}    - Current command running in pane
#   {path}       - Full current path
#   {basename}   - Basename of current path
#   {active}     - Shows "▶" only on active pane (useful with unified border)
#
# Examples:
#   "{index}: {title}"           - Default: "0: zsh"
#   "{active} {basename}"        - "▶ tmux-powerkit" (active) or "tmux-powerkit" (inactive)
#   "{active} {command}"         - "▶ nvim" (active) or "zsh" (inactive)
#
# Note: Active pane text is displayed in bold, inactive uses normal weight
POWERKIT_DEFAULT_PANE_BORDER_FORMAT="{active} {command}"

# =============================================================================
# PANE SCROLLBARS
# =============================================================================
# Scrollbars appear on the side of panes when scrolling (tmux 3.4+)

# @powerkit_pane_scrollbars - Enable pane scrollbars
# Values: "off", "modal", "on"
# - off: No scrollbars
# - modal: Scrollbars only visible in copy/view mode
# - on: Scrollbars always visible
POWERKIT_DEFAULT_PANE_SCROLLBARS="off"

# @powerkit_pane_scrollbars_position - Scrollbar position
# Values: "left", "right"
POWERKIT_DEFAULT_PANE_SCROLLBARS_POSITION="right"

# @powerkit_pane_scrollbars_style_fg - Scrollbar slider (foreground) color
# Values: theme color name or hex color
# The slider represents the visible portion of the pane
POWERKIT_DEFAULT_PANE_SCROLLBARS_STYLE_FG="pane-border-active"

# @powerkit_pane_scrollbars_style_bg - Scrollbar track (background) color
# Values: theme color name or hex color
# The track represents the total scrollable area
POWERKIT_DEFAULT_PANE_SCROLLBARS_STYLE_BG="pane-border-inactive"

# @powerkit_pane_scrollbars_width - Scrollbar width in characters
# Values: integer (1-5 recommended)
POWERKIT_DEFAULT_PANE_SCROLLBARS_WIDTH="1"

# @powerkit_pane_scrollbars_pad - Padding between scrollbar and pane content
# Values: integer (0-2 recommended)
POWERKIT_DEFAULT_PANE_SCROLLBARS_PAD="0"

# =============================================================================
# PANE FLASH EFFECT
# =============================================================================
# Visual feedback when selecting/clicking on a pane.
# The pane background briefly flashes a color to indicate selection.

# @powerkit_pane_flash_enabled - Enable pane flash on selection
# Values: "true", "false"
# When enabled, the pane background flashes briefly when selected/clicked
POWERKIT_DEFAULT_PANE_FLASH_ENABLED="false"

# @powerkit_pane_flash_color - Flash background color
# Values: theme color name (e.g., "statusbar-bg", "info-base") or hex color (#RRGGBB)
# The color used for the flash effect background
# Default: "statusbar-bg" (uses status bar background color from theme)
POWERKIT_DEFAULT_PANE_FLASH_COLOR="statusbar-bg"

# @powerkit_pane_flash_duration - Flash duration in milliseconds
# Values: any positive integer (recommended: 50-200)
# How long the flash effect lasts before resetting
# Lower values = subtle flash, higher values = more visible
POWERKIT_DEFAULT_PANE_FLASH_DURATION="100"

# =============================================================================
# POPUP & MENU CONFIGURATION
# =============================================================================
# @powerkit_popup_border_lines - Popup border line style
# Values: "single", "rounded", "double", "heavy", "simple", "padded", "none"
POWERKIT_DEFAULT_POPUP_BORDER_LINES="rounded"

# @powerkit_menu_border_lines - Menu border line style
# Values: "single", "rounded", "double", "heavy", "simple", "padded", "none"
POWERKIT_DEFAULT_MENU_BORDER_LINES="rounded"

# =============================================================================
# CLOCK CONFIGURATION
# =============================================================================
# @powerkit_clock_style - tmux clock mode format
# Values: "12", "24"
POWERKIT_DEFAULT_CLOCK_STYLE="24"

# =============================================================================
# KEYBINDINGS CONFIGURATION
# =============================================================================
# All keybindings use prefix + key format
# Key notation:
#   C-x  = Ctrl + x
#   M-x  = Alt/Meta + x
#   S-x  = Shift + x
#   ""   = Disabled (empty string)

# @powerkit_show_options_key - Options viewer popup
# @powerkit_show_options_width - Popup width (percentage or columns)
# @powerkit_show_options_height - Popup height (percentage or rows)
POWERKIT_DEFAULT_SHOW_OPTIONS_KEY="C-e"
POWERKIT_DEFAULT_SHOW_OPTIONS_WIDTH="80%"
POWERKIT_DEFAULT_SHOW_OPTIONS_HEIGHT="80%"

# @powerkit_show_keybindings_key - Keybindings viewer popup
# @powerkit_show_keybindings_width - Popup width
# @powerkit_show_keybindings_height - Popup height
POWERKIT_DEFAULT_SHOW_KEYBINDINGS_KEY="C-y"
POWERKIT_DEFAULT_SHOW_KEYBINDINGS_WIDTH="80%"
POWERKIT_DEFAULT_SHOW_KEYBINDINGS_HEIGHT="80%"

# @powerkit_theme_selector_key - Theme selector popup
POWERKIT_DEFAULT_THEME_SELECTOR_KEY="C-r"

# @powerkit_cache_clear_key - Clear all cached data
POWERKIT_DEFAULT_CACHE_CLEAR_KEY="M-x"

# @powerkit_log_viewer_key - Log viewer popup
# @powerkit_log_viewer_width - Popup width
# @powerkit_log_viewer_height - Popup height
POWERKIT_DEFAULT_LOG_VIEWER_KEY="M-l"
POWERKIT_DEFAULT_LOG_VIEWER_WIDTH="90%"
POWERKIT_DEFAULT_LOG_VIEWER_HEIGHT="80%"

# @powerkit_reload_config_key - Reload tmux configuration
# Note: Using "R" (Shift+r) to avoid conflict with choose-buffer default
POWERKIT_DEFAULT_RELOAD_CONFIG_KEY="R"

# @powerkit_keybinding_conflict_action - Action when keybinding conflicts
# Values:
#   "warn"   - Detect and log conflicts, but still register (default)
#   "skip"   - Don't register PowerKit keybinding if conflict exists
#   "ignore" - Don't check for conflicts at all
POWERKIT_DEFAULT_KEYBINDING_CONFLICT_ACTION="warn"

# =============================================================================
# COLOR GENERATOR CONSTANTS
# =============================================================================
# These values control automatic color variant generation from base colors.
# The system generates 6 variants per base color:
#   -light, -lighter, -lightest (toward white)
#   -dark, -darker, -darkest (toward black)

# Light variants (percentage toward white)
POWERKIT_COLOR_LIGHT_PERCENT=10       # -light: subtle lightening
POWERKIT_COLOR_LIGHTER_PERCENT=20     # -lighter: medium lightening
POWERKIT_COLOR_LIGHTEST_PERCENT=80    # -lightest: strong lightening

# Dark variants (percentage toward black)
POWERKIT_COLOR_DARK_PERCENT=10        # -dark: subtle darkening
POWERKIT_COLOR_DARKER_PERCENT=20      # -darker: medium darkening
POWERKIT_COLOR_DARKEST_PERCENT=55     # -darkest: strong darkening

# Theme colors that should have variants generated
# Pattern: base-color -> base-color-{light,lighter,lightest,dark,darker,darkest}
POWERKIT_COLORS_WITH_VARIANTS="window-active-base window-inactive-base ok-base good-base info-base warning-base error-base disabled-base"

# =============================================================================
# SYSTEM CONSTANTS (Internal)
# =============================================================================
# These are internal constants used by the system. Not user-configurable.

# Byte size constants
POWERKIT_BYTE_KB=1024
POWERKIT_BYTE_MB=1048576
POWERKIT_BYTE_GB=1073741824
POWERKIT_BYTE_TB=1099511627776

# Timing constants for system operations
POWERKIT_TIMING_CPU_SAMPLE="0.1"
POWERKIT_TIMING_CACHE_INTERFACE="300"
POWERKIT_TIMING_MIN_DELTA="0.1"
POWERKIT_TIMING_FALLBACK="1"

# iostat configuration (used by cpu plugin)
POWERKIT_IOSTAT_COUNT="2"
POWERKIT_IOSTAT_CPU_FIELD="6"
POWERKIT_IOSTAT_BASELINE="100"

# Performance limits
POWERKIT_PERF_CPU_PROCESS_LIMIT="50"

# Fallback colors when theme fails to load
POWERKIT_FALLBACK_STATUS_BG="#292e42"

# =============================================================================
# ANSI COLORS (for helpers/scripts)
# =============================================================================
# Standard ANSI escape codes for terminal output in helpers

POWERKIT_ANSI_BOLD=$'\033[1m'
POWERKIT_ANSI_DIM=$'\033[2m'
POWERKIT_ANSI_RESET=$'\033[0m'
POWERKIT_ANSI_RED=$'\033[31m'
POWERKIT_ANSI_GREEN=$'\033[32m'
POWERKIT_ANSI_YELLOW=$'\033[33m'
POWERKIT_ANSI_BLUE=$'\033[34m'
POWERKIT_ANSI_MAGENTA=$'\033[35m'
POWERKIT_ANSI_CYAN=$'\033[36m'

# =============================================================================
# PLUGIN DEFAULTS HELPER
# =============================================================================

# Get plugin default value by name
# Usage: get_plugin_default "battery" "icon"
get_plugin_default() {
    local var_name="POWERKIT_PLUGIN_${1^^}_${2^^}"
    var_name="${var_name//-/_}"
    printf '%s' "${!var_name:-}"
}
