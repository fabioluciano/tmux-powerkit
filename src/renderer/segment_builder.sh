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

    # Build separator glyphs
    local sep_left sep_right sep_internal
    sep_left=$(get_left_separator)
    sep_right=$(get_right_separator)
    sep_internal=$(get_right_separator)

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
    local sep_left
    sep_left=$(get_left_separator)

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

    local sep_left sep_right
    sep_left=$(get_left_separator)
    sep_right=$(get_right_separator)

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
            local sep_opening
            sep_opening=$(get_right_separator)
            # Right-pointing (▶): fg=source (prev), bg=destination (icon)
            segment+="#[fg=${prev_bg},bg=${icon_bg}]${sep_opening}#[none]"
        fi
    else
        # Right side: plugins flow right-to-left with LEFT separators (◀)
        # First plugin: edge opening separator (from statusbar)
        # Other plugins: normal left separator
        local sep_opening
        if [[ $is_first -eq 1 ]]; then
            sep_opening=$(get_initial_separator)
        else
            sep_opening=$(get_left_separator)
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

    # Parse plugin list
    local plugin_names
    IFS=',' read -ra plugin_names <<< "$plugins_str"

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
    local plugin_name
    for plugin_name in "${plugin_names[@]}"; do
        # Trim whitespace
        plugin_name="${plugin_name#"${plugin_name%%[![:space:]]*}"}"
        plugin_name="${plugin_name%"${plugin_name##*[![:space:]]}"}"
        [[ -z "$plugin_name" ]] && continue

        local plugin_data=""
        local is_external=0

        # Handle external plugins
        if [[ "$plugin_name" == external\(* ]]; then
            is_external=1
            # Generate a hash-like ID from the spec for caching
            local ext_id
            ext_id=$(printf '%s' "$plugin_name" | cksum | cut -d' ' -f1)
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

        # Use explicit plugin option accessor (no global context) - skip for external
        if [[ $is_external -eq 0 ]]; then
            local show_only_on_threshold
            show_only_on_threshold=$(get_named_plugin_option "$plugin_name" "show_only_on_threshold" 2>/dev/null || echo "false")
            local health_level=0
            health_level=$(get_health_level "$health")
            log_debug "segment_builder" "plugin=$plugin_name show_only_on_threshold=$show_only_on_threshold health=$health health_level=$health_level"
            if [[ "$show_only_on_threshold" == "true" && "$health_level" -lt 1 ]]; then
                log_debug "segment_builder" "plugin=$plugin_name ocultado pelo filtro show_only_on_threshold (health_level=$health_level)"
                continue
            fi
        fi

        visible_plugins+=("$plugin_name")
        visible_data+=("$plugin_data")
        visible_is_external+=("$is_external")
    done

    local total_plugins=${#visible_plugins[@]}
    [[ $total_plugins -eq 0 ]] && return 0

    # Second pass: render plugins
    local output=""
    local prev_bg="$status_bg"
    local plugin_idx=0

    # NOTE: Entry edge separator for CENTER side is handled by render_plugin_segment
    # for the first plugin (is_first=1) via get_initial_separator().
    # We don't add it here to avoid duplication.

    for plugin_name in "${visible_plugins[@]}"; do
        local plugin_data="${visible_data[$plugin_idx]}"
        local is_external="${visible_is_external[$plugin_idx]}"
        local icon content state health stale accent accent_icon
        IFS=$'\x1f' read -r icon content state health stale accent accent_icon <<< "$plugin_data"
        stale="${stale:-0}"  # Default for backward compatibility

        local is_first=$(( plugin_idx == 0 ? 1 : 0 ))
        local is_last=$(( plugin_idx == total_plugins - 1 ? 1 : 0 ))

        # Add spacing between plugins if enabled (not before first plugin)
        if [[ "$use_spacing" == "true" && $is_first -eq 0 ]]; then
            local spacing_sep
            spacing_sep=$(get_closing_separator_for_side "$side")

            # spacing_fg is defined at the top with the actual statusbar-bg color
            # (not "default" which gives terminal's white text color)
            if [[ "$side" == "left" ]]; then
                output+=" #[fg=${prev_bg},bg=${spacing_bg}]${spacing_sep}#[bg=${spacing_bg}]#[none]"
            else
                output+=" #[fg=${spacing_fg},bg=${prev_bg}]${spacing_sep}#[bg=${spacing_bg}]#[none]"
            fi
            prev_bg="$spacing_bg"
        fi

        # Resolve colors (RENDERER responsibility - per contract separation)
        local content_bg content_fg icon_bg icon_fg

        if [[ "$is_external" == "1" && -n "$accent" ]]; then
            # External plugin: use specified accent colors
            content_bg=$(resolve_color "${accent:-ok-base}")
            icon_bg=$(resolve_color "${accent_icon:-${accent:-ok-base}-lighter}")
            # Calculate contrasting foreground
            content_fg=$(resolve_color "${accent:-ok-base}-darkest")
            icon_fg=$(resolve_color "${accent_icon:-${accent:-ok-base}}-darkest")
        else
            # Regular plugin: resolve via state/health
            # Pass stale flag to apply -darker variant for stale data indication
            read -r content_bg content_fg icon_bg icon_fg <<< "$(resolve_plugin_colors_full "$state" "$health" "" "$stale")"
        fi

        # Render segment (pass is_first, is_last and side for correct separator styling)
        local segment
        segment=$(render_plugin_segment "$icon" "$content" "$state" "$health" "$icon_bg" "$icon_fg" "$content_bg" "$content_fg" "$prev_bg" "$is_first" "$is_last" "$side")

        output+="$segment"
        prev_bg="$content_bg"
        ((plugin_idx++))
    done

    # Add closing edge separator after last plugin when on LEFT or CENTER side
    # - LEFT: exit separator pointing right (▶)
    # - CENTER: exit separator pointing right (▶) - center handles both edges
    # - RIGHT: no exit separator (next element handles entry)
    if [[ ("$side" == "left" || "$side" == "center") && $total_plugins -gt 0 ]]; then
        local edge_sep
        edge_sep=$(_get_separator_glyph "$(get_edge_separator_style)" "right")
        # Right-pointing (▶): fg=source (last plugin content), bg=destination (statusbar)
        output+="#[fg=${prev_bg},bg=${status_bg}]${edge_sep}#[none]"
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
