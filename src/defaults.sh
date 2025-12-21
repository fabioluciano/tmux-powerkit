#!/usr/bin/env bash
# =============================================================================
# PowerKit Defaults Configuration - KISS/DRY Version
# =============================================================================
# All default values for PowerKit. Users override via tmux.conf options.
# shellcheck disable=SC2034
#
# GLOBAL VARIABLES EXPORTED:
#   - All POWERKIT_* variables (configuration defaults)
#   - _DEFAULT_* variables (base defaults for DRY)
#
# DEPENDENCIES: source_guard.sh
# =============================================================================

# Source guard
_DEFAULTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=src/source_guard.sh
. "$_DEFAULTS_DIR/source_guard.sh"
source_guard "defaults" && return 0

# =============================================================================
# BASE DEFAULTS (DRY - reused across plugins)
# =============================================================================

_DEFAULT_CACHE_DIRECTORY=tmux-powerkit

# Default colors (semantic names)
_DEFAULT_ACCENT="active"
_DEFAULT_ACCENT_ICON="secondary"
_DEFAULT_SUCCESS="success"
_DEFAULT_SUCCESS_ICON="success-subtle"
_DEFAULT_INFO="info"
_DEFAULT_INFO_ICON="info-subtle"
_DEFAULT_WARNING="warning"
_DEFAULT_WARNING_ICON="warning-subtle"
_DEFAULT_ERROR="error"
_DEFAULT_ERROR_ICON="error-subtle"

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
# PLUGIN DEFAULTS HELPER (DRY)
# =============================================================================
# Automatically sets standard plugin variables if not already defined.
# Call after defining plugin-specific overrides.
#
# Usage: _plugin_defaults "pluginname" [has_thresholds]
# =============================================================================

_plugin_defaults() {
    local name="${1^^}"  # uppercase
    name="${name//-/_}"  # replace - with _
    local has_thresholds="${2:-}"

    local prefix="POWERKIT_PLUGIN_${name}"

    # Standard colors (set if not defined)
    local accent_var="${prefix}_ACCENT_COLOR"
    local accent_icon_var="${prefix}_ACCENT_COLOR_ICON"
    [[ -z "${!accent_var:-}" ]] && eval "${accent_var}=\"\$_DEFAULT_ACCENT\""
    [[ -z "${!accent_icon_var:-}" ]] && eval "${accent_icon_var}=\"\$_DEFAULT_ACCENT_ICON\""

    # Threshold colors (only if plugin uses thresholds)
    if [[ -n "$has_thresholds" ]]; then
        local warn_var="${prefix}_WARNING_ACCENT_COLOR"
        local warn_icon_var="${prefix}_WARNING_ACCENT_COLOR_ICON"
        local crit_var="${prefix}_CRITICAL_ACCENT_COLOR"
        local crit_icon_var="${prefix}_CRITICAL_ACCENT_COLOR_ICON"

        [[ -z "${!warn_var:-}" ]] && eval "${warn_var}=\"\$_DEFAULT_WARNING\""
        [[ -z "${!warn_icon_var:-}" ]] && eval "${warn_icon_var}=\"\$_DEFAULT_WARNING_ICON\""
        [[ -z "${!crit_var:-}" ]] && eval "${crit_var}=\"\$_DEFAULT_ERROR\""
        [[ -z "${!crit_icon_var:-}" ]] && eval "${crit_icon_var}=\"\$_DEFAULT_ERROR_ICON\""
    fi
}

# Get plugin default value by name
# Usage: get_powerkit_plugin_default "battery" "icon"
get_powerkit_plugin_default() {
    local var_name="POWERKIT_PLUGIN_${1^^}_${2^^}"
    var_name="${var_name//-/_}"
    printf '%s' "${!var_name:-}"
}
get_plugin_default() { get_powerkit_plugin_default "$@"; }

# =============================================================================
# CORE OPTIONS
# =============================================================================

POWERKIT_DEFAULT_THEME="tokyo-night"
POWERKIT_DEFAULT_THEME_VARIANT="night"
POWERKIT_CUSTOM_THEME_PATH=""
POWERKIT_DEFAULT_DISABLE_PLUGINS=0
POWERKIT_DEFAULT_BAR_LAYOUT="single"
POWERKIT_DEFAULT_TRANSPARENT="false"
POWERKIT_DEFAULT_PLUGINS="datetime,hostname,git,battery,cpu,memory"
POWERKIT_DEFAULT_STATUS_LEFT_LENGTH="100"
POWERKIT_DEFAULT_STATUS_RIGHT_LENGTH="1000"

# =============================================================================
# SEPARATORS
# =============================================================================

POWERKIT_DEFAULT_SEPARATOR_STYLE="rounded"
POWERKIT_DEFAULT_LEFT_SEPARATOR=$'\ue0b0'
POWERKIT_DEFAULT_RIGHT_SEPARATOR=$'\ue0b2'
POWERKIT_DEFAULT_RIGHT_SEPARATOR_INVERSE=$'\ue0b3'
POWERKIT_DEFAULT_LEFT_SEPARATOR_ROUNDED=$'\ue0b6'
POWERKIT_DEFAULT_RIGHT_SEPARATOR_ROUNDED=$'\ue0b4'
# Options: false, both, plugins, windows
POWERKIT_DEFAULT_ELEMENTS_SPACING="false"

# =============================================================================
# SESSION & WINDOW
# =============================================================================

POWERKIT_DEFAULT_SESSION_ICON="auto"
POWERKIT_DEFAULT_SESSION_PREFIX_COLOR="warning"
POWERKIT_DEFAULT_SESSION_COPY_MODE_COLOR="info"
POWERKIT_DEFAULT_SESSION_NORMAL_COLOR="success"
POWERKIT_DEFAULT_ACTIVE_WINDOW_ICON=$'\ue795'
POWERKIT_DEFAULT_INACTIVE_WINDOW_ICON=$'\uf489'
POWERKIT_DEFAULT_ZOOMED_WINDOW_ICON=$'\uf531'
POWERKIT_DEFAULT_PANE_SYNCHRONIZED_ICON="✵"
POWERKIT_DEFAULT_ACTIVE_WINDOW_TITLE="#W "
POWERKIT_DEFAULT_INACTIVE_WINDOW_TITLE="#W "
POWERKIT_DEFAULT_WINDOW_WITH_ACTIVITY_STYLE="italics"
POWERKIT_DEFAULT_ACTIVE_WINDOW_NUMBER_BG="accent"
POWERKIT_DEFAULT_INACTIVE_WINDOW_NUMBER_BG="border-subtle"
POWERKIT_DEFAULT_ACTIVE_PANE_BORDER_STYLE="border-strong"
POWERKIT_DEFAULT_INACTIVE_PANE_BORDER_STYLE="surface"
POWERKIT_DEFAULT_ACTIVE_WINDOW_CONTENT_BG="primary"
POWERKIT_DEFAULT_STATUS_BELL_STYLE="bold"

# =============================================================================
# HELPER KEYBINDINGS
# =============================================================================
# Mnemonic Ctrl keybindings (prefix + Ctrl+KEY)
# Reserved: C-a(prefix), C-b(prefix), C-h/j/k/l(vim), C-n/p(windows), C-o(rotate), C-z(suspend)
# Free keys: C-d, C-e, C-f, C-g, C-q, C-r, C-s, C-u, C-v, C-y
# =============================================================================

# Options viewer (prefix + Ctrl+e for sEttings/options) - free key
POWERKIT_DEFAULT_OPTIONS_KEY="C-e"
POWERKIT_DEFAULT_OPTIONS_WIDTH="80%"
POWERKIT_DEFAULT_OPTIONS_HEIGHT="80%"

# Keybindings viewer (prefix + Ctrl+y for keYs) - free key
POWERKIT_DEFAULT_KEYBINDINGS_KEY="C-y"
POWERKIT_DEFAULT_KEYBINDINGS_WIDTH="80%"
POWERKIT_DEFAULT_KEYBINDINGS_HEIGHT="80%"

# Theme selector (prefix + Ctrl+r for Retheme/change theme) - free key
POWERKIT_DEFAULT_THEME_SELECTOR_KEY="C-r"

# =============================================================================
# PLUGIN DEFAULTS INITIALIZATION
# =============================================================================
# Plugin-specific defaults are now defined in each plugin's plugin_declare_options()
# function. This section only applies base colors via _plugin_defaults() for
# backward compatibility with any code that still references POWERKIT_PLUGIN_*
# variables directly.
#
# All 42 plugins now use the Plugin Contract pattern:
# - plugin_declare_options() defines all configurable options
# - get_option("name") retrieves values from declared options
# - Falls back to POWERKIT_PLUGIN_* variables if needed
# =============================================================================

# All plugins list (for applying base accent colors)
_ALL_PLUGINS="audiodevices battery bitwarden bitbucket bluetooth brightness
              camera cloud cloudstatus cpu crypto datetime disk external_ip
              fan git github gitlab gpu hostname iops jira kubernetes
              loadavg memory microphone network nowplaying packages ping
              pomodoro smartkey ssh stocks temperature terraform timezones
              uptime volume vpn weather wifi"

# Apply base accent colors to all plugins
for _p in $_ALL_PLUGINS; do
    _plugin_defaults "$_p"
done

unset _p _ALL_PLUGINS

# =============================================================================
# SYSTEM CONSTANTS (used by plugins)
# =============================================================================

# Byte sizes (used by disk, memory, network, gpu)
POWERKIT_BYTE_KB=1024
POWERKIT_BYTE_MB=1048576
POWERKIT_BYTE_GB=1073741824
POWERKIT_BYTE_TB=1099511627776

# Cache keybinding (prefix + Ctrl+d for Delete cache) - free key
POWERKIT_PLUGIN_CACHE_CLEAR_KEY="C-d"

# Timing constants (used by cpu, network)
POWERKIT_TIMING_CPU_SAMPLE="0.1"
POWERKIT_TIMING_CACHE_INTERFACE="300"
POWERKIT_TIMING_CACHE_LONG="60"          # Long-lived cache for delta calculations (network prev data)
POWERKIT_TIMING_MIN_DELTA="0.1"
POWERKIT_TIMING_FALLBACK="1"

# iostat (used by cpu)
POWERKIT_IOSTAT_COUNT="2"
POWERKIT_IOSTAT_CPU_FIELD="6"
POWERKIT_IOSTAT_BASELINE="100"

# Performance limits (used by cpu)
POWERKIT_PERF_CPU_PROCESS_LIMIT="50"

# Fallback colors
POWERKIT_FALLBACK_STATUS_BG="#292e42"

# ANSI colors (used by helpers)
POWERKIT_ANSI_BOLD='\033[1m'
POWERKIT_ANSI_DIM='\033[2m'
POWERKIT_ANSI_RESET='\033[0m'
POWERKIT_ANSI_RED='\033[31m'
POWERKIT_ANSI_GREEN='\033[32m'
POWERKIT_ANSI_YELLOW='\033[33m'
POWERKIT_ANSI_BLUE='\033[34m'
POWERKIT_ANSI_MAGENTA='\033[35m'
POWERKIT_ANSI_CYAN='\033[36m'
