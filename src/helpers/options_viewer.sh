#!/usr/bin/env bash
# =============================================================================
# Helper: options_viewer
# Description: Display all available PowerKit options with defaults and values
# Type: popup
# =============================================================================

# Source helper base (handles all initialization)
. "$(dirname "${BASH_SOURCE[0]}")/../contract/helper_contract.sh"
helper_init --no-strict

# =============================================================================
# Metadata
# =============================================================================

helper_get_metadata() {
    helper_metadata_set "id" "options_viewer"
    helper_metadata_set "name" "Options Viewer"
    helper_metadata_set "description" "View and search all PowerKit options"
    helper_metadata_set "type" "popup"
}

helper_get_actions() {
    echo "view [filter] - View PowerKit options (default)"
    echo "all [filter] - Include other TPM plugins (slower)"
}

# =============================================================================
# Constants
# =============================================================================

# ANSI colors from defaults.sh
BOLD="${POWERKIT_ANSI_BOLD}"
DIM="${POWERKIT_ANSI_DIM}"
CYAN="${POWERKIT_ANSI_CYAN}"
GREEN="${POWERKIT_ANSI_GREEN}"
YELLOW="${POWERKIT_ANSI_YELLOW}"
MAGENTA="${POWERKIT_ANSI_MAGENTA}"
BLUE="${POWERKIT_ANSI_BLUE}"
RESET="${POWERKIT_ANSI_RESET}"

TPM_PLUGINS_DIR="${TMUX_PLUGIN_MANAGER_PATH:-$HOME/.tmux/plugins}"
[[ ! -d "$TPM_PLUGINS_DIR" && -d "$HOME/.config/tmux/plugins" ]] && TPM_PLUGINS_DIR="$HOME/.config/tmux/plugins"

declare -a THEME_OPTIONS=(
    # Theme
    "@powerkit_theme|tokyo-night|theme name|Theme name"
    "@powerkit_theme_variant|night|variant name|Theme variant"
    "@powerkit_transparent|false|true,false|Transparent status bar"
    "@powerkit_custom_theme_path||(path)|Custom theme file path"
    # Plugins
    "@powerkit_plugins|datetime,battery,cpu,memory,hostname,git|(comma-separated)|Enabled plugins"
    # Status Bar
    "@powerkit_status_interval|5|(integer)|Refresh interval (seconds)"
    "@powerkit_status_position|top|top,bottom|Status bar position"
    "@powerkit_status_justify|left|left,centre,right|Window list alignment"
    "@powerkit_bar_layout|single|single,double|Status bar layout"
    "@powerkit_status_order|session,plugins|session,plugins or plugins,session|Element order"
    # Separators
    "@powerkit_separator_style|normal|normal,rounded,flame,pixel,honeycomb,none|Separator style"
    "@powerkit_edge_separator_style|rounded|normal,rounded,flame,pixel,honeycomb,none|Edge separator style"
    "@powerkit_initial_separator_style||(style)|Initial separator style"
    "@powerkit_elements_spacing|false|false,true,both,windows,plugins|Spacing between elements"
    # Session
    "@powerkit_session_icon|auto|auto,icon|Session icon"
    "@powerkit_session_prefix_icon||icon|Prefix mode icon"
    "@powerkit_session_copy_icon||icon|Copy mode icon"
    "@powerkit_session_command_icon||icon|Command mode icon"
    "@powerkit_session_search_icon||icon|Search mode icon"
    "@powerkit_session_normal_color|session-bg|color|Normal session color"
    "@powerkit_session_prefix_color|session-prefix-bg|color|Prefix mode color"
    "@powerkit_session_copy_mode_color|session-copy-bg|color|Copy mode color"
    # Window
    "@powerkit_active_window_icon||icon|Active window icon"
    "@powerkit_inactive_window_icon||icon|Inactive window icon"
    "@powerkit_zoomed_window_icon||icon|Zoomed pane indicator"
    "@powerkit_pane_synchronized_icon||icon|Synchronized panes indicator"
    "@powerkit_window_default_icon||icon|Default window icon"
    "@powerkit_active_window_title|#W|tmux format|Active window title format"
    "@powerkit_inactive_window_title|#W|tmux format|Inactive window title format"
    "@powerkit_window_index_style|text|text,numeric,box,box_outline,box_multiple,box_multiple_outline,circle,circle_outline|Window index display style"
    # Pane
    "@powerkit_pane_border_lines|single|single,double,heavy,simple,number|Pane border style"
    "@powerkit_active_pane_border_color|pane-border-active|color|Active pane border color"
    "@powerkit_inactive_pane_border_color|pane-border-inactive|color|Inactive pane border color"
    "@powerkit_pane_border_status|off|off,top,bottom|Pane border status position"
    "@powerkit_pane_border_format|{index}: {title}|string|Pane border format ({index},{title},{command},{path})"
    # Clock
    "@powerkit_clock_style|24|12,24|Clock format"
    # Keybindings
    "@powerkit_show_options_key|C-e|key|Options viewer keybinding"
    "@powerkit_show_options_width|80%|percentage|Options popup width"
    "@powerkit_show_options_height|80%|percentage|Options popup height"
    "@powerkit_show_keybindings_key|C-y|key|Keybindings viewer keybinding"
    "@powerkit_show_keybindings_width|80%|percentage|Keybindings popup width"
    "@powerkit_show_keybindings_height|80%|percentage|Keybindings popup height"
    "@powerkit_theme_selector_key|C-r|key|Theme selector keybinding"
    "@powerkit_cache_clear_key|M-x|key|Cache clear keybinding"
    "@powerkit_log_viewer_key|M-l|key|Log viewer keybinding"
    "@powerkit_log_viewer_width|90%|percentage|Log viewer popup width"
    "@powerkit_log_viewer_height|80%|percentage|Log viewer popup height"
    "@powerkit_keybinding_conflict_action|warn|warn,skip,ignore|Keybinding conflict handling"
    # Advanced
    "@powerkit_debug|false|true,false|Enable debug logging"
    "@powerkit_ui_backend|auto|auto,gum,fzf,basic|UI backend"
    "@powerkit_segment_template||(template)|Custom segment template"
)

# =============================================================================
# Display Functions
# =============================================================================

_print_header() {
    echo -e "\n${BOLD}${CYAN}--------------------------------------------------------------------${RESET}"
    echo -e "${BOLD}${CYAN}  PowerKit Options Reference${RESET}"
    echo -e "${BOLD}${CYAN}--------------------------------------------------------------------${RESET}"
    echo -e "${DIM}  Plugins directory: ${TPM_PLUGINS_DIR}${RESET}\n"
}

_print_section() {
    echo -e "\n${BOLD}${2:-$MAGENTA}> ${1}${RESET}\n${DIM}--------------------------------------------------------------------${RESET}"
}

# Get default value for a plugin option from defaults.sh
_get_plugin_default_value() {
    local option="$1"
    # Convert @powerkit_plugin_xxx to POWERKIT_PLUGIN_XXX
    local var_name="${option#@}"
    var_name="${var_name^^}"
    printf '%s' "${!var_name:-}"
}

# Get description for a plugin option based on its name
_get_plugin_option_description() {
    local option="$1"
    local suffix="${option##*_}"
    case "$suffix" in
        icon|icon_*) echo "Icon/emoji" ;;
        color) echo "Color name" ;;
        format) echo "Display format" ;;
        threshold) echo "Threshold value" ;;
        ttl) echo "Cache time-to-live (seconds)" ;;
        key) echo "Keybinding" ;;
        width|height) echo "Popup dimension" ;;
        length) echo "Max length" ;;
        separator) echo "Text separator" ;;
        *) echo "Plugin option" ;;
    esac
}

_print_option() {
    local option="$1" default="$2" possible="$3" description="$4"
    local current=""

    # For plugin options, get metadata from cache (fast - no tmux calls)
    if [[ "$option" == @powerkit_plugin_* ]]; then
        local metadata
        metadata=$(_get_option_metadata "$option")
        if [[ -n "$metadata" ]]; then
            local meta_type meta_default meta_desc
            IFS='|' read -r meta_type meta_default meta_desc <<< "$metadata"
            [[ -z "$default" ]] && default="$meta_default"
            [[ -z "$description" || "$description" == "Plugin option" ]] && description="$meta_desc"
            [[ -z "$possible" && -n "$meta_type" ]] && possible="($meta_type)"
        fi
        # Check pre-loaded tmux cache for user-customized value (no tmux call)
        current="${_TMUX_OPTIONS_CACHE[$option]:-}"
    else
        # For non-plugin options (theme options), use get_tmux_option
        current=$(get_tmux_option "$option" "")
    fi

    # If still no default for plugin options, try defaults.sh
    if [[ -z "$default" && "$option" == @powerkit_plugin_* ]]; then
        default=$(_get_plugin_default_value "$option")
    fi

    # If still no description, generate one based on option name
    if [[ -z "$description" || "$description" == "Plugin option" ]] && [[ "$option" == @powerkit_plugin_* ]]; then
        description=$(_get_plugin_option_description "$option")
    fi

    printf "${GREEN}%-45s${RESET}" "$option"
    if [[ -n "$current" && "$current" != "$default" ]]; then
        echo -e " ${YELLOW}= $current${RESET} ${DIM}(default: ${default:-<empty>})${RESET}"
    elif [[ -n "$default" ]]; then
        echo -e " ${DIM}= $default${RESET}"
    else
        echo -e " ${DIM}(not set)${RESET}"
    fi
    [[ -n "$description" ]] && echo -e "  ${DIM}> $description${RESET}"
    [[ -n "$possible" ]] && echo -e "  ${DIM}  Values: $possible${RESET}"
}

_print_tpm_option() {
    local option="$1"
    # Use pre-loaded cache instead of calling tmux for each option
    local current="${_TMUX_OPTIONS_CACHE[$option]:-}"
    printf "${GREEN}%-45s${RESET}" "$option"
    [[ -n "$current" ]] && echo -e " ${YELLOW}= $current${RESET}" || echo -e " ${DIM}(not set)${RESET}"
}

# Cache for option metadata
declare -gA _OPTION_METADATA_CACHE=()
declare -g _OPTIONS_LOADED=0

# Fast option discovery using grep + bash parsing (no subshells)
_load_all_plugin_options() {
    [[ "$_OPTIONS_LOADED" -eq 1 ]] && return 0

    local plugin_file plugin_name line

    for plugin_file in "${POWERKIT_ROOT}/src/plugins"/*.sh; do
        [[ ! -f "$plugin_file" ]] && continue
        plugin_name=$(basename "$plugin_file" .sh)

        # Fast grep to extract declare_option lines, then parse with bash
        while IFS= read -r line; do
            # Parse: declare_option "name" "type" "default" "description"
            local opt_name="" opt_type="" opt_default="" opt_desc=""

            # Extract name (first quoted string after declare_option)
            if [[ "$line" =~ declare_option[[:space:]]+\"([^\"]+)\" ]]; then
                opt_name="${BASH_REMATCH[1]}"
                line="${line#*\"$opt_name\"}"

                # Extract type (next quoted string)
                if [[ "$line" =~ ^[[:space:]]*\"([^\"]+)\" ]]; then
                    opt_type="${BASH_REMATCH[1]}"
                    line="${line#*\"$opt_type\"}"

                    # Extract default - handle $'...' or "..."
                    if [[ "$line" =~ ^[[:space:]]*\$\' ]]; then
                        opt_default="(icon)"
                        line="${line#*\'}"
                        line="${line#*\'}"
                    elif [[ "$line" =~ ^[[:space:]]*\"([^\"]*)\" ]]; then
                        opt_default="${BASH_REMATCH[1]}"
                        line="${line#*\"$opt_default\"}"
                    fi

                    # Extract description (remaining quoted string)
                    if [[ "$line" =~ \"([^\"]+)\" ]]; then
                        opt_desc="${BASH_REMATCH[1]}"
                    fi
                fi

                [[ -n "$opt_name" ]] && {
                    local full_opt="@powerkit_plugin_${plugin_name}_${opt_name}"
                    _OPTION_METADATA_CACHE["$full_opt"]="${opt_type}|${opt_default}|${opt_desc}"
                }
            fi
        done < <(grep -E '^[[:space:]]*declare_option[[:space:]]+"' "$plugin_file" 2>/dev/null)
    done

    _OPTIONS_LOADED=1
}

# Get option metadata from cache
_get_option_metadata() {
    local option="$1"
    _load_all_plugin_options
    printf '%s' "${_OPTION_METADATA_CACHE[$option]:-}"
}

_discover_plugin_options() {
    _load_all_plugin_options

    # Return all discovered option names sorted
    printf '%s\n' "${!_OPTION_METADATA_CACHE[@]}" | sort
}

_scan_tpm_plugin_options() {
    local plugin_dir="$1" plugin_name; plugin_name=$(basename "$plugin_dir")
    [[ "$plugin_name" == "tpm" || "$plugin_name" == "tmux-powerkit" ]] && return

    local -a options=()
    while IFS= read -r opt; do
        [[ "$opt" =~ [-_] ]] && [[ ${#opt} -gt 10 ]] && options+=("$opt")
    done < <(grep -rhI --include='*.sh' --include='*.tmux' -oE '@[a-z][a-z0-9_-]+' "$plugin_dir" 2>/dev/null | sort -u)

    if [[ ${#options[@]} -gt 0 ]]; then
        _print_section " ${plugin_name}" "$BLUE"
        for opt in "${options[@]}"; do _print_tpm_option "$opt"; done
    fi
}

# =============================================================================
# Main Display
# =============================================================================

_display_options() {
    local filter="${1:-}"

    # Pre-load all tmux options in one call for performance
    _batch_load_tmux_options 2>/dev/null || true

    _print_header

    echo -e "${BOLD}${CYAN}+===========================================================================+${RESET}"
    echo -e "${BOLD}${CYAN}|  PowerKit Theme Options                                                   |${RESET}"
    echo -e "${BOLD}${CYAN}+===========================================================================+${RESET}"

    _print_section "Theme Core Options" "$MAGENTA"
    for opt in "${THEME_OPTIONS[@]}"; do
        IFS='|' read -r option default possible description <<< "$opt"
        [[ -z "$filter" || "$option" == *"$filter"* || "$description" == *"$filter"* ]] && _print_option "$option" "$default" "$possible" "$description"
    done

    # Discover and group plugin options
    local discovered_options
    discovered_options=$(_discover_plugin_options)

    # Convert to array for faster iteration
    local -a options_array
    mapfile -t options_array <<< "$discovered_options"

    local -A grouped_options=()
    for option in "${options_array[@]}"; do
        [[ -z "$option" ]] && continue

        local temp plugin_name
        temp="${option#@powerkit_plugin_}"
        plugin_name="${temp%%_*}"
        grouped_options["$plugin_name"]+="$option "
    done

    for plugin_name in $(printf '%s\n' "${!grouped_options[@]}" | sort); do
        local has_visible=false display_name
        # Convert plugin name to title case with proper formatting
        display_name="${plugin_name//_/ }"
        display_name="${display_name^}"
        for option in ${grouped_options[$plugin_name]}; do
            [[ -z "$filter" || "$option" == *"$filter"* ]] && {
                [[ "$has_visible" == "false" ]] && { _print_section "Plugin: ${display_name}" "$MAGENTA"; has_visible=true; }
                _print_option "$option" "" "" "Plugin option" || true
            }
        done
    done

    # TPM plugins scan disabled by default (too slow with many plugins)
    # Run with "all" action to include: options_viewer.sh all
    if [[ "${_INCLUDE_TPM_PLUGINS:-}" == "1" ]]; then
        echo -e "\n\n${BOLD}${BLUE}+===========================================================================+${RESET}"
        echo -e "${BOLD}${BLUE}|  Other TPM Plugins Options                                                |${RESET}"
        echo -e "${BOLD}${BLUE}+===========================================================================+${RESET}"

        if [[ -d "$TPM_PLUGINS_DIR" ]]; then
            for plugin_dir in "$TPM_PLUGINS_DIR"/*/; do
                [[ -d "$plugin_dir" ]] && _scan_tpm_plugin_options "$plugin_dir" 2>/dev/null || true
            done
        fi
    fi

    echo -e "\n${DIM}Press 'q' to exit, '/' to search${RESET}\n"
}

# =============================================================================
# Main Entry Point
# =============================================================================

helper_main() {
    local action="${1:-view}"

    case "$action" in
        view|"")
            shift 2>/dev/null || true
            _display_options "${1:-}" | helper_pager
            ;;
        all)
            # Include other TPM plugins (slower)
            shift 2>/dev/null || true
            _INCLUDE_TPM_PLUGINS=1 _display_options "${1:-}" | helper_pager
            ;;
        *)
            # Treat unknown action as filter
            _display_options "$action" | helper_pager
            ;;
    esac
}

# Dispatch to handler
helper_dispatch "$@"
