#!/usr/bin/env bash
set -eu
# Note: pipefail removed because it causes issues with plugins that use pipes
# (e.g., battery.sh: pmset | grep fails with pipefail when pipe is broken early)

# =============================================================================
# Unified Plugin Renderer (KISS/DRY)
# Usage: render_plugins.sh "name:accent:accent_icon:icon:type;..."
# Types: static, conditional
# =============================================================================
#
# DEPENDENCIES: plugin_bootstrap.sh (loads defaults, utils, cache, plugin_helpers)
# =============================================================================

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Bootstrap (loads defaults, utils, cache, plugin_helpers)
# shellcheck source=src/plugin_bootstrap.sh
. "${CURRENT_DIR}/plugin_bootstrap.sh"

# Load theme - use @powerkit_theme and @powerkit_theme_variant
THEME_NAME=$(get_tmux_option "@powerkit_theme" "$POWERKIT_DEFAULT_THEME")
THEME_VARIANT=$(get_tmux_option "@powerkit_theme_variant" "")

# Auto-detect variant if not specified
if [[ -z "$THEME_VARIANT" ]]; then
    THEME_DIR="${CURRENT_DIR}/themes/${THEME_NAME}"
    if [[ -d "$THEME_DIR" ]]; then
        THEME_VARIANT=$(ls "$THEME_DIR"/*.sh 2>/dev/null | head -1 | xargs basename -s .sh 2>/dev/null || echo "")
    fi
fi
[[ -z "$THEME_VARIANT" ]] && THEME_VARIANT="$POWERKIT_DEFAULT_THEME_VARIANT"

THEME_FILE="${CURRENT_DIR}/themes/${THEME_NAME}/${THEME_VARIANT}.sh"
[[ -f "$THEME_FILE" ]] && . "$THEME_FILE"

# =============================================================================
# Configuration
# =============================================================================
# Use theme's white color for plugin text (ensures contrast on colored backgrounds)
TEXT_COLOR="${RENDER_TEXT_COLOR:-$(get_color 'white')}"
TEXT_COLOR="${TEXT_COLOR:-#ffffff}"  # Fallback if theme doesn't define white
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

# Get plugin defaults from defaults.sh
get_plugin_defaults() {
    local name="$1"
    local upper="${name^^}"
    upper="${upper//-/_}"
    
    local accent_var="POWERKIT_PLUGIN_${upper}_ACCENT_COLOR"
    local accent_icon_var="POWERKIT_PLUGIN_${upper}_ACCENT_COLOR_ICON"
    local icon_var="POWERKIT_PLUGIN_${upper}_ICON"
    
    printf '%s:%s:%s' "${!accent_var:-secondary}" "${!accent_icon_var:-active}" "${!icon_var:-}"
}

# Apply threshold colors if defined
# Returns: accent:accent_icon:has_threshold (has_threshold: 1 if triggered, 0 otherwise)
apply_thresholds() {
    local name="$1" content="$2" accent="$3" accent_icon="$4"
    local upper="${name^^}"
    upper="${upper//-/_}"

    # Extract first numeric value using bash regex (performance: avoids grep fork)
    local num=""
    [[ "$content" =~ ([0-9]+) ]] && num="${BASH_REMATCH[1]}"
    [[ -z "$num" ]] && { printf '%s:%s:0' "$accent" "$accent_icon"; return; }

    local warn_var="POWERKIT_PLUGIN_${upper}_WARNING_THRESHOLD"
    local crit_var="POWERKIT_PLUGIN_${upper}_CRITICAL_THRESHOLD"
    local warn="${!warn_var:-}" crit="${!crit_var:-}"

    [[ -z "$warn" || -z "$crit" ]] && { printf '%s:%s:0' "$accent" "$accent_icon"; return; }

    if [[ "$num" -ge "$crit" ]]; then
        local ca="POWERKIT_PLUGIN_${upper}_CRITICAL_ACCENT_COLOR"
        local ci="POWERKIT_PLUGIN_${upper}_CRITICAL_ACCENT_COLOR_ICON"
        printf '%s:%s:1' "${!ca:-$accent}" "${!ci:-$accent_icon}"
    elif [[ "$num" -ge "$warn" ]]; then
        local wa="POWERKIT_PLUGIN_${upper}_WARNING_ACCENT_COLOR"
        local wi="POWERKIT_PLUGIN_${upper}_WARNING_ACCENT_COLOR_ICON"
        printf '%s:%s:1' "${!wa:-$accent}" "${!wi:-$accent_icon}"
    else
        printf '%s:%s:0' "$accent" "$accent_icon"
    fi
}

# Clean content (remove status prefixes)
clean_content() {
    local c="$1"
    [[ "$c" =~ ^[a-z]+: ]] && c="${c#*:}"
    printf '%s' "${c#MODIFIED:}"
}

# Generate a simple hash from string (performance: avoids md5sum fork)
# Uses bash string manipulation for a fast, deterministic hash
_string_hash() {
    local str="$1"
    local hash=0
    local i char
    for ((i=0; i<${#str}; i++)); do
        char="${str:i:1}"
        hash=$(( (hash * 31 + $(printf '%d' "'$char")) % 2147483647 ))
    done
    printf '%s' "$hash"
}

# Execute shell command from content string (DRY - used by external plugins)
# Supports: #(command), $(command), #{tmux_var}
# Returns: executed content or empty string
_execute_content_command() {
    local content="$1"
    if [[ "$content" =~ ^\#\(.*\)$ ]]; then
        eval "${content:2:-1}" 2>/dev/null || printf ''
    elif [[ "$content" =~ ^\$\(.*\)$ ]]; then
        eval "${content:2:-1}" 2>/dev/null || printf ''
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
    IFS='|' read -r _ cfg_icon content cfg_accent cfg_accent_icon cfg_ttl cfg_name cfg_condition <<< "$config"
    [[ -z "$content" ]] && return 1

    # Default name for logging/telemetry
    cfg_name="${cfg_name:-external}"
    local cache_key="external_$(_string_hash "$content")"
    cfg_ttl="${cfg_ttl:-0}"

    # Start telemetry if available
    local start_ts=""
    declare -f telemetry_plugin_start &>/dev/null && start_ts=$(telemetry_plugin_start "$cfg_name")

    # Try cache first if TTL > 0
    local cache_hit="false"
    if [[ "$cfg_ttl" -gt 0 ]]; then
        local cached_content
        cached_content=$(cache_get "$cache_key" "$cfg_ttl" 2>/dev/null) || cached_content=""
        if [[ -n "$cached_content" ]]; then
            content="$cached_content"
            cache_hit="true"
        else
            content=$(_execute_content_command "$content")
            [[ -n "$content" ]] && cache_set "$cache_key" "$content" 2>/dev/null
        fi
    else
        content=$(_execute_content_command "$content")
    fi

    # Record telemetry
    [[ -n "$start_ts" ]] && declare -f telemetry_plugin_end &>/dev/null && \
        telemetry_plugin_end "$cfg_name" "$start_ts" "$cache_hit"

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

    local cfg_accent_strong
    cfg_accent_strong=$(get_color "${cfg_accent}-strong")
    cfg_accent=$(get_color "$cfg_accent")
    cfg_accent_icon=$(get_color "$cfg_accent_icon")

    # Add to global arrays
    NAMES+=("$cfg_name")
    CONTENTS+=("$content")
    ACCENTS+=("$cfg_accent")
    ACCENT_STRONGS+=("$cfg_accent_strong")
    ACCENT_ICONS+=("$cfg_accent_icon")
    ICONS+=("$cfg_icon")
    HAS_THRESHOLDS+=("0")

    log_debug "render" "External plugin '$cfg_name' loaded (cache_hit=$cache_hit)"
    return 0
}

# Process internal plugin configuration
# Args: config_string
# Returns: 0 on success (sets global arrays), 1 on skip
_process_internal_plugin() {
    local config="$1"

    IFS=':' read -r name cfg_accent cfg_accent_icon cfg_icon plugin_type <<< "$config"

    local plugin_script="${CURRENT_DIR}/plugin/${name}.sh"
    [[ ! -f "$plugin_script" ]] && return 1

    # Start telemetry
    local start_ts=""
    declare -f telemetry_plugin_start &>/dev/null && start_ts=$(telemetry_plugin_start "$name")

    # Clean previous plugin functions
    unset -f load_plugin plugin_get_display_info 2>/dev/null || true

    # Source plugin
    # shellcheck source=/dev/null
    . "$plugin_script" 2>/dev/null || return 1

    # Get content
    local content=""
    declare -f load_plugin &>/dev/null && content=$(load_plugin 2>/dev/null) || true

    # Skip conditional without content
    [[ "$plugin_type" == "conditional" && -z "$content" ]] && return 1

    # Get defaults if not in config
    local def_accent def_accent_icon def_icon
    IFS=':' read -r def_accent def_accent_icon def_icon <<< "$(get_plugin_defaults "$name")"
    [[ -z "$cfg_accent" ]] && cfg_accent="$def_accent"
    [[ -z "$cfg_accent_icon" ]] && cfg_accent_icon="$def_accent_icon"
    [[ -z "$cfg_icon" ]] && cfg_icon="$def_icon"

    # Store original accent to detect if plugin changes it
    local original_accent="$cfg_accent"

    # Check plugin's custom display info
    if declare -f plugin_get_display_info &>/dev/null; then
        local show ov_accent ov_accent_icon ov_icon
        IFS=':' read -r show ov_accent ov_accent_icon ov_icon <<< "$(plugin_get_display_info "${content,,}")"
        [[ "$show" == "0" ]] && return 1
        [[ -n "$ov_accent" ]] && cfg_accent="$ov_accent"
        [[ -n "$ov_accent_icon" ]] && cfg_accent_icon="$ov_accent_icon"
        [[ -n "$ov_icon" ]] && cfg_icon="$ov_icon"
    fi

    # Apply thresholds
    local has_threshold="0" threshold_flag
    IFS=':' read -r cfg_accent cfg_accent_icon threshold_flag <<< "$(apply_thresholds "$name" "$content" "$cfg_accent" "$cfg_accent_icon")"

    # Detect threshold state
    if [[ "$threshold_flag" == "1" ]] || [[ "$cfg_accent" != "$original_accent" ]]; then
        has_threshold="1"
    fi

    # Resolve colors
    local cfg_accent_strong
    cfg_accent_strong=$(get_color "${cfg_accent}-strong")
    cfg_accent=$(get_color "$cfg_accent")
    cfg_accent_icon=$(get_color "$cfg_accent_icon")

    # Add to global arrays
    NAMES+=("$name")
    CONTENTS+=("$(clean_content "$content")")
    ACCENTS+=("$cfg_accent")
    ACCENT_STRONGS+=("$cfg_accent_strong")
    ACCENT_ICONS+=("$cfg_accent_icon")
    ICONS+=("$cfg_icon")
    HAS_THRESHOLDS+=("$has_threshold")

    # Record telemetry (note: cache hits are already tracked in cache_get_or_compute)
    [[ -n "$start_ts" ]] && declare -f telemetry_plugin_end &>/dev/null && \
        telemetry_plugin_end "$name" "$start_ts" "false"

    return 0
}

# =============================================================================
# Main Processing Loop
# =============================================================================

declare -a NAMES=() CONTENTS=() ACCENTS=() ACCENT_STRONGS=() ACCENT_ICONS=() ICONS=() HAS_THRESHOLDS=()

IFS=';' read -ra CONFIGS <<< "$PLUGINS_CONFIG"

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

output=""
prev_accent=""

for ((i=0; i<total; i++)); do
    content="${CONTENTS[$i]}"
    accent="${ACCENTS[$i]}"
    accent_strong="${ACCENT_STRONGS[$i]}"
    accent_icon="${ACCENT_ICONS[$i]}"
    icon="${ICONS[$i]}"
    has_threshold="${HAS_THRESHOLDS[$i]}"
    
    # Separators (left-facing: fg=new color, bg=previous color)
    if [[ $i -eq 0 ]]; then
        # First plugin separator
        if [[ "$SEPARATOR_STYLE" == "rounded" ]]; then
            # Rounded/pill effect - fg=plugin_color, bg=status_bg
            sep_start="#[fg=${accent_icon},bg=${STATUS_BG}]${LEFT_SEPARATOR_ROUNDED}#[none]"
        else
            # Normal powerline - fg=plugin_color, bg=status_bg
            sep_start="#[fg=${accent_icon},bg=${STATUS_BG}]${RIGHT_SEPARATOR}#[none]"
        fi
    else
        sep_start="#[fg=${accent_icon},bg=${prev_accent}]${RIGHT_SEPARATOR}#[none]"
    fi

    sep_mid="#[fg=${accent},bg=${accent_icon}]${RIGHT_SEPARATOR}#[none]"
    
    # Build output - consistent spacing: " ICON SEP TEXT "
    # Icon text: white for normal state, accent-strong when threshold is triggered
    if [[ "$has_threshold" == "1" ]]; then
        output+="${sep_start}#[fg=${accent_strong},bg=${accent_icon},bold]${icon} ${sep_mid}"
    else
        output+="${sep_start}#[fg=${TEXT_COLOR},bg=${accent_icon},bold]${icon} ${sep_mid}"
    fi
    
    # Content text: use accent-strong + bold when threshold is triggered for better visibility
    content_fg="${TEXT_COLOR}"
    content_style=""
    if [[ "$has_threshold" == "1" && -n "$accent_strong" ]]; then
        content_fg="$accent_strong"
        content_style=",bold"
    fi

    if [[ $i -eq $((total-1)) ]]; then
        output+="#[fg=${content_fg},bg=${accent}${content_style}] ${content} "
    else
        output+="#[fg=${content_fg},bg=${accent}${content_style}] ${content} #[none]"
    fi
    
    prev_accent="$accent"
done

printf '%s' "$output"
