#!/usr/bin/env bash
# =============================================================================
# PowerKit Renderer: Segment Builder
# Description: Builds status bar segments using template system
# =============================================================================
#
# This module builds formatted tmux status bar segments from plugin data.
# It handles color resolution, separators, and stale data indication.
#
# KEY FUNCTIONS:
#   render_plugins()            - Main entry point for powerkit-render
#   render_plugin_segment()     - Render a single plugin segment
#   build_segment()             - Build segment from template
#
# PLUGIN DATA FORMAT (from lifecycle):
#   "icon<US>content<US>state<US>health<US>stale"
#   - 5 fields separated by Unit Separator (\x1f)
#   - stale field: "0"=fresh, "1"=cached data (triggers darker colors)
#
# STALE INDICATOR:
#   When parsing plugin data, the stale field is passed to resolve_plugin_colors_full()
#   which applies @powerkit_stale_color_variant to background colors.
#
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "renderer_segment_builder" && return 0

. "${POWERKIT_ROOT}/src/core/logger.sh"
. "${POWERKIT_ROOT}/src/core/options.sh"
. "${POWERKIT_ROOT}/src/core/registry.sh"
. "${POWERKIT_ROOT}/src/renderer/separator.sh"
. "${POWERKIT_ROOT}/src/renderer/color_resolver.sh"

# =============================================================================
# Template System
# =============================================================================

# Default segment template
# Variables: {sep_left}, {sep_right}, {sep_internal}, {icon}, {icon_bg}, {icon_fg},
#            {content}, {content_bg}, {content_fg}, {prev_bg}, {next_bg}
declare -g DEFAULT_SEGMENT_TEMPLATE='{sep_left}{icon_section}{sep_internal}{content_section}{sep_right}'

# Get global or plugin-specific template
# Usage: get_segment_template ["plugin_name"]
# shellcheck disable=SC2120  # Function designed to be called with or without arguments
get_segment_template() {
    local plugin="${1:-}"

    # Try plugin-specific template first
    if [[ -n "$plugin" ]]; then
        local plugin_template
        plugin_template=$(get_tmux_option "@powerkit_plugin_${plugin}_template" "")
        [[ -n "$plugin_template" ]] && { printf '%s' "$plugin_template"; return; }
    fi

    # Fall back to global template
    get_tmux_option "@powerkit_segment_template" "$DEFAULT_SEGMENT_TEMPLATE"
}

# =============================================================================
# Segment Building
# =============================================================================

# Build a complete segment from parts
# Usage: build_segment "icon" "content" "icon_bg" "icon_fg" "content_bg" "content_fg" "prev_bg" "next_bg" ["template"]
build_segment() {
    local icon="$1"
    local content="$2"
    local icon_bg="$3"
    local icon_fg="$4"
    local content_bg="$5"
    local content_fg="$6"
    local prev_bg="${7:-default}"
    local next_bg="${8:-default}"
    local template="${9:-}"

    [[ -z "$template" ]] && template=$(get_segment_template)

    # Build separator glyphs (use pre-populated cache - no subshells)
    local sep_left="${_SEP_CACHE_LEFT}"
    local sep_right="${_SEP_CACHE_RIGHT}"
    local sep_internal="${_SEP_CACHE_RIGHT}"

    # Build icon section
    local icon_section=""
    if [[ -n "$icon" ]]; then
        icon_section="#[fg=${icon_fg},bg=${icon_bg}] ${icon} "
    fi

    # Build content section
    local content_section=""
    if [[ -n "$content" ]]; then
        content_section="#[fg=${content_fg},bg=${content_bg}] ${content} "
    fi

    # Build left separator (transition from prev_bg to icon_bg or content_bg)
    local left_sep_target="${icon_bg}"
    [[ -z "$icon" ]] && left_sep_target="${content_bg}"
    local sep_left_full="#[fg=${left_sep_target},bg=${prev_bg}]${sep_left}"

    # Build internal separator (between icon and content)
    local sep_internal_full=""
    if [[ -n "$icon" && -n "$content" ]]; then
        sep_internal_full="#[fg=${icon_bg},bg=${content_bg}]${sep_internal}"
    fi

    # Build right separator (transition from content_bg to next_bg)
    local right_sep_source="${content_bg}"
    [[ -z "$content" ]] && right_sep_source="${icon_bg}"
    local sep_right_full="#[fg=${right_sep_source},bg=${next_bg}]${sep_right}"

    # Replace template variables
    local result="$template"
    result="${result//\{sep_left\}/$sep_left_full}"
    result="${result//\{sep_right\}/$sep_right_full}"
    result="${result//\{sep_internal\}/$sep_internal_full}"
    result="${result//\{icon\}/$icon}"
    result="${result//\{icon_bg\}/$icon_bg}"
    result="${result//\{icon_fg\}/$icon_fg}"
    result="${result//\{content\}/$content}"
    result="${result//\{content_bg\}/$content_bg}"
    result="${result//\{content_fg\}/$content_fg}"
    result="${result//\{prev_bg\}/$prev_bg}"
    result="${result//\{next_bg\}/$next_bg}"
    result="${result//\{icon_section\}/$icon_section}"
    result="${result//\{content_section\}/$content_section}"

    printf '%s' "$result"
}

# =============================================================================
# Plugin Segment Building (for status-right)
# =============================================================================

# Build a segment for a plugin using lifecycle output
# NOTE: Plugins use LEFT separators (◀) because they're in status-right
# Structure: [sep_start]◀[icon_section] [sep_mid]◀[content_section]
# - sep_start: fg=icon_bg, bg=prev_bg (arrow points left, fg is where arrow points)
# - sep_mid: fg=content_bg, bg=icon_bg (transitions from icon to content)
# Both icon and content are dynamic via #() for real-time updates
# Usage: build_plugin_segment "plugin_name" "prev_bg" "next_bg"
build_plugin_segment() {
    local plugin="$1"
    local prev_bg="${2:-default}"
    local next_bg="${3:-default}"

    # Get plugin output from lifecycle
    local state health context
    state=$(get_plugin_output "$plugin" "state")
    health=$(get_plugin_output "$plugin" "health")
    context=$(get_plugin_output "$plugin" "context")

    # Check visibility
    if ! is_plugin_visible "$plugin"; then
        return
    fi

    # Resolve colors based on state/health/context
    local content_bg content_fg icon_bg icon_fg
    read -r content_bg content_fg icon_bg icon_fg <<< "$(resolve_plugin_colors_full "$state" "$health" "$context")"

    # Get LEFT separator (◀) - plugins in status-right use left-pointing arrows
    local sep_left="${_SEP_CACHE_LEFT}"

    # Script paths for dynamic content
    local icon_runner="${POWERKIT_ROOT}/bin/powerkit-icon"
    local plugin_runner="${POWERKIT_ROOT}/bin/powerkit-plugin"

    # Build the segment using LEFT separators (pointing left ◀)
    local format=""

    # Opening separator: transitions from prev_bg INTO icon_bg
    format+="#[fg=${icon_bg},bg=${prev_bg}]${sep_left}#[none]"

    # Icon section - dynamic via #()
    format+="#[fg=${icon_fg},bg=${icon_bg},bold]#(${icon_runner} ${plugin}) "

    # Internal separator between icon and content
    format+="#[fg=${content_bg},bg=${icon_bg}]${sep_left}#[none]"

    # Content section - dynamic via #()
    format+="#[fg=${content_fg},bg=${content_bg},bold] #(${plugin_runner} ${plugin}) "

    printf '%s' "$format"
}

# =============================================================================
# Simplified Segment Building
# =============================================================================

# Build a simple segment (icon + content) with automatic color resolution
# Usage: build_simple_segment "icon" "content" "accent" "prev_bg" "next_bg"
build_simple_segment() {
    local icon="$1"
    local content="$2"
    local accent="${3:-ok-bg}"
    local prev_bg="${4:-default}"
    local next_bg="${5:-default}"

    local content_bg content_fg icon_bg icon_fg

    content_bg=$(resolve_color "$accent")
    icon_bg=$(resolve_color "${accent}-darker" 2>/dev/null || resolve_color "ok-icon-bg")
    # Use the appropriate fg color for the accent (ok-fg for ok-bg, etc.)
    content_fg=$(resolve_color "${accent//-bg/-fg}" 2>/dev/null || resolve_color "ok-fg")
    icon_fg="$content_fg"

    build_segment "$icon" "$content" "$icon_bg" "$icon_fg" "$content_bg" "$content_fg" "$prev_bg" "$next_bg"
}

# Build segment without icon
# Usage: build_content_segment "content" "accent" "prev_bg" "next_bg"
build_content_segment() {
    local content="$1"
    local accent="${2:-ok-bg}"
    local prev_bg="${3:-default}"
    local next_bg="${4:-default}"

    build_simple_segment "" "$content" "$accent" "$prev_bg" "$next_bg"
}

# Build segment without content (icon only)
# Usage: build_icon_segment "icon" "accent" "prev_bg" "next_bg"
build_icon_segment() {
    local icon="$1"
    local accent="${2:-ok-bg}"
    local prev_bg="${3:-default}"
    local next_bg="${4:-default}"

    local icon_bg icon_fg
    icon_bg=$(resolve_color "$accent")
    # Use the appropriate fg color for the accent
    icon_fg=$(resolve_color "${accent//-bg/-fg}" 2>/dev/null || resolve_color "ok-fg")

    local sep_left="${_SEP_CACHE_LEFT}"
    local sep_right="${_SEP_CACHE_RIGHT}"

    printf '#[fg=%s,bg=%s]%s#[fg=%s,bg=%s] %s #[fg=%s,bg=%s]%s' \
        "$icon_bg" "$prev_bg" "$sep_left" \
        "$icon_fg" "$icon_bg" "$icon" \
        "$icon_bg" "$next_bg" "$sep_right"
}

# =============================================================================
# Plugin Segment Rendering (for powerkit-render)
# =============================================================================

# Render a plugin segment for status bar
# This is the main function used by powerkit-render
# Usage: render_plugin_segment "icon" "content" "state" "health" "icon_bg" "icon_fg" "content_bg" "content_fg" "prev_bg" ["is_first"] ["is_last"] ["side"]
# - is_first: 1 if this is the first plugin (affects opening separator)
# - is_last: 1 if this is the last plugin (affects closing separator)
# - side: "left" or "right" (default: "right" for backwards compatibility)
#   - "left": plugins on left side of bar → RIGHT-pointing separators (▶)
#     - First plugin: NO opening separator (starts from statusbar)
#     - Last plugin: edge closing separator (to statusbar before windows)
#   - "right": plugins on right side of bar → LEFT-pointing separators (◀)
#     - First plugin: edge opening separator (from statusbar)
#     - Last plugin: NO closing separator (next element follows)
# Returns: formatted segment string
render_plugin_segment() {
    local icon="$1"
    local content="$2"
    local state="$3"
    local health="$4"
    local icon_bg="$5"
    local icon_fg="$6"
    local content_bg="$7"
    local content_fg="$8"
    local prev_bg="$9"
    local is_first="${10:-0}"
    local is_last="${11:-0}"
    local side="${12:-right}"

    local sep_internal
    sep_internal=$(get_internal_separator_for_side "$side")

    local segment=""

    # Opening separator logic depends on side and position
    if [[ "$side" == "left" ]]; then
        # Left side: plugins flow left-to-right with RIGHT separators (▶)
        # First plugin: NO opening separator (starts directly from statusbar bg)
        # Other plugins: normal right separator
        if [[ $is_first -eq 1 ]]; then
            # First plugin: add small padding from edge
            segment+="#[bg=${icon_bg}] "
        else
            # Right-pointing (▶): fg=source (prev), bg=destination (icon)
            segment+="#[fg=${prev_bg},bg=${icon_bg}]${_SEP_CACHE_RIGHT}#[none]"
        fi
    else
        # Right side: plugins flow right-to-left with LEFT separators (◀)
        # First plugin: edge opening separator (from statusbar)
        # Other plugins: normal left separator
        local sep_opening
        if [[ $is_first -eq 1 ]]; then
            sep_opening="${_SEP_CACHE_INITIAL}"
        else
            sep_opening="${_SEP_CACHE_LEFT}"
        fi
        # Left-pointing (◀): fg=destination (icon), bg=source (prev)
        segment+="#[fg=${icon_bg},bg=${prev_bg}]${sep_opening}#[none]"
    fi

    # Icon section (no bold - icons don't need emphasis)
    if [[ -n "$icon" ]]; then
        segment+="#[fg=${icon_fg},bg=${icon_bg}]${icon} "
        # Internal separator between icon and content
        if [[ "$side" == "left" ]]; then
            # Right-pointing (▶): fg=source (icon), bg=destination (content)
            segment+="#[fg=${icon_bg},bg=${content_bg}]${sep_internal}#[none]"
        else
            # Left-pointing (◀): fg=destination (content), bg=source (icon)
            segment+="#[fg=${content_bg},bg=${icon_bg}]${sep_internal}#[none]"
        fi
    fi

    # Content section - bold when:
    # - health is NOT ok (info, warning, error)
    # - OR state is inactive (disabled)
    local text_style=""
    if [[ "${health:-ok}" != "ok" || "${state:-active}" == "inactive" ]]; then
        text_style=",bold"
    fi
    segment+="#[fg=${content_fg},bg=${content_bg}${text_style}] ${content} "

    printf '%s' "$segment"
}

# =============================================================================
# Plugin Group Parsing
# =============================================================================

# Parse plugin list and extract groups
# Populates global arrays:
#   _PARSED_PLUGINS[]     - Plugin names in order
#   _PLUGIN_GROUP_ID[]    - Group ID for each plugin (0 = no group)
#   _GROUP_COLORS[]       - Resolved colors for each group ID
# Usage: _parse_plugin_list "plugins_str"
_parse_plugin_list() {
    local plugins_str="$1"

    _PARSED_PLUGINS=()
    _PLUGIN_GROUP_ID=()
    _GROUP_COLORS=()

    # Get group color palette
    local group_colors_str
    group_colors_str=$(get_tmux_option "@powerkit_plugin_group_colors" "${POWERKIT_DEFAULT_PLUGIN_GROUP_COLORS}")
    local -a color_palette
    IFS=',' read -ra color_palette <<< "$group_colors_str"

    local group_counter=0
    local current_pos=0
    local len=${#plugins_str}

    while [[ $current_pos -lt $len ]]; do
        # Skip whitespace
        while [[ $current_pos -lt $len && "${plugins_str:$current_pos:1}" =~ [[:space:]] ]]; do
            ((current_pos++))
        done
        [[ $current_pos -ge $len ]] && break

        # Check for group(...) syntax
        if [[ "${plugins_str:$current_pos:6}" == "group(" ]]; then
            ((group_counter++))
            current_pos=$((current_pos + 6))

            # Assign color from palette (cycle if more groups than colors)
            local color_idx=$(( (group_counter - 1) % ${#color_palette[@]} ))
            _GROUP_COLORS[$group_counter]=$(resolve_color "${color_palette[$color_idx]}")

            # Find matching closing parenthesis
            local paren_depth=1
            local group_start=$current_pos
            while [[ $current_pos -lt $len && $paren_depth -gt 0 ]]; do
                local char="${plugins_str:$current_pos:1}"
                [[ "$char" == "(" ]] && ((paren_depth++))
                [[ "$char" == ")" ]] && ((paren_depth--))
                [[ $paren_depth -gt 0 ]] && ((current_pos++))
            done

            # Extract group content (plugins inside group())
            local group_content="${plugins_str:$group_start:$((current_pos - group_start))}"
            ((current_pos++))  # Skip closing )

            # Parse plugins inside group
            local -a group_plugins
            IFS=',' read -ra group_plugins <<< "$group_content"
            for plugin in "${group_plugins[@]}"; do
                # Trim whitespace (uses nameref - zero subshells)
                trim_inplace plugin
                [[ -n "$plugin" ]] && {
                    _PARSED_PLUGINS+=("$plugin")
                    _PLUGIN_GROUP_ID+=("$group_counter")
                }
            done
        # Check for external(...) syntax
        elif [[ "${plugins_str:$current_pos:9}" == "external(" ]]; then
            local ext_start=$current_pos
            current_pos=$((current_pos + 9))

            # Find matching closing parenthesis
            local paren_depth=1
            while [[ $current_pos -lt $len && $paren_depth -gt 0 ]]; do
                local char="${plugins_str:$current_pos:1}"
                [[ "$char" == "(" ]] && ((paren_depth++))
                [[ "$char" == ")" ]] && ((paren_depth--))
                ((current_pos++))
            done

            local ext_plugin="${plugins_str:$ext_start:$((current_pos - ext_start))}"
            _PARSED_PLUGINS+=("$ext_plugin")
            _PLUGIN_GROUP_ID+=("0")
        else
            # Regular plugin name - find end (comma or end of string)
            local name_start=$current_pos
            while [[ $current_pos -lt $len && "${plugins_str:$current_pos:1}" != "," ]]; do
                ((current_pos++))
            done

            local plugin="${plugins_str:$name_start:$((current_pos - name_start))}"
            # Trim whitespace (uses nameref - zero subshells)
            trim_inplace plugin
            [[ -n "$plugin" ]] && {
                _PARSED_PLUGINS+=("$plugin")
                _PLUGIN_GROUP_ID+=("0")
            }
        fi

        # Skip comma separator
        if [[ $current_pos -lt $len && "${plugins_str:$current_pos:1}" == "," ]]; then
            ((current_pos++))
        fi
    done
}

# =============================================================================
# Render Helpers
# =============================================================================

# Check if plugin should be hidden by threshold filter
# Usage: _is_hidden_by_threshold "plugin_name" "health"
# Returns: 0 if hidden, 1 if visible
_is_hidden_by_threshold() {
    local plugin_name="$1"
    local health="$2"

    local show_only_on_threshold
    show_only_on_threshold=$(get_named_plugin_option "$plugin_name" "show_only_on_threshold" 2>/dev/null || echo "false")

    [[ "$show_only_on_threshold" != "true" ]] && return 1

    local health_level
    health_level=$(get_health_level "$health")
    log_debug "segment_builder" "plugin=$plugin_name show_only_on_threshold=$show_only_on_threshold health=$health health_level=$health_level"

    if [[ "$health_level" -lt 1 ]]; then
        log_debug "segment_builder" "plugin=$plugin_name hidden by show_only_on_threshold (health_level=$health_level)"
        return 0
    fi

    return 1
}

# Build spacing separator between plugins
# Usage: _build_spacing_separator "side" "prev_bg" "spacing_bg" "spacing_fg"
# Outputs: tmux format string for spacing separator
_build_spacing_separator() {
    local side="$1"
    local prev_bg="$2"
    local spacing_bg="$3"
    local spacing_fg="$4"

    local spacing_sep
    spacing_sep=$(get_closing_separator_for_side "$side")

    if [[ "$side" == "left" ]]; then
        printf ' #[fg=%s,bg=%s]%s#[bg=%s]#[none]' "$prev_bg" "$spacing_bg" "$spacing_sep" "$spacing_bg"
    else
        printf ' #[fg=%s,bg=%s]%s#[bg=%s]#[none]' "$spacing_fg" "$prev_bg" "$spacing_sep" "$spacing_bg"
    fi
}

# Resolve colors for plugin (external or regular)
# Usage: _resolve_plugin_colors "is_external" "state" "health" "stale" "accent" "accent_icon"
# Outputs: "content_bg content_fg icon_bg icon_fg" (space-separated)
_resolve_plugin_colors() {
    local is_external="$1"
    local state="$2"
    local health="$3"
    local stale="$4"
    local accent="$5"
    local accent_icon="$6"

    if [[ "$is_external" == "1" && -n "$accent" ]]; then
        # External plugin: use specified accent colors
        local content_bg content_fg icon_bg icon_fg
        content_bg=$(resolve_color "${accent:-ok-base}")
        icon_bg=$(resolve_color "${accent_icon:-${accent:-ok-base}-lighter}")
        content_fg=$(resolve_color "${accent:-ok-base}-darkest")
        icon_fg=$(resolve_color "${accent_icon:-${accent:-ok-base}}-darkest")
        printf '%s %s %s %s' "$content_bg" "$content_fg" "$icon_bg" "$icon_fg"
    else
        # Regular plugin: resolve via state/health
        resolve_plugin_colors_full "$state" "$health" "" "$stale"
    fi
}

# =============================================================================
# Plugin List Rendering (main entry point for powerkit-render)
# =============================================================================

# Render all plugins from the plugin list
# This is the main function that orchestrates plugin rendering
# Usage: render_plugins ["side"]
# - side: "left" or "right" (default: "right")
#   - "left": plugins on left side of bar → RIGHT-pointing separators (▶)
#   - "right": plugins on right side of bar → LEFT-pointing separators (◀)
# Returns: complete formatted string for status bar
render_plugins() {
    local side="${1:-right}"

    # Source lifecycle for data collection
    . "${POWERKIT_ROOT}/src/core/lifecycle.sh"

    # Pre-populate separator cache (avoids subshell loss in loops)
    separator_ensure_cache

    # Determine status bar background
    local status_bg
    status_bg=$(resolve_background)

    local transparent
    transparent=$(get_tmux_option "@powerkit_transparent" "${POWERKIT_DEFAULT_TRANSPARENT}")
    [[ "$transparent" == "true" ]] && status_bg="default"

    # Get plugin list
    local plugins_str
    plugins_str=$(get_tmux_option "@powerkit_plugins" "${POWERKIT_DEFAULT_PLUGINS}")
    [[ -z "$plugins_str" ]] && return 0

    # Parse plugin list with group support
    _parse_plugin_list "$plugins_str"
    local -a plugin_names=("${_PARSED_PLUGINS[@]}")

    # Check if plugin spacing is enabled
    local use_spacing
    use_spacing=$(has_plugin_spacing && echo "true" || echo "false")

    # Spacing colors for plugin separators
    # In transparent mode: use theme's "background" (terminal background)
    # In normal mode: use statusbar-bg
    local spacing_bg spacing_fg
    if [[ "$transparent" == "true" ]]; then
        spacing_bg="default"
        spacing_fg=$(resolve_color "background")
    else
        local resolved_statusbar_bg
        resolved_statusbar_bg=$(resolve_color "statusbar-bg")
        spacing_bg="$resolved_statusbar_bg"
        spacing_fg="$resolved_statusbar_bg"
    fi

    # First pass: collect visible plugins to know total count (for is_last detection)
    local visible_plugins=()
    local visible_data=()
    local visible_is_external=()
    local visible_group_id=()
    local plugin_name
    local plugin_idx=0
    for plugin_name in "${plugin_names[@]}"; do
        local current_group_id="${_PLUGIN_GROUP_ID[$plugin_idx]:-0}"
        ((plugin_idx++))

        # Trim whitespace (uses nameref - zero subshells)
        trim_inplace plugin_name
        [[ -z "$plugin_name" ]] && continue

        local plugin_data=""
        local is_external=0

        # Handle external plugins
        if [[ "$plugin_name" == external\(* ]]; then
            is_external=1
            # Generate a hash-like ID from the spec for caching (pure bash, no subshells)
            local ext_id
            ext_id=$(string_hash "$plugin_name")
            plugin_data=$(collect_external_plugin_render_data "$ext_id" "$plugin_name") || continue
            [[ -z "$plugin_data" ]] && continue
        else
            # Regular plugin - collect via lifecycle
            plugin_data=$(collect_plugin_render_data "$plugin_name") || continue
            [[ -z "$plugin_data" ]] && continue
            [[ "$plugin_data" == "HIDDEN" ]] && continue
        fi

        # Parse data: icon|content|state|health|stale (5 fields from lifecycle)
        # External plugins have 2 extra fields: accent|accent_icon
        local icon content state health stale
        IFS=$'\x1f' read -r icon content state health stale _ _ <<< "$plugin_data"
        stale="${stale:-0}"  # Default for backward compatibility

        # Apply threshold filter (skip for external plugins)
        [[ $is_external -eq 0 ]] && _is_hidden_by_threshold "$plugin_name" "$health" && continue

        visible_plugins+=("$plugin_name")
        visible_data+=("$plugin_data")
        visible_is_external+=("$is_external")
        visible_group_id+=("$current_group_id")
    done

    local total_plugins=${#visible_plugins[@]}
    [[ $total_plugins -eq 0 ]] && return 0

    # Second pass: render plugins
    local output=""
    local prev_bg="$status_bg"
    local render_idx=0
    local prev_group_id=0

    # NOTE: Entry edge separator for CENTER side is handled by render_plugin_segment
    # for the first plugin (is_first=1) via get_initial_separator().
    # We don't add it here to avoid duplication.

    for plugin_name in "${visible_plugins[@]}"; do
        local plugin_data="${visible_data[$render_idx]}"
        local is_external="${visible_is_external[$render_idx]}"
        local current_group_id="${visible_group_id[$render_idx]}"
        local icon content state health stale accent accent_icon
        IFS=$'\x1f' read -r icon content state health stale accent accent_icon <<< "$plugin_data"
        stale="${stale:-0}"  # Default for backward compatibility

        local is_first=$(( render_idx == 0 ? 1 : 0 ))
        local is_last=$(( render_idx == total_plugins - 1 ? 1 : 0 ))

        # Determine spacing/separator behavior based on groups
        # - Same group (non-zero): use group color as separator background (no gap)
        # - Different groups: use statusbar background (creates visual gap)
        local current_spacing_bg="$spacing_bg"
        local current_spacing_fg="$spacing_fg"
        local same_group=0

        if [[ $current_group_id -gt 0 && $current_group_id -eq $prev_group_id ]]; then
            # Same group: use group color for continuous background
            same_group=1
            current_spacing_bg="${_GROUP_COLORS[$current_group_id]}"
            current_spacing_fg="${_GROUP_COLORS[$current_group_id]}"
        fi

        # Add spacing between plugins if enabled (not before first plugin)
        # Skip spacing for plugins in the same group (they appear connected)
        if [[ "$use_spacing" == "true" && $is_first -eq 0 && $same_group -eq 0 ]]; then
            local spacing_sep
            spacing_sep=$(get_closing_separator_for_side "$side")

            # spacing_fg is defined at the top with the actual statusbar-bg color
            # (not "default" which gives terminal's white text color)
            if [[ "$side" == "left" ]]; then
                output+=" #[fg=${prev_bg},bg=${current_spacing_bg}]${spacing_sep}#[bg=${current_spacing_bg}]#[none]"
            else
                output+=" #[fg=${current_spacing_fg},bg=${prev_bg}]${spacing_sep}#[bg=${current_spacing_bg}]#[none]"
            fi
            prev_bg="$current_spacing_bg"
        # For same group without global spacing, still need to update prev_bg context
        elif [[ $same_group -eq 1 && $is_first -eq 0 ]]; then
            # Plugins in same group connect directly without gap
            # prev_bg already set from previous plugin's content_bg
            :
        fi

        prev_group_id="$current_group_id"

        # Resolve colors (RENDERER responsibility - per contract separation)
        local content_bg content_fg icon_bg icon_fg
        read -r content_bg content_fg icon_bg icon_fg <<< "$(_resolve_plugin_colors "$is_external" "$state" "$health" "$stale" "$accent" "$accent_icon")"

        # Render segment (pass is_first, is_last and side for correct separator styling)
        local segment
        segment=$(render_plugin_segment "$icon" "$content" "$state" "$health" "$icon_bg" "$icon_fg" "$content_bg" "$content_fg" "$prev_bg" "$is_first" "$is_last" "$side")

        output+="$segment"
        prev_bg="$content_bg"
        ((render_idx++))
    done

    # Add closing edge separator after last plugin
    # Exit edge always uses right-pointing (▶) to create ")" closing cap
    # ▶: fg=plugin content (fills shape), bg=statusbar (outside)
    if [[ $total_plugins -gt 0 ]]; then
        if [[ "$side" == "left" || "$side" == "center" ]]; then
            local edge_sep
            edge_sep=$(_get_separator_glyph "$(get_edge_separator_style)" "right")
            output+="#[fg=${prev_bg},bg=${status_bg}]${edge_sep}#[none]"
        elif [[ "$side" == "right" ]] && should_apply_all_edges; then
            local edge_sep
            edge_sep=$(_get_separator_glyph "$(get_edge_separator_style)" "right")
            output+="#[fg=${prev_bg},bg=${status_bg}]${edge_sep}#[none]"
        fi
    fi

    # After all plugins processed, show popup for any missing binaries
    if declare -F binary_prompt_missing &>/dev/null; then
        binary_prompt_missing
    fi

    printf '%s' "$output"
}

# =============================================================================
# External Plugin Segment
# =============================================================================

# Build segment for external plugin
# Usage: build_external_segment "icon" "content" "accent" "accent_icon" "prev_bg" "next_bg"
build_external_segment() {
    local icon="$1"
    local content="$2"
    local accent="${3:-ok-bg}"
    local accent_icon="${4:-ok-icon-bg}"
    local prev_bg="${5:-default}"
    local next_bg="${6:-default}"

    local content_bg content_fg icon_bg icon_fg

    content_bg=$(resolve_color "$accent")
    icon_bg=$(resolve_color "$accent_icon")
    # Use the appropriate fg color for the accent
    content_fg=$(resolve_color "${accent//-bg/-fg}" 2>/dev/null || resolve_color "ok-fg")
    icon_fg=$(resolve_color "${accent_icon//-bg/-fg}" 2>/dev/null || resolve_color "ok-fg")

    build_segment "$icon" "$content" "$icon_bg" "$icon_fg" "$content_bg" "$content_fg" "$prev_bg" "$next_bg"
}
