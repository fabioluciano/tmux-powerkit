#!/usr/bin/env bash
set -eu
# Note: pipefail removed because it causes issues with plugins that use pipes
# (e.g., battery.sh: pmset | grep fails with pipefail when pipe is broken early)

# =============================================================================
# Unified Plugin Renderer (KISS/DRY)
# Usage: render_plugins.sh "name:accent:accent_icon:icon:type;..."
# Valid Types: static, conditional
# Note: "dynamic" type is deprecated - plugins should use conditional with
#       threshold_mode option instead. For backwards compatibility, dynamic
#       is treated as conditional.
# =============================================================================
#
# DEPENDENCIES: plugin_bootstrap.sh (loads defaults, utils, cache, plugin_helpers)
# =============================================================================

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Bootstrap (loads defaults, utils, cache, plugin_helpers)
# shellcheck source=src/plugin_bootstrap.sh
. "${CURRENT_DIR}/plugin_bootstrap.sh"

# Load theme using centralized function (DRY - avoids duplicating theme loading logic)
load_powerkit_theme

# =============================================================================
# Configuration
# =============================================================================
# Use theme's white color for plugin text (ensures contrast on colored backgrounds)
TEXT_COLOR="${RENDER_TEXT_COLOR:-$(get_color 'white')}"
TEXT_COLOR="${TEXT_COLOR:-#ffffff}" # Fallback if theme doesn't define white
STATUS_BG="${RENDER_STATUS_BG:-${POWERKIT_FALLBACK_STATUS_BG:-#1a1b26}}"
TRANSPARENT="${RENDER_TRANSPARENT:-false}"
PLUGINS_CONFIG="${1:-}"

RIGHT_SEPARATOR=$(get_tmux_option "@powerkit_right_separator" "$POWERKIT_DEFAULT_RIGHT_SEPARATOR")
RIGHT_SEPARATOR_INVERSE=$(get_tmux_option "@powerkit_right_separator_inverse" "$POWERKIT_DEFAULT_RIGHT_SEPARATOR_INVERSE")
LEFT_SEPARATOR_ROUNDED=$(get_tmux_option "@powerkit_left_separator_rounded" "$POWERKIT_DEFAULT_LEFT_SEPARATOR_ROUNDED")
SEPARATOR_STYLE=$(get_tmux_option "@powerkit_separator_style" "$POWERKIT_DEFAULT_SEPARATOR_STYLE")

# =============================================================================
# Helpers
# =============================================================================

# Note: get_color() is now provided by utils.sh (alias for get_powerkit_color)

# Get plugin defaults from plugin's declared options (via get_option)
# Called AFTER plugin is sourced, so get_option() has access to declarations
get_plugin_defaults() {
    local name="$1"
    local accent accent_icon icon

    # Use get_option which reads from plugin_declare_options() defaults
    accent=$(get_option "accent_color" 2>/dev/null) || accent="secondary"
    accent_icon=$(get_option "accent_color_icon" 2>/dev/null) || accent_icon="active"
    icon=$(get_option "icon" 2>/dev/null) || icon=""

    printf '%s:%s:%s' "$accent" "$accent_icon" "$icon"
}

# Apply threshold colors if defined (DRY - uses apply_threshold_colors from plugin_helpers)
# Returns: accent:accent_icon:has_threshold (has_threshold: 1 if triggered, 0 otherwise)
apply_thresholds() {
    local name="$1" content="$2" accent="$3" accent_icon="$4"

    # Extract first numeric value using bash regex (performance: avoids grep fork)
    local num=""
    [[ "$content" =~ ([0-9]+) ]] && num="${BASH_REMATCH[1]}"
    [[ -z "$num" ]] && {
        printf '%s:%s:0' "$accent" "$accent_icon"
        return
    }

    # Use shared apply_threshold_colors from plugin_helpers.sh
    local result
    result=$(apply_threshold_colors "$num" "$name" 0)

    # If threshold triggered, return new colors with flag
    if [[ -n "$result" ]]; then
        printf '%s:1' "$result"
    else
        # No threshold triggered, return original colors
        printf '%s:%s:0' "$accent" "$accent_icon"
    fi
}

# Clean content (remove status prefixes)
clean_content() {
    local c="$1"
    [[ "$c" =~ ^[a-z]+: ]] && c="${c#*:}"
    printf '%s' "${c#MODIFIED:}"
}

# Generate a simple hash from string (performance optimized)
# Uses cksum (built-in Unix command) instead of character-by-character loop
# ~10x faster than previous implementation for typical strings
_string_hash() {
    local str="$1"
    printf '%s' "$str" | cksum | awk '{print $1}'
}

# Execute shell command from content string (DRY - used by external plugins)
# Supports: #(command), $(command), #{tmux_var}
# Also expands #{...} inside $(command) and #(command) before execution
# Returns: executed content or empty string
_execute_content_command() {
    local content="$1"
    local cmd
    if [[ "$content" =~ ^\#\(.*\)$ ]]; then
        cmd="${content:2:-1}"
        # Expand #{...} inside command first
        [[ "$cmd" == *'#{'*'}'* ]] && cmd=$(tmux display-message -p "$cmd" 2>/dev/null)
        eval "$cmd" 2>/dev/null || printf ''
    elif [[ "$content" =~ ^\$\(.*\)$ ]]; then
        cmd="${content:2:-1}"
        # Expand #{...} inside command first
        [[ "$cmd" == *'#{'*'}'* ]] && cmd=$(tmux display-message -p "$cmd" 2>/dev/null)
        eval "$cmd" 2>/dev/null || printf ''
    elif [[ "$content" == *'#{'*'}'* ]]; then
        tmux display-message -p "$content" 2>/dev/null || printf ''
    else
        printf '%s' "$content"
    fi
}

# Process external plugin configuration
# Extended format: EXTERNAL|icon|content|accent|accent_icon|ttl|name|condition
# Args: config_string
# Returns: 0 on success (sets global arrays), 1 on skip
_process_external_plugin() {
    local config="$1"

    # Extended parsing with optional name and condition
    local cfg_icon content cfg_accent cfg_accent_icon cfg_ttl cfg_name cfg_condition
    IFS='|' read -r _ cfg_icon content cfg_accent cfg_accent_icon cfg_ttl cfg_name cfg_condition <<<"$config"
    [[ -z "$content" ]] && return 1

    # Default name for logging
    cfg_name="${cfg_name:-external}"
    local cache_key="external_$(_string_hash "$content")"
    cfg_ttl="${cfg_ttl:-0}"

    # Try cache first if TTL > 0
    if [[ "$cfg_ttl" -gt 0 ]]; then
        local cached_content
        cached_content=$(cache_get "$cache_key" "$cfg_ttl" 2>/dev/null) || cached_content=""
        if [[ -n "$cached_content" ]]; then
            content="$cached_content"
        else
            content=$(_execute_content_command "$content")
            [[ -n "$content" ]] && cache_set "$cache_key" "$content" 2>/dev/null
        fi
    else
        content=$(_execute_content_command "$content")
    fi

    # Check condition (optional - skip plugin if condition fails)
    if [[ -n "$cfg_condition" ]]; then
        local condition_result
        condition_result=$(_execute_content_command "$cfg_condition" 2>/dev/null)
        # Skip if condition returns empty, "false", "0", or non-zero exit
        [[ -z "$condition_result" || "$condition_result" == "false" || "$condition_result" == "0" ]] && return 1
    fi

    [[ -z "$content" ]] && return 1

    # Resolve colors with defaults
    cfg_accent="${cfg_accent:-secondary}"
    cfg_accent_icon="${cfg_accent_icon:-active}"

    local cfg_accent_strong cfg_accent_subtle
    cfg_accent_strong=$(get_color "${cfg_accent}-strong")
    cfg_accent_subtle=$(get_color "${cfg_accent}-subtle")
    cfg_accent=$(get_color "$cfg_accent")
    cfg_accent_icon=$(get_color "$cfg_accent_icon")

    # Add to global arrays
    NAMES+=("$cfg_name")
    CONTENTS+=("$content")
    ACCENTS+=("$cfg_accent")
    ACCENT_STRONGS+=("$cfg_accent_strong")
    ACCENT_SUBTLES+=("$cfg_accent_subtle")
    ACCENT_ICONS+=("$cfg_accent_icon")
    ICONS+=("$cfg_icon")
    HAS_THRESHOLDS+=("0")

    log_debug "render" "External plugin '$cfg_name' loaded"
    return 0
}

# Process internal plugin configuration
# Args: config_string
# Returns: 0 on success (sets global arrays), 1 on skip
_process_internal_plugin() {
    local config="$1"

    IFS=':' read -r name cfg_accent cfg_accent_icon cfg_icon plugin_type <<<"$config"

    local plugin_script="${CURRENT_DIR}/plugin/${name}.sh"
    [[ ! -f "$plugin_script" ]] && return 1

    # Clean previous plugin functions
    unset -f load_plugin plugin_get_display_info plugin_check_dependencies plugin_get_type plugin_declare_options 2>/dev/null || true

    # Source plugin
    # shellcheck source=/dev/null
    . "$plugin_script" 2>/dev/null || return 1

    # ==========================================================================
    # Contract Validation: Reject non-compliant plugins
    # Required functions: plugin_get_type, load_plugin
    # ==========================================================================
    if ! declare -f plugin_get_type &>/dev/null; then
        log_error "render" "Plugin '$name' REJECTED: missing required function plugin_get_type()"
        return 1
    fi

    if ! declare -f load_plugin &>/dev/null; then
        log_error "render" "Plugin '$name' REJECTED: missing required function load_plugin()"
        return 1
    fi

    # Check dependencies if plugin implements the contract
    if ! run_plugin_dependency_check; then
        local missing
        missing=$(get_missing_deps)
        # Only show error if there are actual missing dependencies
        # (plugins can return 1 silently to indicate "not supported on this platform")
        if [[ -n "$missing" ]]; then
            log_error "render" "Plugin '$name' skipped: missing dependencies: $missing"
            # Show toast notification to user (only once per session)
            local toast_key="deps_notified_${name}"
            if [[ -z "${!toast_key:-}" ]]; then
                declare -g "$toast_key=1"
                tmux display-message "PowerKit: Plugin '$name' disabled - missing: $missing" 2>/dev/null || true
            fi
        fi
        return 1
    fi

    # Get content
    local content=""
    declare -f load_plugin &>/dev/null && content=$(load_plugin 2>/dev/null) || true

    # Skip conditional/dynamic without content (dynamic treated as conditional)
    [[ ("$plugin_type" == "conditional" || "$plugin_type" == "dynamic") && -z "$content" ]] && return 1

    # Get defaults if not in config
    local def_accent def_accent_icon def_icon
    IFS=':' read -r def_accent def_accent_icon def_icon <<<"$(get_plugin_defaults "$name")"
    [[ -z "$cfg_accent" ]] && cfg_accent="$def_accent"
    [[ -z "$cfg_accent_icon" ]] && cfg_accent_icon="$def_accent_icon"
    [[ -z "$cfg_icon" ]] && cfg_icon="$def_icon"

    # Store original accent to detect if plugin changes it
    local original_accent="$cfg_accent"
    local plugin_provided_colors="0"

    # Check plugin's custom display info
    if declare -f plugin_get_display_info &>/dev/null; then
        local show ov_accent ov_accent_icon ov_icon
        IFS=':' read -r show ov_accent ov_accent_icon ov_icon <<<"$(plugin_get_display_info "${content,,}")"
        [[ "$show" == "0" ]] && return 1

        # Track if plugin provided explicit colors (even if same as defaults)
        if [[ -n "$ov_accent" ]]; then
            cfg_accent="$ov_accent"
            plugin_provided_colors="1"
        fi
        [[ -n "$ov_accent_icon" ]] && cfg_accent_icon="$ov_accent_icon"
        [[ -n "$ov_icon" ]] && cfg_icon="$ov_icon"
    fi

    # Detect threshold state (plugin controls this via plugin_get_display_info)
    # Threshold is detected when plugin changes colors from defaults
    local has_threshold="0"
    if [[ "$cfg_accent" != "$original_accent" ]]; then
        has_threshold="1"
    fi

    # Resolve colors
    local cfg_accent_strong cfg_accent_subtle
    cfg_accent_strong=$(get_color "${cfg_accent}-strong")
    cfg_accent_subtle=$(get_color "${cfg_accent}-subtle")
    cfg_accent=$(get_color "$cfg_accent")
    cfg_accent_icon=$(get_color "$cfg_accent_icon")

    # Add to global arrays
    NAMES+=("$name")
    CONTENTS+=("$(clean_content "$content")")
    ACCENTS+=("$cfg_accent")
    ACCENT_STRONGS+=("$cfg_accent_strong")
    ACCENT_SUBTLES+=("$cfg_accent_subtle")
    ACCENT_ICONS+=("$cfg_accent_icon")
    ICONS+=("$cfg_icon")
    HAS_THRESHOLDS+=("$has_threshold")

    return 0
}

# =============================================================================
# Main Processing Loop
# =============================================================================

declare -a NAMES=() CONTENTS=() ACCENTS=() ACCENT_STRONGS=() ACCENT_SUBTLES=() ACCENT_ICONS=() ICONS=() HAS_THRESHOLDS=()

IFS=';' read -ra CONFIGS <<<"$PLUGINS_CONFIG"

for config in "${CONFIGS[@]}"; do
    [[ -z "$config" ]] && continue

    if [[ "$config" == EXTERNAL\|* ]]; then
        _process_external_plugin "$config" || continue
    else
        _process_internal_plugin "$config" || continue
    fi
done

# =============================================================================
# Render
# =============================================================================

total=${#NAMES[@]}
[[ $total -eq 0 ]] && exit 0

# Check if spacing is enabled
ELEMENTS_SPACING=$(get_tmux_option "@powerkit_elements_spacing" "$POWERKIT_DEFAULT_ELEMENTS_SPACING")

output=""
prev_accent=""

for ((i = 0; i < total; i++)); do
    content="${CONTENTS[$i]}"
    accent="${ACCENTS[$i]}"
    accent_strong="${ACCENT_STRONGS[$i]}"
    accent_subtle="${ACCENT_SUBTLES[$i]}"
    accent_icon="${ACCENT_ICONS[$i]}"
    icon="${ICONS[$i]}"
    has_threshold="${HAS_THRESHOLDS[$i]}"

    # Add spacing after previous element if enabled
    if [[ $i -gt 0 && ("$ELEMENTS_SPACING" == "both" || "$ELEMENTS_SPACING" == "plugins") ]]; then
        # Spacing with proper background color
        spacing_bg=""
        spacing_fg=""
        if [[ "$TRANSPARENT" == "true" ]]; then
            spacing_bg="default"                 # Transparent background
            spacing_fg=$(get_color 'background') # Separator needs solid color from theme
        else
            spacing_bg=$(get_color 'surface')
            spacing_fg="$spacing_bg"
        fi

        # Extend previous plugin color + close it + neutral gap
        output+=" #[fg=${spacing_fg},bg=${prev_accent}]${RIGHT_SEPARATOR}#[bg=${spacing_bg}]#[none]"
        prev_accent="$spacing_bg"
    fi

    # When threshold/severity is triggered, use semantic colors:
    # - Icon background: accent-subtle (e.g., error-subtle)
    # - Content background: accent (e.g., error)
    # - Text color: accent-strong (e.g., error-strong)
    if [[ "$has_threshold" == "1" && -n "$accent_subtle" ]]; then
        icon_bg="$accent_subtle"
        content_bg="$accent"
        text_fg="$accent_strong"
    else
        icon_bg="$accent_icon"
        content_bg="$accent"
        text_fg="$TEXT_COLOR"
    fi

    # Separators (left-facing: fg=new color, bg=previous color)
    if [[ $i -eq 0 ]]; then
        # First plugin separator
        # Use default background when transparent mode is enabled
        first_sep_bg="${STATUS_BG}"
        [[ "$TRANSPARENT" == "true" ]] && first_sep_bg="default"

        if [[ "$SEPARATOR_STYLE" == "rounded" ]]; then
            # Rounded/pill effect - fg=plugin_color, bg=status_bg
            sep_start="#[fg=${icon_bg},bg=${first_sep_bg}]${LEFT_SEPARATOR_ROUNDED}#[none]"
        else
            # Normal powerline - fg=plugin_color, bg=status_bg
            sep_start="#[fg=${icon_bg},bg=${first_sep_bg}]${RIGHT_SEPARATOR}#[none]"
        fi
    else
        sep_start="#[fg=${icon_bg},bg=${prev_accent}]${RIGHT_SEPARATOR}#[none]"
    fi

    sep_mid="#[fg=${content_bg},bg=${icon_bg}]${RIGHT_SEPARATOR}#[none]"

    # Build output - consistent spacing: " ICON SEP TEXT "
    output+="${sep_start}#[fg=${text_fg},bg=${icon_bg},bold]${icon} ${sep_mid}"

    # Content text
    if [[ $i -eq $((total - 1)) ]]; then
        output+="#[fg=${text_fg},bg=${content_bg},bold] ${content} "
    else
        output+="#[fg=${text_fg},bg=${content_bg},bold] ${content} #[none]"
    fi

    prev_accent="$content_bg"
done

printf '%s' "$output"
