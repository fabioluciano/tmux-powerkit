#!/usr/bin/env bash
# =============================================================================
# PowerKit Layout Compositor
# Description: Composes status bar layouts from independent entities
# =============================================================================
# The compositor is responsible for:
# - Reading layout configuration (@powerkit_bar_layout, @powerkit_status_order)
# - Calling entity render functions
# - Building separators BETWEEN entities (not inside them)
# - Applying the composed format to tmux
#
# The compositor does NOT know what each entity renders - it only knows
# how to position them and connect them with separators.
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "renderer_compositor" && return 0

. "${POWERKIT_ROOT}/src/core/defaults.sh"
. "${POWERKIT_ROOT}/src/core/logger.sh"
. "${POWERKIT_ROOT}/src/core/options.sh"
. "${POWERKIT_ROOT}/src/renderer/color_resolver.sh"
. "${POWERKIT_ROOT}/src/renderer/separator.sh"
. "${POWERKIT_ROOT}/src/renderer/entities/session.sh"
. "${POWERKIT_ROOT}/src/renderer/entities/windows.sh"
. "${POWERKIT_ROOT}/src/renderer/entities/plugins.sh"

# =============================================================================
# Helper Functions
# =============================================================================

# Expand order to include windows if not present
# Windows are inserted BEFORE the last entity (so last entity remains rightmost)
# Usage: _expand_order "order"
# Examples:
#   "session,plugins" → "session,windows,plugins"
#   "plugins,session" → "plugins,windows,session"
_expand_order() {
    local order="$1"

    [[ "$order" == *"windows"* ]] && { printf '%s' "$order"; return; }

    local -a parts
    IFS=',' read -ra parts <<< "$order"

    if [[ ${#parts[@]} -ge 2 ]]; then
        local last_idx=$((${#parts[@]} - 1))
        local new_order=""
        for i in "${!parts[@]}"; do
            [[ -n "$new_order" ]] && new_order+=","
            if [[ $i -eq $last_idx ]]; then
                new_order+="windows,${parts[$i]}"
            else
                new_order+="${parts[$i]}"
            fi
        done
        printf '%s' "$new_order"
    else
        printf '%s,windows' "$order"
    fi
}

# Render a single entity
# Usage: _render_entity "entity" "side" ["align"]
_render_entity() {
    local entity="$1"
    local side="$2"
    local align="${3:-}"

    case "$entity" in
        windows)
            _get_windows_format "$side" "$align"
            ;;
        plugins)
            plugins_render "$side"
            ;;
        *)
            "${entity}_render" "$side"
            ;;
    esac
}

# Split entities into before/after windows
# Usage: _split_at_windows "order" "before_var" "after_var"
# Sets global arrays: _BEFORE_WINDOWS, _AFTER_WINDOWS
_split_at_windows() {
    local order="$1"

    _BEFORE_WINDOWS=()
    _AFTER_WINDOWS=()

    local -a entities
    IFS=',' read -ra entities <<< "$order"

    local found_windows=0
    for entity in "${entities[@]}"; do
        if [[ "$entity" == "windows" ]]; then
            found_windows=1
        elif [[ $found_windows -eq 0 ]]; then
            _BEFORE_WINDOWS+=("$entity")
        else
            _AFTER_WINDOWS+=("$entity")
        fi
    done
}

# Clear status-format lines 1-3
# Usage: _clear_extra_status_lines
_clear_extra_status_lines() {
    tmux set-option -g 'status-format[1]' ''
    tmux set-option -g 'status-format[2]' ''
    tmux set-option -g 'status-format[3]' ''
}

# =============================================================================
# Default Status Format (from tmux source)
# =============================================================================

# Get the default tmux status-format[0] string
# This is the exact format from tmux 3.6a source (options-table.c OPTIONS_TABLE_STATUS_FORMAT1)
# We need this because `tmux set-option -gu 'status-format[0]'` sets it to empty string,
# NOT to the default value.
#
# Modified to include edge separator between windows and status-right.
# The edge separator is stored in @_powerkit_left_edge_sep and evaluated with #{E:...}
_get_default_status_format() {
    local fmt
    fmt='#[align=left range=left #{E:status-left-style}]'
    fmt+='#[push-default]'
    fmt+='#{T;=/#{status-left-length}:status-left}'
    fmt+='#[pop-default]'
    fmt+='#[norange default]'
    fmt+='#[list=on align=#{status-justify}]'
    fmt+='#[list=left-marker]<#[list=right-marker]>#[list=on]'
    fmt+='#{W:'
    fmt+='#[range=window|#{window_index} #{E:window-status-style}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]'
    fmt+='#[push-default]'
    fmt+='#{T:window-status-format}'
    fmt+='#[pop-default]'
    fmt+='#[norange default]'
    fmt+='#{?loop_last_flag,,#{window-status-separator}}'
    fmt+=','
    fmt+='#[range=window|#{window_index} list=focus #{?#{!=:#{E:window-status-current-style},default},#{E:window-status-current-style},#{E:window-status-style}}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]'
    fmt+='#[push-default]'
    fmt+='#{T:window-status-current-format}'
    fmt+='#[pop-default]'
    fmt+='#[norange list=on default]'
    fmt+='#{?loop_last_flag,,#{window-status-separator}}'
    fmt+='}'
    # Edge separator: last element on left side → statusbar-bg
    # Uses edge style separator pointing right (▶ direction)
    # Color is conditional based on whether last window is active
    fmt+='#{E:@_powerkit_left_edge_sep}'
    fmt+='#[nolist align=right range=right #{E:status-right-style}]'
    fmt+='#[push-default]'
    fmt+='#{T;=/#{status-right-length}:status-right}'
    fmt+='#[pop-default]'
    fmt+='#[norange default]'
    printf '%s' "$fmt"
}

# Get the complete windows format for direct status-format usage (double layout)
# This includes all the complex tmux styling that #{W:...} needs
# Usage: _get_windows_format "side" ["align"]
# Arguments:
#   side  - "left" or "right" (determines separator direction)
#   align - "left", "right", or empty for #{status-justify} (default)
# Returns: Complete window list format string
_get_windows_format() {
    local side="${1:-left}"
    local align="${2:-}"
    local fmt=""

    # List mode and alignment
    # If align is specified, use it; otherwise use status-justify
    if [[ -n "$align" ]]; then
        fmt+="#[list=on align=${align}]"
    else
        fmt+='#[list=on align=#{status-justify}]'
    fi
    fmt+='#[list=left-marker]<#[list=right-marker]>#[list=on]'

    # Window iteration - inactive windows
    fmt+='#{W:'
    fmt+='#[range=window|#{window_index} #{E:window-status-style}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]'
    fmt+='#[push-default]'
    fmt+='#{T:window-status-format}'
    fmt+='#[pop-default]'
    fmt+='#[norange default]'
    fmt+='#{?loop_last_flag,,#{window-status-separator}}'
    fmt+=','

    # Active window
    fmt+='#[range=window|#{window_index} list=focus #{?#{!=:#{E:window-status-current-style},default},#{E:window-status-current-style},#{E:window-status-style}}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]'
    fmt+='#[push-default]'
    fmt+='#{T:window-status-current-format}'
    fmt+='#[pop-default]'
    fmt+='#[norange list=on default]'
    fmt+='#{?loop_last_flag,,#{window-status-separator}}'
    fmt+='}'

    printf '%s' "$fmt"
}

# Build the left edge separator (final separator on left side → statusbar)
# This is the edge separator that appears after the last window
# Usage: _build_left_edge_separator
# Returns: formatted edge separator string
_build_left_edge_separator() {
    local status_bg sep_char
    local transparent

    transparent=$(get_tmux_option "@powerkit_transparent" "${POWERKIT_DEFAULT_TRANSPARENT}")
    if [[ "$transparent" == "true" ]]; then
        status_bg="default"
    else
        status_bg=$(resolve_color "statusbar-bg")
    fi

    # Edge separator glyph (right-pointing for left side)
    sep_char=$(_get_separator_glyph "$(get_edge_separator_style)" "right")
    [[ -z "$sep_char" ]] && return

    # Get the last window background colors (active vs inactive)
    local active_bg inactive_bg
    active_bg=$(resolve_color "window-active-base")
    inactive_bg=$(resolve_color "window-inactive-base")

    # Conditional: if last window is active, use active_bg; else use inactive_bg
    # #{session_windows} gives the number of windows (== last window index for 1-based indexing)
    local last_bg
    last_bg="#{?#{==:#{active_window_index},#{session_windows}},${active_bg},${inactive_bg}}"

    # Build separator: fg=last_element_bg, bg=statusbar_bg
    printf '#[fg=%s,bg=%s]%s' "$last_bg" "$status_bg" "$sep_char"
}

# =============================================================================
# Separator Building
# =============================================================================

# Build separator between two entities
# Usage: _build_inter_entity_separator "from_entity" "to_entity" "side"
# Arguments:
#   from_entity - name of the entity we're coming from
#   to_entity   - name of the entity we're going to
#   side        - "left" or "right" (determines separator direction)
# Returns: formatted separator string
_build_inter_entity_separator() {
    local from_entity="$1"
    local to_entity="$2"
    local side="${3:-left}"

    # Get background colors from entities
    local from_bg to_bg

    # Get the "exit" background of the from_entity
    if type -t "${from_entity}_get_last_bg" &>/dev/null; then
        from_bg=$("${from_entity}_get_last_bg")
    elif type -t "${from_entity}_get_bg" &>/dev/null; then
        from_bg=$("${from_entity}_get_bg")
    else
        from_bg=$(resolve_color "statusbar-bg")
    fi

    # Get the "entry" background of the to_entity
    if type -t "${to_entity}_get_first_bg" &>/dev/null; then
        to_bg=$("${to_entity}_get_first_bg")
    elif type -t "${to_entity}_get_bg" &>/dev/null; then
        to_bg=$("${to_entity}_get_bg")
    else
        to_bg=$(resolve_color "statusbar-bg")
    fi

    # Build separator based on side
    local sep_char
    if [[ "$side" == "left" ]]; then
        # Left side of bar → RIGHT-pointing separators (▶)
        sep_char=$(get_right_separator)
        [[ -z "$sep_char" ]] && return
        printf '#[fg=%s,bg=%s]%s' "$from_bg" "$to_bg" "$sep_char"
    else
        # Right side of bar → LEFT-pointing separators (◀)
        sep_char=$(get_left_separator)
        [[ -z "$sep_char" ]] && return
        printf '#[fg=%s,bg=%s]%s' "$to_bg" "$from_bg" "$sep_char"
    fi
}

# Build edge separator (first or last entity to status bar)
# Usage: _build_edge_separator "entity" "direction" "side"
# Arguments:
#   entity    - name of the entity
#   direction - "start" (statusbar → entity) or "end" (entity → statusbar)
#   side      - "left" or "right"
_build_edge_separator() {
    local entity="$1"
    local direction="$2"
    local side="${3:-left}"

    local status_bg entity_bg sep_char
    status_bg=$(resolve_color "statusbar-bg")

    if [[ "$direction" == "start" ]]; then
        # Separator FROM statusbar TO entity
        if type -t "${entity}_get_first_bg" &>/dev/null; then
            entity_bg=$("${entity}_get_first_bg")
        else
            entity_bg=$("${entity}_get_bg" 2>/dev/null || echo "$status_bg")
        fi

        if [[ "$side" == "left" ]]; then
            sep_char=$(_get_separator_glyph "$(get_edge_separator_style)" "right")
            [[ -z "$sep_char" ]] && return
            printf '#[fg=%s,bg=%s]%s' "$status_bg" "$entity_bg" "$sep_char"
        else
            sep_char=$(_get_separator_glyph "$(get_edge_separator_style)" "left")
            [[ -z "$sep_char" ]] && return
            printf '#[fg=%s,bg=%s]%s' "$entity_bg" "$status_bg" "$sep_char"
        fi
    else
        # Separator FROM entity TO statusbar
        if type -t "${entity}_get_last_bg" &>/dev/null; then
            entity_bg=$("${entity}_get_last_bg")
        else
            entity_bg=$("${entity}_get_bg" 2>/dev/null || echo "$status_bg")
        fi

        if [[ "$side" == "left" ]]; then
            sep_char=$(_get_separator_glyph "$(get_edge_separator_style)" "right")
            [[ -z "$sep_char" ]] && return
            printf '#[fg=%s,bg=%s]%s' "$entity_bg" "$status_bg" "$sep_char"
        else
            sep_char=$(_get_separator_glyph "$(get_edge_separator_style)" "left")
            [[ -z "$sep_char" ]] && return
            printf '#[fg=%s,bg=%s]%s' "$status_bg" "$entity_bg" "$sep_char"
        fi
    fi
}

# =============================================================================
# Layout Composition
# =============================================================================

# Compose a single status line from entity order
# Usage: _compose_line "order" "line_side"
# Arguments:
#   order     - comma-separated entity names (e.g., "session,windows,plugins")
#   line_side - overall side for the line ("left" or "right")
# Returns: composed format string
_compose_line() {
    local order="$1"
    local side="${2:-left}"

    local -a entities
    IFS=',' read -ra entities <<< "$order"

    local result="" prev_entity=""

    for entity in "${entities[@]}"; do
        entity="${entity// /}"  # trim whitespace

        # Add separator BETWEEN entities (not before first)
        [[ -n "$prev_entity" ]] && result+=$(_build_inter_entity_separator "$prev_entity" "$entity" "$side")

        # Render the entity
        if type -t "${entity}_render" &>/dev/null; then
            result+=$("${entity}_render" "$side")
        else
            log_warn "compositor" "Entity '${entity}' has no render function"
        fi

        prev_entity="$entity"
    done

    printf '%s' "$result"
}

# =============================================================================
# Layout Application
# =============================================================================

# Apply single layout (all on one line using status-left/right)
# Usage: _apply_single_layout "order"
#
# Handles two cases:
# 1. Standard order (session first): session → status-left, windows → center, plugins → status-right
# 2. Inverted order (plugins first): plugins → status-left, windows+session → status-right
_apply_single_layout() {
    local order="$1"

    _split_at_windows "$order"

    # Inverted = first entity before windows is "plugins"
    local is_inverted=0
    [[ ${#_BEFORE_WINDOWS[@]} -gt 0 && "${_BEFORE_WINDOWS[0]}" == "plugins" ]] && is_inverted=1

    if [[ $is_inverted -eq 1 ]]; then
        _apply_single_inverted "$order"
    else
        _apply_single_standard "$order"
    fi
}

# Apply standard single layout (session left, windows center, plugins right)
_apply_single_standard() {
    local order="$1"

    windows_configure "left"
    _split_at_windows "$order"

    # Build status-left (entities before windows + separator to windows)
    local left_content=""
    if [[ ${#_BEFORE_WINDOWS[@]} -gt 0 ]]; then
        local left_order
        left_order=$(IFS=','; echo "${_BEFORE_WINDOWS[*]}")
        left_content=$(_compose_line "$left_order" "left")

        local last_left="${_BEFORE_WINDOWS[${#_BEFORE_WINDOWS[@]}-1]}"
        left_content+=$(_build_inter_entity_separator "$last_left" "windows" "left")
    fi

    # Build status-right (entities after windows)
    local right_content=""
    if [[ ${#_AFTER_WINDOWS[@]} -gt 0 ]]; then
        local first_right="${_AFTER_WINDOWS[0]}"

        # Plugins handle their own initial separator
        [[ "$first_right" != "plugins" ]] && \
            right_content+=$(_build_inter_entity_separator "windows" "$first_right" "right")

        local right_order
        right_order=$(IFS=','; echo "${_AFTER_WINDOWS[*]}")
        right_content+=$(_compose_line "$right_order" "right")
    fi

    # Apply to tmux
    tmux set-option -g status-left "$left_content"
    tmux set-option -g status-right "$right_content"
    tmux set-option -g status-justify "left"
    tmux set-option -g @_powerkit_left_edge_sep "$(_build_left_edge_separator)"
    tmux set-option -g 'status-format[0]' "$(_get_default_status_format)"
    _clear_extra_status_lines
    tmux set-option -g status on

    log_debug "compositor" "Single layout (standard) applied: order=$order"
}

# Apply inverted single layout (plugins left, windows+session right)
_apply_single_inverted() {
    local order="$1"

    windows_configure "right"
    _split_at_windows "$order"

    # Build left content (entities before windows + edge separator)
    local left_content=""
    if [[ ${#_BEFORE_WINDOWS[@]} -gt 0 ]]; then
        local left_order
        left_order=$(IFS=','; echo "${_BEFORE_WINDOWS[*]}")
        left_content=$(_compose_line "$left_order" "left")

        local last_left="${_BEFORE_WINDOWS[${#_BEFORE_WINDOWS[@]}-1]}"
        left_content+=$(_build_edge_separator "$last_left" "end" "left")
    fi

    # Build right content (windows + entities after, with windows+session grouping)
    local right_content=""
    local -a right_entities=("windows")
    for entity in "${_AFTER_WINDOWS[@]}"; do
        right_entities+=("$entity")
    done

    local prev_entity=""
    for entity in "${right_entities[@]}"; do
        [[ -n "$prev_entity" ]] && \
            right_content+=$(_build_inter_entity_separator "$prev_entity" "$entity" "right")
        right_content+=$(_render_entity "$entity" "right" "right")
        prev_entity="$entity"
    done

    # Build custom status-format[0]
    local fmt=""
    fmt+="#[align=left range=left #{E:status-left-style}]#[push-default]"
    fmt+="$left_content"
    fmt+="#[pop-default]#[norange default]"
    fmt+="#[nolist align=right range=right #{E:status-right-style}]#[push-default]"
    fmt+="$right_content"
    fmt+="#[pop-default]#[norange default]"

    tmux set-option -g status-left ""
    tmux set-option -g status-right ""
    tmux set-option -g 'status-format[0]' "$fmt"
    _clear_extra_status_lines
    tmux set-option -g status on

    log_debug "compositor" "Single layout (inverted) applied: order=$order"
}

# Apply double layout (two lines using status-format[0] and status-format[1])
# Usage: _apply_double_layout "order"
#
# Split point determined by first entity:
# - "plugins" first: plugins → line 0, session+windows → line 1
# - "session" first: session+windows → line 0, plugins → line 1
_apply_double_layout() {
    local order="$1"
    local status_bg
    status_bg=$(resolve_color "statusbar-bg")

    local -a entities
    IFS=',' read -ra entities <<< "$order"

    # Split entities into line0 and line1
    local first_entity="${entities[0]}"
    local -a line0_entities=() line1_entities=()

    for entity in "${entities[@]}"; do
        if [[ "$first_entity" == "plugins" ]]; then
            [[ "$entity" == "plugins" ]] && line0_entities+=("$entity") || line1_entities+=("$entity")
        else
            [[ "$entity" == "session" || "$entity" == "windows" ]] && line0_entities+=("$entity") || line1_entities+=("$entity")
        fi
    done

    # Determine windows side (line0=left, line1=right)
    local windows_side="right"
    for entity in "${line0_entities[@]}"; do
        [[ "$entity" == "windows" ]] && windows_side="left"
    done
    windows_configure "$windows_side"

    # Build line 0 (left-aligned)
    local line0_content=""
    line0_content=$(_build_line_content line0_entities "left")

    # Build line 1 (right-aligned)
    local line1_content=""
    if [[ ${#line1_entities[@]} -gt 0 ]]; then
        line1_content="#[bg=${status_bg}]#[align=right]"
        line1_content+=$(_build_line_content line1_entities "right")
    fi

    # Apply to tmux
    tmux set-option -g 'status-format[0]' "$line0_content"
    tmux set-option -g 'status-format[1]' "$line1_content"
    tmux set-option -g 'status-format[2]' ''
    tmux set-option -g 'status-format[3]' ''
    tmux set-option -g status-left ""
    tmux set-option -g status-right ""
    tmux set-option -g status 2

    log_debug "compositor" "Double layout applied: order=$order"
}

# Build content for a status line from entity array
# Usage: _build_line_content array_name side
_build_line_content() {
    local -n entities_ref=$1
    local side="$2"

    [[ ${#entities_ref[@]} -eq 0 ]] && return

    # Reorder if right-side with session (session must be last/rightmost)
    local -a ordered=()
    if [[ "$side" == "right" ]]; then
        local session_entity=""
        for entity in "${entities_ref[@]}"; do
            [[ "$entity" == "session" ]] && session_entity="$entity" || ordered+=("$entity")
        done
        [[ -n "$session_entity" ]] && ordered+=("$session_entity")
    else
        ordered=("${entities_ref[@]}")
    fi

    local content="" prev_entity="" last_entity=""
    for entity in "${ordered[@]}"; do
        [[ -n "$prev_entity" ]] && content+=$(_build_inter_entity_separator "$prev_entity" "$entity" "$side")
        content+=$(_render_entity "$entity" "$side" "$side")
        prev_entity="$entity"
        last_entity="$entity"
    done

    # Add edge separator at end (only for left-aligned line 0)
    if [[ "$side" == "left" && -n "$last_entity" ]]; then
        case "$last_entity" in
            windows) content+=$(_build_left_edge_separator) ;;
            plugins) ;; # Plugins add their own
            *) content+=$(_build_edge_separator "$last_entity" "end" "left") ;;
        esac
    fi

    printf '%s' "$content"
}

# =============================================================================
# Public API
# =============================================================================

# Compose and apply the status bar layout
# Reads configuration and applies the appropriate layout
# Usage: compose_layout
compose_layout() {
    log_debug "compositor" "Composing layout"

    local bar_layout order
    bar_layout=$(get_tmux_option "@powerkit_bar_layout" "${POWERKIT_DEFAULT_BAR_LAYOUT}")
    order=$(get_tmux_option "@powerkit_status_order" "${POWERKIT_DEFAULT_STATUS_ORDER}")
    order=$(_expand_order "$order")

    log_debug "compositor" "Layout: $bar_layout, Order: $order"

    if [[ "$bar_layout" == "double" ]]; then
        _apply_double_layout "$order"
    else
        _apply_single_layout "$order"
    fi

    log_debug "compositor" "Layout composition complete"
}

# Get the current entity order (expanded to include windows)
# Usage: get_entity_order
get_entity_order() {
    local order
    order=$(get_tmux_option "@powerkit_status_order" "${POWERKIT_DEFAULT_STATUS_ORDER}")
    _expand_order "$order"
}

# Check if using custom order (non-default)
# Usage: is_custom_order
is_custom_order() {
    local order
    order=$(get_tmux_option "@powerkit_status_order" "${POWERKIT_DEFAULT_STATUS_ORDER}")
    [[ "$order" != "${POWERKIT_DEFAULT_STATUS_ORDER}" ]]
}
