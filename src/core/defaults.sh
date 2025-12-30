#!/usr/bin/env bash
# =============================================================================
# PowerKit Core: Defaults Configuration
# Description: All default values for PowerKit
# =============================================================================
# Users override via tmux.conf options.
# shellcheck disable=SC2034
#
# GLOBAL VARIABLES EXPORTED:
#   - All POWERKIT_* variables (configuration defaults)
#   - _DEFAULT_* variables (base defaults for DRY)
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "defaults" && return 0

# =============================================================================
# BASE DEFAULTS (DRY - reused across plugins)
# =============================================================================

_DEFAULT_CACHE_DIRECTORY="tmux-powerkit"

# Default plugin colors (semantic names from theme)
_DEFAULT_ACCENT="ok-bg"
_DEFAULT_ACCENT_ICON="ok-icon-bg"
_DEFAULT_INFO="info-bg"
_DEFAULT_INFO_ICON="info-icon-bg"
_DEFAULT_WARNING="warning-bg"
_DEFAULT_WARNING_ICON="warning-icon-bg"
_DEFAULT_ERROR="error-bg"
_DEFAULT_ERROR_ICON="error-icon-bg"

# Default thresholds
_DEFAULT_WARNING_THRESHOLD="70"
_DEFAULT_CRITICAL_THRESHOLD="90"

# Common values
_DEFAULT_SEPARATOR=" | "
_DEFAULT_MAX_LENGTH="40"
_DEFAULT_POPUP_SIZE="50%"

# Common timeouts and TTLs (in seconds)
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
# CORE OPTIONS
# =============================================================================

POWERKIT_DEFAULT_THEME="tokyo-night"
POWERKIT_DEFAULT_THEME_VARIANT="night"
POWERKIT_DEFAULT_CUSTOM_THEME_PATH=""
POWERKIT_DEFAULT_TRANSPARENT="false"
POWERKIT_DEFAULT_PLUGINS="datetime,battery,cpu,memory,hostname,git"
POWERKIT_DEFAULT_STATUS_INTERVAL="5"
POWERKIT_DEFAULT_STATUS_POSITION="top"
POWERKIT_DEFAULT_STATUS_JUSTIFY="left"
POWERKIT_DEFAULT_STATUS_LEFT_LENGTH="100"
POWERKIT_DEFAULT_STATUS_RIGHT_LENGTH="500"
POWERKIT_DEFAULT_BAR_LAYOUT="single"       # single or double (2 status lines)

# Status bar element order - comma-separated list of: session, windows, plugins
#
# 2-element orders are auto-expanded (windows inserted before last element):
#   "session,plugins" → "session,windows,plugins" (standard layout)
#   "plugins,session" → "plugins,windows,session" (inverted layout)
#
# 3-element orders with explicit "windows" enable CENTERED layout:
#   "session,windows,plugins" → session LEFT, windows CENTER, plugins RIGHT
#   "plugins,windows,session" → plugins LEFT, windows CENTER, session RIGHT
#   "session,plugins,windows" → session LEFT, plugins CENTER, windows RIGHT
#
# Any element can be in the center position - it will be centered in the status bar.

# POWERKIT_DEFAULT_STATUS_ORDER="session,plugins"
POWERKIT_DEFAULT_STATUS_ORDER="session,plugins"

# =============================================================================
# LAZY LOADING (Stale-While-Revalidate)
# =============================================================================
#
# The stale-while-revalidate pattern provides fast UI response while keeping
# data fresh in the background. When plugin data is "stale" (older than TTL
# but within the stale window), the cached data is shown immediately with
# visual indication while fresh data is fetched in background.
#
# Cache State Flow:
#   FRESH (age ≤ TTL)           → Return cache, stale=0 (normal colors)
#   STALE (TTL < age ≤ TTL×M)   → Return cache + bg refresh, stale=1 (darker colors)
#   VERY OLD (age > TTL×M)      → Synchronous refresh (blocking), stale=0
#   COLLECTION FAILED           → Return previous cache, stale=1 (darker colors)
#
# Where M = POWERKIT_DEFAULT_STALE_MULTIPLIER

# Enable lazy loading for plugin data collection
# When enabled, stale cache data is returned immediately while fresh data is fetched in background
POWERKIT_DEFAULT_LAZY_LOADING="true"

# Stale multiplier: how many times the TTL before data is considered "too old"
# Example: TTL=300s, multiplier=3 → data up to 900s old can be returned while refreshing
# After TTL×multiplier, synchronous (blocking) refresh is forced
POWERKIT_DEFAULT_STALE_MULTIPLIER="3"

# Stale indicator: color variant suffix applied when displaying stale (cached) data
# Applied to background colors (content_bg and icon_bg) via resolve_plugin_colors_full()
# Options: -darker, -darkest, -lighter, -lightest (must match theme color variants)
POWERKIT_DEFAULT_STALE_COLOR_VARIANT="-darkest"

# =============================================================================
# SEPARATORS
# =============================================================================

POWERKIT_DEFAULT_SEPARATOR_STYLE="normal"
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

# Available separator styles
POWERKIT_SEPARATOR_STYLES="normal rounded slant slantup trapezoid flame pixel honeycomb none"


# Elements spacing: false, true, both, plugins, windows
POWERKIT_DEFAULT_ELEMENTS_SPACING="false"

# =============================================================================
# SESSION
# =============================================================================

POWERKIT_DEFAULT_SESSION_ICON="auto"              # auto-detect OS icon
POWERKIT_DEFAULT_SESSION_PREFIX_ICON=$'\U0000f11c'    # nf-fa-keyboard
POWERKIT_DEFAULT_SESSION_COPY_ICON=$'\U0000f0c5'      # nf-fa-copy

# Session colors for different modes (semantic names from theme)
POWERKIT_DEFAULT_SESSION_PREFIX_COLOR="session-prefix-bg"
POWERKIT_DEFAULT_SESSION_COPY_MODE_COLOR="session-copy-bg"
POWERKIT_DEFAULT_SESSION_NORMAL_COLOR="session-bg"

# =============================================================================
# WINDOW
# =============================================================================

POWERKIT_DEFAULT_ACTIVE_WINDOW_ICON=$'\U0000e795'     # nf-dev-terminal
POWERKIT_DEFAULT_INACTIVE_WINDOW_ICON=$'\U0000f489'   # nf-oct-terminal
POWERKIT_DEFAULT_ZOOMED_WINDOW_ICON=$'\U0000f531'     # nf-mdi-fullscreen
POWERKIT_DEFAULT_PANE_SYNCHRONIZED_ICON=$'\U00002735'

POWERKIT_DEFAULT_ACTIVE_WINDOW_TITLE="#W"
POWERKIT_DEFAULT_INACTIVE_WINDOW_TITLE="#W"

# Window index icons (show icons instead of numbers for indices 1-10)
POWERKIT_DEFAULT_WINDOW_INDEX_ICONS="false"

# Window colors are derived automatically from base colors:
# - window-active-base: content bg (index bg = -lighter, text = -darker)
# - window-inactive-base: content bg (index bg = -lighter, text = -darker)
# No explicit color variables needed - system uses color_generator.sh

# =============================================================================
# PANE
# =============================================================================

POWERKIT_DEFAULT_PANE_BORDER_LINES="single"
POWERKIT_DEFAULT_ACTIVE_PANE_BORDER_COLOR="pane-border-active"
POWERKIT_DEFAULT_INACTIVE_PANE_BORDER_COLOR="pane-border-inactive"

# =============================================================================
# CLOCK
# =============================================================================

POWERKIT_DEFAULT_CLOCK_STYLE="24"

# =============================================================================
# HELPER KEYBINDINGS
# =============================================================================

# Options viewer (prefix + Ctrl+e)
POWERKIT_DEFAULT_SHOW_OPTIONS_KEY="C-e"
POWERKIT_DEFAULT_SHOW_OPTIONS_WIDTH="80%"
POWERKIT_DEFAULT_SHOW_OPTIONS_HEIGHT="80%"

# Keybindings viewer (prefix + Ctrl+y)
POWERKIT_DEFAULT_SHOW_KEYBINDINGS_KEY="C-y"
POWERKIT_DEFAULT_SHOW_KEYBINDINGS_WIDTH="80%"
POWERKIT_DEFAULT_SHOW_KEYBINDINGS_HEIGHT="80%"

# Theme selector (prefix + Ctrl+r)
POWERKIT_DEFAULT_THEME_SELECTOR_KEY="C-r"

# Cache clear (prefix + Alt+x)
POWERKIT_DEFAULT_CACHE_CLEAR_KEY="M-x"

# Log viewer (prefix + Alt+l)
POWERKIT_DEFAULT_LOG_VIEWER_KEY="M-l"
POWERKIT_DEFAULT_LOG_VIEWER_WIDTH="90%"
POWERKIT_DEFAULT_LOG_VIEWER_HEIGHT="80%"

# Reload tmux config (prefix + r)
POWERKIT_DEFAULT_RELOAD_CONFIG_KEY="r"

# Keybinding conflict handling: warn, skip, ignore
# - warn: detect and log conflicts, but still register (default)
# - skip: don't register PowerKit keybinding if conflict exists
# - ignore: don't check for conflicts at all
POWERKIT_DEFAULT_KEYBINDING_CONFLICT_ACTION="warn"

# =============================================================================
# COLOR GENERATOR CONSTANTS
# =============================================================================

# Color variant percentages (6 levels: 3 lighter + 3 darker)
# Light variants (toward white)
POWERKIT_COLOR_LIGHT_PERCENT=10       # -light: subtle lightening
POWERKIT_COLOR_LIGHTER_PERCENT=20      # -lighter: medium lightening
POWERKIT_COLOR_LIGHTEST_PERCENT=80     # -lightest: strong lightening

# Dark variants (toward black)
POWERKIT_COLOR_DARK_PERCENT=10         # -dark: subtle darkening
POWERKIT_COLOR_DARKER_PERCENT=20       # -darker: medium darkening
POWERKIT_COLOR_DARKEST_PERCENT=55      # -darkest: strong darkening

# Colors that should have variants generated
# System generates: -light, -lighter, -lightest, -dark, -darker, -darkest
# Pattern: base-color → base-color-{variant}
POWERKIT_COLORS_WITH_VARIANTS="window-active-base window-inactive-base ok-base good-base info-base warning-base error-base disabled-base"

# =============================================================================
# SYSTEM CONSTANTS
# =============================================================================

# Byte sizes
POWERKIT_BYTE_KB=1024
POWERKIT_BYTE_MB=1048576
POWERKIT_BYTE_GB=1073741824
POWERKIT_BYTE_TB=1099511627776

# Timing constants
POWERKIT_TIMING_CPU_SAMPLE="0.1"
POWERKIT_TIMING_CACHE_INTERFACE="300"
POWERKIT_TIMING_MIN_DELTA="0.1"
POWERKIT_TIMING_FALLBACK="1"

# iostat (used by cpu)
POWERKIT_IOSTAT_COUNT="2"
POWERKIT_IOSTAT_CPU_FIELD="6"
POWERKIT_IOSTAT_BASELINE="100"

# Performance limits
POWERKIT_PERF_CPU_PROCESS_LIMIT="50"

# Fallback colors
POWERKIT_FALLBACK_STATUS_BG="#292e42"

# =============================================================================
# ANSI COLORS (for helpers/scripts)
# =============================================================================

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
