#!/usr/bin/env bash
# Helper: keybindings_viewer - Display all tmux keybindings grouped by plugin

set -eu

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$CURRENT_DIR/.."

# Source common dependencies
# shellcheck source=src/helper_bootstrap.sh
. "$ROOT_DIR/helper_bootstrap.sh"

# =============================================================================
# Constants
# =============================================================================

# ANSI colors (from defaults.sh via helper_bootstrap)
BOLD="${POWERKIT_ANSI_BOLD:-\033[1m}"
DIM="${POWERKIT_ANSI_DIM:-\033[2m}"
CYAN="${POWERKIT_ANSI_CYAN:-\033[36m}"
GREEN="${POWERKIT_ANSI_GREEN:-\033[32m}"
YELLOW="${POWERKIT_ANSI_YELLOW:-\033[33m}"
MAGENTA="${POWERKIT_ANSI_MAGENTA:-\033[35m}"
BLUE="${POWERKIT_ANSI_BLUE:-\033[34m}"
RED="${POWERKIT_ANSI_RED:-\033[31m}"
RESET="${POWERKIT_ANSI_RESET:-\033[0m}"

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
    local log_file="${POWERKIT_CACHE_DIR}/keybinding_conflicts.log"
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
# Main
# =============================================================================

main() {
    # Pre-load all tmux options in one call for performance
    _batch_load_tmux_options 2>/dev/null || true

    print_header
    print_conflicts
    print_keybindings
    print_root_bindings
    echo -e "\n${DIM}Press 'q' to exit, '/' to search${RESET}\n"
}

main | less -R
