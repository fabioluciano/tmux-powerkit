#!/usr/bin/env bash
# =============================================================================
#
#  ██████╗  ██████╗ ██╗    ██╗███████╗██████╗ ██╗  ██╗██╗████████╗
#  ██╔══██╗██╔═══██╗██║    ██║██╔════╝██╔══██╗██║ ██╔╝██║╚══██╔══╝
#  ██████╔╝██║   ██║██║ █╗ ██║█████╗  ██████╔╝█████╔╝ ██║   ██║
#  ██╔═══╝ ██║   ██║██║███╗██║██╔══╝  ██╔══██╗██╔═██╗ ██║   ██║
#  ██║     ╚██████╔╝╚███╔███╔╝███████╗██║  ██║██║  ██╗██║   ██║
#  ╚═╝      ╚═════╝  ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝   ╚═╝
#
#  REGISTRY - Version 1.0.0
#  Centralized constants and enums for PowerKit
#
# =============================================================================
#
# TABLE OF CONTENTS
# =================
#   1. Overview
#   2. Plugin Constants
#   3. Session Constants
#   4. Window Constants
#   5. Helper Constants
#   6. Health System
#   7. Lookup Functions
#
# =============================================================================
#
# 1. OVERVIEW
# ===========
#
# The Registry provides a single source of truth for all constants, enums,
# and static mappings used across PowerKit contracts. This eliminates
# duplication and ensures consistency.
#
# Benefits:
#   - Single source of truth for states, health levels, types
#   - Efficient lookups via associative arrays
#   - Descriptive metadata for each value
#   - Easy to extend with new values
#
# =============================================================================
# END OF DOCUMENTATION
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "registry" && return 0

# =============================================================================
# 2. PLUGIN CONSTANTS
# =============================================================================

# Valid plugin states
# Usage: for state in "${PLUGIN_STATES[@]}"; do ...
declare -gra PLUGIN_STATES=(
    "inactive" # Plugin is not active (e.g., no battery on desktop)
    "active"   # Plugin is active and working
    "degraded" # Plugin is working but with reduced functionality
    "failed"   # Plugin failed to collect data
)

# Plugin state descriptions
# shellcheck disable=SC2034 # Used for validation and documentation
declare -grA PLUGIN_STATE_DESCRIPTIONS=(
    [inactive]="Plugin is not active (resource doesn't exist or is disabled)"
    [active]="Plugin is active and working normally"
    [degraded]="Plugin working with reduced functionality"
    [failed]="Plugin failed completely (auth failed, dependency missing)"
)

# Valid plugin content types
# shellcheck disable=SC2034 # Used for validation
declare -gra PLUGIN_CONTENT_TYPES=(
    "static"  # Content doesn't change frequently
    "dynamic" # Content changes frequently
)

# Valid plugin presence modes
# shellcheck disable=SC2034 # Used for validation
declare -gra PLUGIN_PRESENCE_MODES=(
    "always"      # Always show plugin
    "conditional" # Show based on state
)

# =============================================================================
# 3. SESSION CONSTANTS
# =============================================================================

# Valid session states
# shellcheck disable=SC2034 # Used for validation
declare -gra SESSION_STATES=(
    "attached" # Session is attached to a client
    "detached" # Session has no attached clients
)

# Valid session modes
# shellcheck disable=SC2034 # Used for validation
declare -gra SESSION_MODES=(
    "normal"  # Default state
    "prefix"  # After pressing prefix key (client_prefix=1)
    "copy"    # Copy mode active (pane_in_mode=1)
    "command" # Command prompt (:)
    "search"  # Search mode (/ or ? in copy-mode)
)

# Session mode descriptions
# shellcheck disable=SC2034 # Used for validation and documentation
declare -grA SESSION_MODE_DESCRIPTIONS=(
    [normal]="Default tmux state"
    [prefix]="Prefix key pressed, awaiting command"
    [copy]="Copy mode active for text selection"
    [command]="Command prompt active"
    [search]="Search mode within copy mode"
)

# =============================================================================
# 4. WINDOW CONSTANTS
# =============================================================================

# Valid window states (derived from tmux variables)
# shellcheck disable=SC2034 # Used for validation
declare -gra WINDOW_STATES=(
    "active"   # Current window (window_active=1)
    "inactive" # Other windows
    "activity" # Has activity (window_activity_flag=1)
    "bell"     # Has bell (window_bell_flag=1)
    "zoomed"   # Is zoomed (window_zoomed_flag=1)
    "last"     # Was last active (window_last_flag=1)
    "marked"   # Is marked (window_marked_flag=1)
)

# Window icon map (command -> icon)
# Used for automatic icon resolution based on pane command
declare -grA WINDOW_ICON_MAP=(
    # Editors
    [vim]=$'\ue7c5'
    [nvim]=$'\ue7c5'
    [vi]=$'\ue7c5'
    [nano]=$'\uf0f6'
    [emacs]=$'\ue7c2'
    [code]=$'\ue70c'

    # Shells
    [bash]=$'\uf120'
    [zsh]=$'\uf120'
    [fish]=$'\uf120'
    [sh]=$'\uf120'
    [dash]=$'\uf120'

    # Version control
    [git]=$'\uf1d3'
    [lazygit]=$'\uf1d3'
    [tig]=$'\uf1d3'

    # Node/JavaScript
    [node]=$'\ue718'
    [npm]=$'\ue71e'
    [yarn]=$'\ue718'
    [pnpm]=$'\ue718'
    [bun]=$'\ue76d'
    [deno]=$'\ue628'

    # Python
    [python]=$'\ue73c'
    [python3]=$'\ue73c'
    [pip]=$'\ue73c'
    [pipenv]=$'\ue73c'
    [poetry]=$'\ue73c'

    # Ruby
    [ruby]=$'\ue739'
    [irb]=$'\ue739'
    [rails]=$'\ue739'
    [bundle]=$'\ue739'

    # Go
    [go]=$'\ue627'

    # Rust
    [cargo]=$'\ue7a8'
    [rustc]=$'\ue7a8'

    # Java/JVM
    [java]=$'\ue738'
    [gradle]=$'\ue738'
    [mvn]=$'\ue738'

    # Containers/Cloud
    [docker]=$'\uf308'
    [kubectl]=$'\uf10fe'
    [k9s]=$'\uf10fe'
    [helm]=$'\uf10fe'
    [terraform]=$'\uf1bb'

    # Databases
    [psql]=$'\ue76e'
    [mysql]=$'\ue704'
    [redis - cli]=$'\ue76d'
    [mongosh]=$'\ue7a4'

    # System tools
    [htop]=$'\uf080'
    [top]=$'\uf080'
    [btop]=$'\uf080'
    [tmux]=$'\uebc8'

    # File managers
    [ranger]=$'\uf07b'
    [nnn]=$'\uf07b'
    [lf]=$'\uf07b'
    [mc]=$'\uf07b'

    # Network
    [ssh]=$'\uf489'
    [curl]=$'\uf0ac'
    [wget]=$'\uf0ed'

    # Misc
    [man]=$'\uf02d'
    [less]=$'\uf02d'
    [make]=$'\uf425'
    [cmake]=$'\uf425'
)

# Default window icon (when command not in map)
WINDOW_DEFAULT_ICON=$'\uf120'

# =============================================================================
# WINDOW INDEX ICON STYLES
# =============================================================================
# Available styles: text, numeric, box, box_outline, box_multiple, box_multiple_outline, circle, circle_outline
# - text: Plain numbers (1, 2, 3...)
# - numeric: Nerd Font numeric icons (󰬹, 󰬺, 󰬻...)
# - box: Numbers in filled boxes (󰎡, 󰎤, 󰎧...)
# - box_outline: Numbers in outlined boxes (󰎣, 󰎦, 󰎩...)
# - box_multiple: Numbers in multiple filled boxes (󰼎, 󰼏, 󰼐...)
# - box_multiple_outline: Numbers in multiple outlined boxes (󰎢, 󰎥, 󰎨...)
# - circle: Numbers in filled circles
# - circle_outline: Numbers in outlined circles

# shellcheck disable=SC2034
declare -gra WINDOW_INDEX_STYLES=(
    "text"
    "numeric"
    "box"
    "box_outline"
    "box_multiple"
    "box_multiple_outline"
    "circle"
    "circle_outline"
)

# Style: numeric (nf-md-numeric_X)
declare -grA WINDOW_INDEX_ICONS_NUMERIC=(
    [0]=$'\U000f0b39' # nf-md-numeric_0
    [1]=$'\U000f0b3a' # nf-md-numeric_1
    [2]=$'\U000f0b3b' # nf-md-numeric_2
    [3]=$'\U000f0b3c' # nf-md-numeric_3
    [4]=$'\U000f0b3d' # nf-md-numeric_4
    [5]=$'\U000f0b3e' # nf-md-numeric_5
    [6]=$'\U000f0b3f' # nf-md-numeric_6
    [7]=$'\U000f0b40' # nf-md-numeric_7
    [8]=$'\U000f0b41' # nf-md-numeric_8
    [9]=$'\U000f0b42' # nf-md-numeric_9
)

# Style: box (nf-md-numeric_X) - uses numeric glyphs, box appearance from index bg color
declare -grA WINDOW_INDEX_ICONS_BOX=(
    [0]=$'\U000f0b39' # nf-md-numeric_0
    [1]=$'\U000f0b3a' # nf-md-numeric_1
    [2]=$'\U000f0b3b' # nf-md-numeric_2
    [3]=$'\U000f0b3c' # nf-md-numeric_3
    [4]=$'\U000f0b3d' # nf-md-numeric_4
    [5]=$'\U000f0b3e' # nf-md-numeric_5
    [6]=$'\U000f0b3f' # nf-md-numeric_6
    [7]=$'\U000f0b40' # nf-md-numeric_7
    [8]=$'\U000f0b41' # nf-md-numeric_8
    [9]=$'\U000f0b42' # nf-md-numeric_9
)

# Style: box_outline (nf-md-numeric_X) - uses numeric glyphs, outline appearance from index bg color
declare -grA WINDOW_INDEX_ICONS_BOX_OUTLINE=(
    [0]=$'\U000f0b39' # nf-md-numeric_0
    [1]=$'\U000f0b3a' # nf-md-numeric_1
    [2]=$'\U000f0b3b' # nf-md-numeric_2
    [3]=$'\U000f0b3c' # nf-md-numeric_3
    [4]=$'\U000f0b3d' # nf-md-numeric_4
    [5]=$'\U000f0b3e' # nf-md-numeric_5
    [6]=$'\U000f0b3f' # nf-md-numeric_6
    [7]=$'\U000f0b40' # nf-md-numeric_7
    [8]=$'\U000f0b41' # nf-md-numeric_8
    [9]=$'\U000f0b42' # nf-md-numeric_9
)

# Style: box_multiple (nf-md-numeric_X) - uses numeric glyphs
declare -grA WINDOW_INDEX_ICONS_BOX_MULTIPLE=(
    [0]=$'\U000f0b39' # nf-md-numeric_0
    [1]=$'\U000f0b3a' # nf-md-numeric_1
    [2]=$'\U000f0b3b' # nf-md-numeric_2
    [3]=$'\U000f0b3c' # nf-md-numeric_3
    [4]=$'\U000f0b3d' # nf-md-numeric_4
    [5]=$'\U000f0b3e' # nf-md-numeric_5
    [6]=$'\U000f0b3f' # nf-md-numeric_6
    [7]=$'\U000f0b40' # nf-md-numeric_7
    [8]=$'\U000f0b41' # nf-md-numeric_8
    [9]=$'\U000f0b42' # nf-md-numeric_9
)

# Style: box_multiple_outline (nf-md-numeric_X) - uses numeric glyphs
declare -grA WINDOW_INDEX_ICONS_BOX_MULTIPLE_OUTLINE=(
    [0]=$'\U000f0b39' # nf-md-numeric_0
    [1]=$'\U000f0b3a' # nf-md-numeric_1
    [2]=$'\U000f0b3b' # nf-md-numeric_2
    [3]=$'\U000f0b3c' # nf-md-numeric_3
    [4]=$'\U000f0b3d' # nf-md-numeric_4
    [5]=$'\U000f0b3e' # nf-md-numeric_5
    [6]=$'\U000f0b3f' # nf-md-numeric_6
    [7]=$'\U000f0b40' # nf-md-numeric_7
    [8]=$'\U000f0b41' # nf-md-numeric_8
    [9]=$'\U000f0b42' # nf-md-numeric_9
)

# Style: circle (nf-md-numeric_X) - uses numeric glyphs, circle appearance from index bg color
# Icons are interleaved with circle_outline (+2 pattern)
declare -grA WINDOW_INDEX_ICONS_CIRCLE=(
    [0]=$'\U000f0b39' # nf-md-numeric_0
    [1]=$'\U000f0b3a' # nf-md-numeric_1
    [2]=$'\U000f0b3b' # nf-md-numeric_2
    [3]=$'\U000f0b3c' # nf-md-numeric_3
    [4]=$'\U000f0b3d' # nf-md-numeric_4
    [5]=$'\U000f0b3e' # nf-md-numeric_5
    [6]=$'\U000f0b3f' # nf-md-numeric_6
    [7]=$'\U000f0b40' # nf-md-numeric_7
    [8]=$'\U000f0b41' # nf-md-numeric_8
    [9]=$'\U000f0b42' # nf-md-numeric_9
)

# Style: circle_outline (nf-md-numeric_X) - uses numeric glyphs
# Icons are interleaved with circle (+2 pattern)
declare -grA WINDOW_INDEX_ICONS_CIRCLE_OUTLINE=(
    [0]=$'\U000f0b39' # nf-md-numeric_0
    [1]=$'\U000f0b3a' # nf-md-numeric_1
    [2]=$'\U000f0b3b' # nf-md-numeric_2
    [3]=$'\U000f0b3c' # nf-md-numeric_3
    [4]=$'\U000f0b3d' # nf-md-numeric_4
    [5]=$'\U000f0b3e' # nf-md-numeric_5
    [6]=$'\U000f0b3f' # nf-md-numeric_6
    [7]=$'\U000f0b40' # nf-md-numeric_7
    [8]=$'\U000f0b41' # nf-md-numeric_8
    [9]=$'\U000f0b42' # nf-md-numeric_9
)

# Legacy alias for backwards compatibility
# shellcheck disable=SC2034
declare -grA WINDOW_INDEX_ICON_MAP=(
    [0]=$'\U000f0b39' [1]=$'\U000f0b3a' [2]=$'\U000f0b3b'
    [3]=$'\U000f0b3c' [4]=$'\U000f0b3d' [5]=$'\U000f0b3e'
    [6]=$'\U000f0b3f' [7]=$'\U000f0b40' [8]=$'\U000f0b41'
    [9]=$'\U000f0b42'
)

# Fallback icon for window indices > 9
WINDOW_INDEX_FALLBACK_ICON=$'\uf120' # Terminal icon as fallback

# =============================================================================
# 5. HELPER CONSTANTS
# =============================================================================

# Valid helper types
# shellcheck disable=SC2034 # Used for validation
declare -gra HELPER_TYPES=(
    "popup"   # Opens in display-popup -E
    "menu"    # Uses display-menu
    "command" # Executes via run-shell
    "toast"   # Shows display-message
)

# Helper type descriptions
# shellcheck disable=SC2034 # Used for validation and documentation
declare -grA HELPER_TYPE_DESCRIPTIONS=(
    [popup]="Opens in tmux display-popup with interactive UI"
    [menu]="Uses native tmux display-menu"
    [command]="Executes action via run-shell (no UI)"
    [toast]="Shows brief notification via display-message"
)

# =============================================================================
# 6. HEALTH SYSTEM
# =============================================================================

# Valid health levels
declare -gra HEALTH_LEVELS=(
    "ok"      # Everything is fine
    "good"    # Better than ok, positive state
    "info"    # Informational state
    "warning" # Warning threshold reached
    "error"   # Error/critical threshold reached
)

# Health level precedence (for comparisons)
# Higher number = more severe
declare -grA HEALTH_PRECEDENCE=(
    [ok]=0
    [info]=1
    [good]=2
    [warning]=3
    [error]=4
)

# Health level descriptions
# shellcheck disable=SC2034 # Used for validation and documentation
declare -grA HEALTH_DESCRIPTIONS=(
    [ok]="Normal operation, everything is fine"
    [good]="Better than normal, positive state (e.g., unlocked, connected)"
    [info]="Informational state, not an error but noteworthy"
    [warning]="Warning threshold reached, needs attention soon"
    [error]="Critical threshold reached or failure occurred"
)

# =============================================================================
# 7. LOOKUP FUNCTIONS
# =============================================================================

# Get health level (numeric value for comparison)
# Usage: level=$(get_health_level "warning")  # Returns: 2
get_health_level() {
    local health="$1"
    echo "${HEALTH_PRECEDENCE[$health]:-0}"
}

# Compare health levels
# Usage: health_is_worse "error" "warning"  # Returns: 0 (true)
health_is_worse() {
    local health1="$1"
    local health2="$2"
    local level1="${HEALTH_PRECEDENCE[$health1]:-0}"
    local level2="${HEALTH_PRECEDENCE[$health2]:-0}"
    ((level1 > level2))
}

# Get the worse of two health levels
# Usage: worst=$(health_max "warning" "error")  # Returns: error
health_max() {
    local health1="$1"
    local health2="$2"
    health_is_worse "$health1" "$health2" && echo "$health1" || echo "$health2"
}

# Get window icon for command
# Usage: icon=$(get_window_icon "vim")
get_window_icon() {
    local command="$1"
    echo "${WINDOW_ICON_MAP[$command]:-$WINDOW_DEFAULT_ICON}"
}

# Get window index icon based on style
# Usage: icon=$(get_window_index_icon "1" "box")
# Styles: text, numeric, box, box_outline, box_multiple, box_multiple_outline, circle, circle_outline
get_window_index_icon() {
    local index="$1"
    local style="${2:-numeric}"

    # For "text" style, return the index as-is
    [[ "$style" == "text" ]] && {
        echo "$index"
        return
    }

    # For multi-digit indices, build icon digit by digit
    if ((index > 9)); then
        local result=""
        local digit
        while [[ -n "$index" ]]; do
            digit="${index:0:1}"
            index="${index:1}"
            result+="$(get_window_index_icon "$digit" "$style")"
        done
        echo "$result"
        return
    fi

    # Single digit - get from appropriate map
    local icon
    case "$style" in
    numeric)
        icon="${WINDOW_INDEX_ICONS_NUMERIC[$index]:-}"
        ;;
    box)
        icon="${WINDOW_INDEX_ICONS_BOX[$index]:-}"
        ;;
    box_outline)
        icon="${WINDOW_INDEX_ICONS_BOX_OUTLINE[$index]:-}"
        ;;
    box_multiple)
        icon="${WINDOW_INDEX_ICONS_BOX_MULTIPLE[$index]:-}"
        ;;
    box_multiple_outline)
        icon="${WINDOW_INDEX_ICONS_BOX_MULTIPLE_OUTLINE[$index]:-}"
        ;;
    circle)
        icon="${WINDOW_INDEX_ICONS_CIRCLE[$index]:-}"
        ;;
    circle_outline)
        icon="${WINDOW_INDEX_ICONS_CIRCLE_OUTLINE[$index]:-}"
        ;;
    *)
        icon="${WINDOW_INDEX_ICONS_NUMERIC[$index]:-}"
        ;;
    esac

    echo "${icon:-$WINDOW_INDEX_FALLBACK_ICON}"
}

# Check if window index has an icon for given style
# Usage: has_window_index_icon "5" "box" && echo "Has icon"
has_window_index_icon() {
    local index="$1"
    local style="${2:-numeric}"

    [[ "$style" == "text" ]] && return 0

    case "$style" in
    numeric) [[ -n "${WINDOW_INDEX_ICONS_NUMERIC[$index]:-}" ]] ;;
    box) [[ -n "${WINDOW_INDEX_ICONS_BOX[$index]:-}" ]] ;;
    box_outline) [[ -n "${WINDOW_INDEX_ICONS_BOX_OUTLINE[$index]:-}" ]] ;;
    box_multiple) [[ -n "${WINDOW_INDEX_ICONS_BOX_MULTIPLE[$index]:-}" ]] ;;
    box_multiple_outline) [[ -n "${WINDOW_INDEX_ICONS_BOX_MULTIPLE_OUTLINE[$index]:-}" ]] ;;
    *) [[ -n "${WINDOW_INDEX_ICONS_NUMERIC[$index]:-}" ]] ;;
    esac
}

# Check if window icon exists for command
# Usage: has_window_icon "vim" && echo "Has custom icon"
has_window_icon() {
    local command="$1"
    [[ -n "${WINDOW_ICON_MAP[$command]:-}" ]]
}

# =============================================================================
# Validation Functions (using registry data)
# =============================================================================

# Note: These functions use the arrays defined above.
# For more complex validation, use src/utils/validation.sh

# Check if plugin state is valid
is_valid_state() {
    local state="$1"
    local valid
    for valid in "${PLUGIN_STATES[@]}"; do
        [[ "$state" == "$valid" ]] && return 0
    done
    return 1
}

# Check if health level is valid
is_valid_health() {
    local health="$1"
    local valid
    for valid in "${HEALTH_LEVELS[@]}"; do
        [[ "$health" == "$valid" ]] && return 0
    done
    return 1
}

# Check if plugin content type is valid
is_valid_content_type() {
    local type="$1"
    local valid
    for valid in "${PLUGIN_CONTENT_TYPES[@]}"; do
        [[ "$type" == "$valid" ]] && return 0
    done
    return 1
}

# Check if plugin presence mode is valid
is_valid_presence() {
    local presence="$1"
    local valid
    for valid in "${PLUGIN_PRESENCE_MODES[@]}"; do
        [[ "$presence" == "$valid" ]] && return 0
    done
    return 1
}

# =============================================================================
# 9. BACKWARD COMPATIBILITY ALIASES
# =============================================================================

# Alias for PLUGIN_PRESENCE_MODES (some code uses PLUGIN_PRESENCE)
# shellcheck disable=SC2034
declare -ga PLUGIN_PRESENCE=("${PLUGIN_PRESENCE_MODES[@]}")

# Alias for HEALTH_LEVELS (some code uses PLUGIN_HEALTH)
# shellcheck disable=SC2034
declare -ga PLUGIN_HEALTH=("${HEALTH_LEVELS[@]}")
