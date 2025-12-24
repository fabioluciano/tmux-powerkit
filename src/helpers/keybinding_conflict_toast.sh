#!/usr/bin/env bash
# =============================================================================
# Helper: keybinding_conflict_toast
# Description: Displays a formatted popup showing keybinding conflicts
# Type: popup
# =============================================================================

# Source helper base (handles all initialization)
. "$(dirname "${BASH_SOURCE[0]}")/../contract/helper_contract.sh"
helper_init --no-strict

# =============================================================================
# Metadata
# =============================================================================

helper_get_metadata() {
    helper_metadata_set "id" "keybinding_conflict_toast"
    helper_metadata_set "name" "Keybinding Conflict Toast"
    helper_metadata_set "description" "Display keybinding conflicts notification"
    helper_metadata_set "type" "popup"
    helper_metadata_set "version" "2.0.0"
}

helper_get_actions() {
    echo "show - Display conflicts (default)"
}

# =============================================================================
# Configuration
# =============================================================================

CACHE_DIR="$(dirname "$(get_cache_dir)")"
LOG_FILE="${CACHE_DIR}/keybinding_conflicts.log"

# =============================================================================
# Display Functions
# =============================================================================

_show_conflicts() {
    # Colors from defaults.sh
    local red="${POWERKIT_ANSI_RED}"
    local yellow="${POWERKIT_ANSI_YELLOW}"
    local cyan="${POWERKIT_ANSI_CYAN}"
    local white="${POWERKIT_ANSI_BOLD}"
    local dim="${POWERKIT_ANSI_DIM}"
    local reset="${POWERKIT_ANSI_RESET}"

    # Check if log file exists
    if [[ ! -f "$LOG_FILE" ]]; then
        echo "No keybinding conflicts detected."
        read -r -n 1 -s
        return 0
    fi

    # Clear screen
    clear

    # Header
    echo ""
    echo -e "  ${red}+==============================================================+${reset}"
    echo -e "  ${red}|${reset}  ${yellow}  PowerKit: Keybinding Conflicts Detected!${reset}                 ${red}|${reset}"
    echo -e "  ${red}+==============================================================+${reset}"
    echo ""

    # Count conflicts
    local conflict_count
    conflict_count=$(grep -c "•" "$LOG_FILE" 2>/dev/null || echo "0")
    echo -e "  ${white}Found ${yellow}${conflict_count}${white} conflict(s):${reset}"
    echo ""

    # Read and display conflicts from log file
    while IFS= read -r line; do
        if [[ "$line" == *"•"* ]]; then
            # Color the conflict type
            if [[ "$line" == *"PowerKit internal"* ]]; then
                echo -e "  ${yellow}$line${reset}"
            elif [[ "$line" == *"Tmux conflict"* ]]; then
                echo -e "  ${red}$line${reset}"
            else
                echo -e "  $line"
            fi
        fi
    done < "$LOG_FILE"

    echo ""
    echo -e "  ${dim}----------------------------------------------------------------${reset}"
    echo ""
    echo -e "  ${cyan}How to fix:${reset}"
    echo -e "     Change the conflicting key in your ${white}tmux.conf${reset}:"
    echo -e "     ${dim}set -g @powerkit_plugin_<plugin>_keybinding_<action> \"<new_key>\"${reset}"
    echo ""
    echo -e "  ${cyan}To dismiss this warning permanently:${reset}"
    echo -e "     ${dim}rm '$LOG_FILE'${reset}"
    echo ""
    echo -e "  ${dim}----------------------------------------------------------------${reset}"
    echo ""
    echo -e "  ${white}Press any key to close...${reset}"

    # Wait for user input
    read -r -n 1 -s
}

# =============================================================================
# Main Entry Point
# =============================================================================

helper_main() {
    local action="${1:-show}"

    case "$action" in
        show|"") _show_conflicts ;;
        *)
            echo "Unknown action: $action" >&2
            return 1
            ;;
    esac
}

# Dispatch to handler
helper_dispatch "$@"
