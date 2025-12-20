#!/usr/bin/env bash
# Helper: options_viewer - Display all available theme options with defaults and current values

set -eu

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$CURRENT_DIR/.."

# Source common dependencies
# shellcheck source=src/helper_bootstrap.sh
. "$ROOT_DIR/helper_bootstrap.sh"

# =============================================================================
# Constants
# =============================================================================

# ANSI colors (from defaults.sh via helper_bootstrap, with fallbacks)
BOLD="${POWERKIT_ANSI_BOLD:-\033[1m}"
DIM="${POWERKIT_ANSI_DIM:-\033[2m}"
CYAN="${POWERKIT_ANSI_CYAN:-\033[36m}"
GREEN="${POWERKIT_ANSI_GREEN:-\033[32m}"
YELLOW="${POWERKIT_ANSI_YELLOW:-\033[33m}"
MAGENTA="${POWERKIT_ANSI_MAGENTA:-\033[35m}"
BLUE="${POWERKIT_ANSI_BLUE:-\033[34m}"
RESET="${POWERKIT_ANSI_RESET:-\033[0m}"

TPM_PLUGINS_DIR="${TMUX_PLUGIN_MANAGER_PATH:-$HOME/.tmux/plugins}"
[[ ! -d "$TPM_PLUGINS_DIR" && -d "$HOME/.config/tmux/plugins" ]] && TPM_PLUGINS_DIR="$HOME/.config/tmux/plugins"

declare -a THEME_OPTIONS=(
    "@powerkit_variation|night|night|Color scheme variation"
    "@powerkit_plugins|datetime,weather|(comma-separated)|Enabled plugins"
    "@powerkit_disable_plugins|0|0,1|Disable all plugins"
    "@powerkit_transparent|false|true,false|Transparent status bar"
    "@powerkit_bar_layout|single|single,double|Status bar layout"
    "@powerkit_status_left_length|100|(integer)|Maximum left status length"
    "@powerkit_status_right_length|250|(integer)|Maximum right status length"
    "@powerkit_separator_style|rounded|rounded,normal|Separator style (pill or arrows)"
    "@powerkit_left_separator||Powerline|Left separator"
    "@powerkit_right_separator||Powerline|Right separator"
    "@powerkit_session_icon| |Icon/emoji|Session icon"
    "@powerkit_active_window_title|#W |tmux format|Active window title format"
    "@powerkit_inactive_window_title|#W |tmux format|Inactive window title format"
)

# =============================================================================
# Display Functions
# =============================================================================

print_header() {
    echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${CYAN}  🌃 tmux Options Reference${RESET}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${DIM}  Plugins directory: ${TPM_PLUGINS_DIR}${RESET}\n"
}

print_section() {
    echo -e "\n${BOLD}${2:-$MAGENTA}▸ ${1}${RESET}\n${DIM}─────────────────────────────────────────────────────────────────────────────${RESET}"
}

# Get default value for a plugin option from defaults.sh
get_plugin_default_value() {
    local option="$1"
    # Convert @powerkit_plugin_xxx to POWERKIT_PLUGIN_XXX
    local var_name="${option#@}"
    var_name="${var_name^^}"
    printf '%s' "${!var_name:-}"
}

# Get description for a plugin option based on its name
get_plugin_option_description() {
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

print_option() {
    local option="$1" default="$2" possible="$3" description="$4"
    local current
    current=$(get_tmux_option "$option" "")

    # If no default provided, try to get it from defaults.sh for plugin options
    if [[ -z "$default" && "$option" == @powerkit_plugin_* ]]; then
        default=$(get_plugin_default_value "$option")
    fi

    # If no description provided, generate one based on option name
    if [[ -z "$description" || "$description" == "Plugin option" ]] && [[ "$option" == @powerkit_plugin_* ]]; then
        description=$(get_plugin_option_description "$option")
    fi

    printf "${GREEN}%-45s${RESET}" "$option"
    if [[ -n "$current" && "$current" != "$default" ]]; then
        echo -e " ${YELLOW}= $current${RESET} ${DIM}(default: ${default:-<empty>})${RESET}"
    elif [[ -n "$default" ]]; then
        echo -e " ${DIM}= $default${RESET}"
    else
        echo -e " ${DIM}(not set)${RESET}"
    fi
    [[ -n "$description" ]] && echo -e "  ${DIM}↳ $description${RESET}"
    [[ -n "$possible" ]] && echo -e "  ${DIM}  Values: $possible${RESET}"
}

print_tpm_option() {
    local option="$1"; local current
    current=$(get_tmux_option "$option" "")
    printf "${GREEN}%-45s${RESET}" "$option"
    [[ -n "$current" ]] && echo -e " ${YELLOW}= $current${RESET}" || echo -e " ${DIM}(not set)${RESET}"
}

discover_plugin_options() {
    local -A plugin_options=()

    # Scan plugin files using grep (much faster than line-by-line reading)
    while IFS= read -r match; do
        # Extract just the option name from grep output
        if [[ "$match" =~ (@powerkit_plugin_[a-zA-Z0-9_]+) ]]; then
            plugin_options["${BASH_REMATCH[1]}"]=1
        fi
    done < <(grep -rho '@powerkit_plugin_[a-zA-Z0-9_]\+' "$ROOT_DIR/plugin" 2>/dev/null | sort -u)

    # Also scan defaults.sh to discover all POWERKIT_PLUGIN_* defaults and convert to @powerkit_plugin_* format
    if [[ -f "$ROOT_DIR/defaults.sh" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^POWERKIT_PLUGIN_([A-Z0-9_]+)= ]]; then
                local var_name="${BASH_REMATCH[1]}"
                local option_name="@powerkit_plugin_${var_name,,}"
                plugin_options["$option_name"]=1
            fi
        done < "$ROOT_DIR/defaults.sh"
    fi

    printf '%s\n' "${!plugin_options[@]}" | sort
}

scan_tpm_plugin_options() {
    local plugin_dir="$1" plugin_name; plugin_name=$(basename "$plugin_dir")
    [[ "$plugin_name" == "tpm" || "$plugin_name" == "tmux-powerkit" ]] && return

    local -a options=()
    while IFS= read -r opt; do
        [[ "$opt" =~ [-_] ]] && [[ ${#opt} -gt 10 ]] && options+=("$opt")
    done < <(grep -rhI --include='*.sh' --include='*.tmux' -oE '@[a-z][a-z0-9_-]+' "$plugin_dir" 2>/dev/null | sort -u)

    if [[ ${#options[@]} -gt 0 ]]; then
        print_section "📦 ${plugin_name}" "$BLUE"
        for opt in "${options[@]}"; do print_tpm_option "$opt"; done
    fi
}

# =============================================================================
# Main
# =============================================================================

display_options() {
    local filter="${1:-}"

    # Pre-load all tmux options in one call for performance
    _batch_load_tmux_options 2>/dev/null || true

    print_header

    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║  🌃 Tokyo Night Theme Options                                             ║${RESET}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════════════════╝${RESET}"

    print_section "Theme Core Options" "$MAGENTA"
    for opt in "${THEME_OPTIONS[@]}"; do
        IFS='|' read -r option default possible description <<< "$opt"
        [[ -z "$filter" || "$option" == *"$filter"* || "$description" == *"$filter"* ]] && print_option "$option" "$default" "$possible" "$description"
    done

    # Discover and group plugin options
    local discovered_options
    discovered_options=$(discover_plugin_options)

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
                [[ "$has_visible" == "false" ]] && { print_section "Theme Plugin: ${display_name}" "$MAGENTA"; has_visible=true; }
                print_option "$option" "" "" "Plugin option" || true
            }
        done
    done

    echo -e "\n\n${BOLD}${BLUE}╔═══════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${BLUE}║  📦 Other TPM Plugins Options                                             ║${RESET}"
    echo -e "${BOLD}${BLUE}╚═══════════════════════════════════════════════════════════════════════════╝${RESET}"

    # Scan TPM plugins with timeout to avoid hanging
    if [[ -d "$TPM_PLUGINS_DIR" ]]; then
        for plugin_dir in "$TPM_PLUGINS_DIR"/*/; do
            [[ -d "$plugin_dir" ]] && scan_tpm_plugin_options "$plugin_dir" 2>/dev/null || true
        done
    fi

    echo -e "\n${DIM}Press 'q' to exit, '/' to search${RESET}\n"
}

[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { echo "Usage: $0 [filter]"; exit 0; }

# Simple invocation: pipe to less like keybindings_viewer.sh
display_options "${1:-}" | less -R
