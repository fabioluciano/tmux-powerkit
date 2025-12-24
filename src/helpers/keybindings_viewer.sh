#!/usr/bin/env bash
# =============================================================================
# Helper: keybindings_viewer
# Description: Display all tmux keybindings grouped by plugin
# Type: popup
# =============================================================================

# Source helper base (handles all initialization)
. "$(dirname "${BASH_SOURCE[0]}")/../contract/helper_contract.sh"
helper_init --no-strict

# =============================================================================
# Metadata
# =============================================================================

helper_get_metadata() {
    helper_metadata_set "id" "keybindings_viewer"
    helper_metadata_set "name" "Keybindings Viewer"
    helper_metadata_set "description" "View all tmux keybindings grouped by plugin"
    helper_metadata_set "type" "popup"
    helper_metadata_set "version" "2.0.0"
}

helper_get_actions() {
    echo "view [filter] - View keybindings (default)"
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
RED="${POWERKIT_ANSI_RED}"
RESET="${POWERKIT_ANSI_RESET}"

TPM_PLUGINS_DIR="${TMUX_PLUGIN_MANAGER_PATH:-$HOME/.tmux/plugins}"
[[ ! -d "$TPM_PLUGINS_DIR" && -d "$HOME/.config/tmux/plugins" ]] && TPM_PLUGINS_DIR="$HOME/.config/tmux/plugins"

# =============================================================================
# Display Functions
# =============================================================================

print_header() {
    # Get prefix once (already cached by _batch_load_tmux_options in main)
    local prefix
    prefix=$(get_tmux_option "prefix" "C-b")

    echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${CYAN}  ⌨️  tmux Keybindings Reference${RESET}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
    echo -e "${DIM}  Prefix: ${YELLOW}${prefix}${RESET}\n"
}

print_section() {
    echo -e "\n${BOLD}${2:-$MAGENTA}▸ ${1}${RESET}\n${DIM}─────────────────────────────────────────────────────────────────────────────${RESET}"
}

format_key() {
    local key="$1"
    key="${key//C-/Ctrl+}"
    key="${key//M-/Alt+}"
    key="${key//S-/Shift+}"
    printf '%s' "$key"
}

extract_plugin_from_path() {
    local path="$1"
    [[ "$path" =~ /plugins/([^/]+)/ ]] && printf '%s' "${BASH_REMATCH[1]}" || printf ''
}

print_keybindings() {
    print_section "Plugin Keybindings" "$CYAN"

    declare -A plugin_bindings
    declare -a builtin_bindings

    # Single tmux call - get all prefix bindings at once
    local all_bindings
    all_bindings=$(tmux list-keys -T prefix 2>/dev/null) || return

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        # Parse line more efficiently using bash regex
        # Format: bind-key -T prefix <key> <command...>
        if [[ "$line" =~ ^bind-key[[:space:]]+-T[[:space:]]+prefix[[:space:]]+([^[:space:]]+)[[:space:]]+(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local cmd="${BASH_REMATCH[2]}"
            local plugin

            plugin=$(extract_plugin_from_path "$cmd")
            key=$(format_key "$key")

            if [[ -n "$plugin" ]]; then
                plugin_bindings["$plugin"]+="${key}|${cmd}"$'\n'
            else
                builtin_bindings+=("${key}|${cmd}")
            fi
        fi
    done <<< "$all_bindings"

    # Display plugin bindings
    for plugin in $(printf '%s\n' "${!plugin_bindings[@]}" | sort); do
        echo -e "\n  ${BOLD}${BLUE}📦 ${plugin}${RESET}"
        while IFS='|' read -r key cmd; do
            [[ -z "$key" ]] && continue
            printf "    ${GREEN}%-15s${RESET} ${DIM}%s${RESET}\n" "$key" "$cmd"
        done <<< "${plugin_bindings[$plugin]}"
    done

    # Display builtin bindings
    if [[ ${#builtin_bindings[@]} -gt 0 ]]; then
        print_section "tmux Built-in" "$MAGENTA"
        for binding in "${builtin_bindings[@]}"; do
            IFS='|' read -r key cmd <<< "$binding"
            printf "  ${GREEN}%-15s${RESET} ${DIM}%s${RESET}\n" "$key" "$cmd"
        done
    fi
}

print_root_bindings() {
    # Single tmux call - get root bindings (limit to first 20)
    local all_bindings
    all_bindings=$(tmux list-keys -T root 2>/dev/null | head -20) || return
    [[ -z "$all_bindings" ]] && return

    print_section "Root Bindings (no prefix)" "$YELLOW"

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        # Parse line using bash regex
        # Format: bind-key -T root <key> <command...>
        if [[ "$line" =~ ^bind-key[[:space:]]+-T[[:space:]]+root[[:space:]]+([^[:space:]]+)[[:space:]]+(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local cmd="${BASH_REMATCH[2]}"
            key=$(format_key "$key")
            printf "  ${GREEN}%-15s${RESET} ${DIM}%s${RESET}\n" "$key" "$cmd"
        fi
    done <<< "$all_bindings"
}

print_conflicts() {
    local log_file
    log_file="$(dirname "$(get_cache_dir)")/keybinding_conflicts.log"
    [[ ! -f "$log_file" ]] && return

    print_section "⚠️  Keybinding Conflicts Detected" "$RED"
    echo -e "  ${DIM}These conflicts were detected at startup:${RESET}\n"

    while IFS= read -r line; do
        # Skip header lines
        [[ "$line" == "==="* || "$line" == "Detected at:"* || "$line" == "Fix by"* || -z "$line" ]] && continue
        # Format conflict lines
        if [[ "$line" == *"PowerKit internal"* ]]; then
            echo -e "  ${RED}●${RESET} ${YELLOW}${line#  • }${RESET}"
        elif [[ "$line" == *"Tmux conflict"* ]]; then
            echo -e "  ${RED}●${RESET} ${YELLOW}${line#  • }${RESET}"
        fi
    done < "$log_file"

    echo -e "\n  ${DIM}Fix: Change keys in tmux.conf using @powerkit_* options${RESET}"
}

# =============================================================================
# Main Display
# =============================================================================

_display_keybindings() {
    local filter="${1:-}"

    # Pre-load all tmux options in one call for performance
    _batch_load_tmux_options 2>/dev/null || true

    print_header
    print_conflicts
    print_keybindings
    print_root_bindings
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
            _display_keybindings "${1:-}" | helper_pager
            ;;
        *)
            # Treat unknown action as filter
            _display_keybindings "$action" | helper_pager
            ;;
    esac
}

# Dispatch to handler
helper_dispatch "$@"
