#!/usr/bin/env bash
# =============================================================================
#  HELPER CONTRACT
#  Base functions and utilities for all PowerKit helpers
# =============================================================================
#
# TABLE OF CONTENTS
# =================
#   1. Overview
#   2. Architecture
#   3. Helper Types
#   4. Contract Functions (Mandatory & Optional)
#   5. Lifecycle
#   6. UI Backend Abstraction
#   7. API Reference
#   8. Examples
#
# =============================================================================
#
# 1. OVERVIEW
# ===========
#
# The Helper Contract provides a standardized framework for creating interactive
# tmux utilities (helpers) within PowerKit. It eliminates boilerplate code and
# ensures consistency across all helper implementations.
#
# Key Benefits:
#   - Reduces boilerplate from ~15 lines to ~3 lines per helper
#   - Provides UI backend abstraction (gum > fzf > basic fallback)
#   - Standardizes metadata, actions, and dispatch patterns
#   - Enables introspection via --metadata and --actions flags
#   - Automatic error handling and strict mode management
#
# =============================================================================
#
# 2. ARCHITECTURE
# ===============
#
# The helper system follows a layered architecture:
#
#   ┌─────────────────────────────────────────────────────────────────────────┐
#   │                           HELPER LAYER                                  │
#   │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐               │
#   │  │ password_sel  │  │ jira_selector │  │ theme_select  │  ...          │
#   │  └───────┬───────┘  └───────┬───────┘  └───────┬───────┘               │
#   └──────────┼──────────────────┼──────────────────┼────────────────────────┘
#              │                  │                  │
#   ┌──────────▼──────────────────▼──────────────────▼────────────────────────┐
#   │                      HELPER CONTRACT LAYER                              │
#   │  ┌─────────────────────────────────────────────────────────────────┐   │
#   │  │                    helper_contract.sh                           │   │
#   │  │  - helper_init()      - helper_dispatch()                       │   │
#   │  │  - helper_metadata_*  - helper_require()                        │   │
#   │  │  - helper_filter()    - helper_choose()                         │   │
#   │  │  - helper_toast()     - helper_pager()                          │   │
#   │  └─────────────────────────────────────────────────────────────────┘   │
#   └────────────────────────────────┬────────────────────────────────────────┘
#                                    │
#   ┌────────────────────────────────▼────────────────────────────────────────┐
#   │                        UI BACKEND LAYER                                 │
#   │  ┌─────────────────────────────────────────────────────────────────┐   │
#   │  │                      ui_backend.sh                              │   │
#   │  │  Priority: gum (preferred) > fzf (fallback) > basic (minimal)   │   │
#   │  │  - ui_filter()   - ui_choose()   - ui_table()                   │   │
#   │  │  - ui_input()    - ui_confirm()  - ui_spin()                    │   │
#   │  │  - ui_pager()    - ui_file()     - ui_format()                  │   │
#   │  └─────────────────────────────────────────────────────────────────┘   │
#   └────────────────────────────────┬────────────────────────────────────────┘
#                                    │
#   ┌────────────────────────────────▼────────────────────────────────────────┐
#   │                      POWERKIT CORE LAYER                                │
#   │  bootstrap.sh, cache.sh, options.sh, logger.sh, defaults.sh             │
#   └─────────────────────────────────────────────────────────────────────────┘
#
# =============================================================================
#
# 3. HELPER TYPES
# ===============
#
# Helpers are categorized by their display mechanism:
#
#   ┌────────────┬─────────────────────────────────────────────────────────────┐
#   │ Type       │ Description                                                 │
#   ├────────────┼─────────────────────────────────────────────────────────────┤
#   │ popup      │ Opens in `tmux display-popup -E` with interactive UI        │
#   │            │ Examples: bitwarden_selector, jira_issue_selector           │
#   ├────────────┼─────────────────────────────────────────────────────────────┤
#   │ menu       │ Uses `tmux display-menu` for native tmux menus              │
#   │            │ Examples: theme_selector, terraform_workspace_selector      │
#   ├────────────┼─────────────────────────────────────────────────────────────┤
#   │ command    │ Executes action via `run-shell` (no UI)                     │
#   │            │ Examples: cache_clear, pomodoro_timer                       │
#   ├────────────┼─────────────────────────────────────────────────────────────┤
#   │ toast      │ Shows brief notification via `display-message`              │
#   │            │ Examples: keybinding_conflict_toast                         │
#   └────────────┴─────────────────────────────────────────────────────────────┘
#
# =============================================================================
#
# 4. CONTRACT FUNCTIONS
# =====================
#
# MANDATORY FUNCTIONS (must be implemented by every helper):
# ----------------------------------------------------------
#
#   helper_main(action, ...)
#       Main entry point for the helper. Receives the action and any
#       additional arguments. Must handle at least the default action.
#
#       Parameters:
#         action  - The action to perform (string, may be empty)
#         ...     - Additional arguments passed to the helper
#
#       Example:
#         helper_main() {
#             local action="${1:-default}"
#             case "$action" in
#                 select|"") do_selection ;;
#                 refresh)   do_refresh ;;
#                 *)         echo "Unknown: $action" >&2; return 1 ;;
#             esac
#         }
#
# OPTIONAL FUNCTIONS (recommended for full contract compliance):
# --------------------------------------------------------------
#
#   helper_get_metadata()
#       Sets metadata about the helper using helper_metadata_set().
#       Called automatically when --metadata flag is passed.
#
#       Required metadata keys:
#         id          - Unique identifier (e.g., "bitwarden_password_selector")
#         name        - Human-readable name (e.g., "Bitwarden Password Selector")
#         description - Brief description of what the helper does
#         type        - One of: popup, menu, command, toast
#
#       Example:
#         helper_get_metadata() {
#             helper_metadata_set "id" "my_helper"
#             helper_metadata_set "name" "My Helper"
#             helper_metadata_set "description" "Does something useful"
#             helper_metadata_set "type" "popup"
#         }
#
#   helper_get_actions()
#       Returns a list of available actions, one per line.
#       Format: "action_name - Description"
#       Called automatically when --actions flag is passed.
#
#       Example:
#         helper_get_actions() {
#             echo "select - Select an item (default)"
#             echo "refresh - Refresh the cache"
#             echo "clear - Clear all cached data"
#         }
#
# =============================================================================
#
# 5. LIFECYCLE
# ============
#
# Helper execution follows this lifecycle:
#
#   1. SOURCE
#      ├── helper_contract.sh is sourced
#      └── POWERKIT_ROOT is determined
#
#   2. INIT (helper_init)
#      ├── Enable strict mode (unless --no-strict)
#      ├── Set HELPER_SCRIPT_DIR and HELPER_SCRIPT_NAME
#      ├── Source bootstrap.sh (minimal or full)
#      └── Source ui_backend.sh
#
#   3. DISPATCH (helper_dispatch)
#      ├── Parse first argument as action
#      ├── Handle special flags (--metadata, --actions, --help)
#      └── Call helper_main() with action and remaining args
#
#   4. EXECUTE (helper_main)
#      ├── Switch on action
#      ├── Perform helper-specific logic
#      └── Use UI functions as needed
#
#   5. CLEANUP
#      └── Automatic (bash handles cleanup)
#
# Sequence diagram:
#
#   User           Shell              helper_contract       helper.sh
#    │               │                      │                   │
#    │──run helper──▶│                      │                   │
#    │               │──source contract────▶│                   │
#    │               │                      │──source guard────▶│
#    │               │                      │                   │
#    │               │──helper_init()──────▶│                   │
#    │               │                      │──bootstrap───────▶│
#    │               │                      │──ui_backend──────▶│
#    │               │                      │                   │
#    │               │──helper_dispatch()──▶│                   │
#    │               │                      │──helper_main()───▶│
#    │               │                      │                   │──execute
#    │               │                      │◀──return──────────│
#    │◀──output─────────────────────────────│                   │
#
# =============================================================================
#
# 6. UI BACKEND ABSTRACTION
# =========================
#
# The helper contract provides UI functions that automatically use the best
# available backend. The priority is: gum > fzf > basic (select/read).
#
# Backend Detection:
#   - Set @powerkit_ui_backend in tmux.conf to force a specific backend
#   - Or let PowerKit auto-detect based on available commands
#
# Available UI Functions:
#
#   ┌─────────────────┬───────────────────────────────────────────────────────┐
#   │ Function        │ Description                                           │
#   ├─────────────────┼───────────────────────────────────────────────────────┤
#   │ helper_filter   │ Fuzzy search/filter from stdin                        │
#   │ helper_choose   │ Select from a list of options                         │
#   │ helper_table    │ Interactive table selection                           │
#   │ helper_input    │ Text input prompt                                     │
#   │ helper_confirm  │ Yes/No confirmation                                   │
#   │ helper_spin     │ Show spinner while command runs                       │
#   │ helper_pager    │ Page through long text                                │
#   │ helper_file     │ File picker                                           │
#   │ helper_toast    │ Show tmux notification                                │
#   └─────────────────┴───────────────────────────────────────────────────────┘
#
# Backend Comparison:
#
#   ┌─────────────────┬──────────────────┬──────────────────┬─────────────────┐
#   │ Feature         │ gum              │ fzf              │ basic           │
#   ├─────────────────┼──────────────────┼──────────────────┼─────────────────┤
#   │ Filter/Search   │ gum filter       │ fzf              │ select          │
#   │ Choose          │ gum choose       │ fzf --no-fuzzy   │ select          │
#   │ Table           │ gum table        │ fzf --header     │ column + select │
#   │ Input           │ gum input        │ N/A              │ read            │
#   │ Confirm         │ gum confirm      │ N/A              │ read -p         │
#   │ Spinner         │ gum spin         │ N/A              │ echo            │
#   │ Pager           │ gum pager        │ less             │ less            │
#   │ Style           │ gum style        │ ANSI codes       │ ANSI codes      │
#   └─────────────────┴──────────────────┴──────────────────┴─────────────────┘
#
# =============================================================================
#
# 7. API REFERENCE
# ================
#
# INITIALIZATION
# --------------
#
#   helper_init [OPTIONS]
#       Initialize the helper environment. Must be called after sourcing.
#
#       Options:
#         --no-strict   Disable strict mode (set -euo pipefail)
#         --full        Use full bootstrap instead of minimal
#
#       Example:
#         helper_init                 # Standard initialization
#         helper_init --no-strict     # For helpers that handle errors manually
#         helper_init --full          # When plugins/themes are needed
#
# METADATA
# --------
#
#   helper_metadata_set KEY VALUE
#       Set a metadata key-value pair.
#
#   helper_metadata_get KEY
#       Get a metadata value by key.
#
# DISPATCH
# --------
#
#   helper_dispatch "$@"
#       Dispatch command-line arguments to the appropriate handler.
#       Must be called at the end of the helper script.
#
# DEPENDENCY CHECKING
# -------------------
#
#   helper_require CMD [ERROR_MESSAGE]
#       Check if a command is available. Shows error and returns 1 if missing.
#
#       Example:
#         helper_require "jq" "jq is required for JSON parsing" || return 1
#
#   helper_require_selector
#       Check if a selector backend (gum/fzf) is available.
#       Logs warning if falling back to basic mode.
#
# ERROR HANDLING
# --------------
#
#   helper_show_error MESSAGE
#       Display error message and wait for keypress.
#
#   helper_show_warning MESSAGE
#       Display warning message (yellow).
#
#   helper_show_success MESSAGE
#       Display success message (green).
#
# UI FUNCTIONS
# ------------
#
#   helper_filter [PROMPT]
#       Fuzzy filter items from stdin.
#       Returns: Selected item
#
#       Example:
#         selected=$(echo -e "opt1\nopt2\nopt3" | helper_filter "Choose:")
#
#   helper_choose PROMPT "opt1" "opt2" ...
#       Select from a list of options.
#       Returns: Selected option
#
#       Example:
#         color=$(helper_choose "Pick color:" "red" "green" "blue")
#
#   helper_table [COLUMNS]
#       Interactive table selection from stdin (CSV/TSV).
#       Returns: Selected row
#
#       Example:
#         row=$(echo -e "Name,Age\nAlice,30\nBob,25" | helper_table "Name,Age")
#
#   helper_input PROMPT [DEFAULT]
#       Prompt for text input.
#       Returns: User input
#
#       Example:
#         name=$(helper_input "Enter name:" "anonymous")
#
#   helper_confirm [PROMPT]
#       Yes/No confirmation.
#       Returns: 0 for yes, 1 for no
#
#       Example:
#         helper_confirm "Delete file?" && rm "$file"
#
#   helper_spin TITLE COMMAND [ARGS...]
#       Show spinner while running a command.
#
#       Example:
#         helper_spin "Downloading..." curl -sO "$url"
#
#   helper_pager
#       Page through text from stdin.
#
#       Example:
#         cat large_file.txt | helper_pager
#
#   helper_file [DIRECTORY]
#       File picker starting from directory.
#       Returns: Selected file path
#
#       Example:
#         file=$(helper_file "$HOME/documents")
#
# FORMATTING
# ----------
#
#   helper_print_header TITLE [SUBTITLE]
#       Print a formatted header box.
#
#   helper_print_separator [WIDTH]
#       Print a horizontal separator line.
#
# CACHE
# -----
#
#   helper_get_cache_dir
#       Get helper-specific cache directory (creates if needed).
#       Returns: Path to cache directory
#
#   helper_get_cache_file FILENAME
#       Get path to a cache file.
#       Returns: Full path to cache file
#
# NOTIFICATIONS
# -------------
#
#   helper_toast MESSAGE [STYLE]
#       Show tmux notification.
#       Style: "simple" (default) or "center"
#
# =============================================================================
#
# 8. EXAMPLES
# ===========
#
# MINIMAL HELPER (command type):
# ------------------------------
#
#   #!/usr/bin/env bash
#   . "$(dirname "${BASH_SOURCE[0]}")/../contract/helper_contract.sh"
#   helper_init
#
#   helper_get_metadata() {
#       helper_metadata_set "id" "cache_clearer"
#       helper_metadata_set "name" "Cache Clearer"
#       helper_metadata_set "description" "Clear PowerKit cache"
#       helper_metadata_set "type" "command"
#   }
#
#   helper_main() {
#       cache_clear_all
#       helper_toast "Cache cleared!" "simple"
#   }
#
#   helper_dispatch "$@"
#
# INTERACTIVE HELPER (popup type):
# --------------------------------
#
#   #!/usr/bin/env bash
#   . "$(dirname "${BASH_SOURCE[0]}")/../contract/helper_contract.sh"
#   helper_init
#
#   helper_get_metadata() {
#       helper_metadata_set "id" "color_picker"
#       helper_metadata_set "name" "Color Picker"
#       helper_metadata_set "description" "Pick a color from the palette"
#       helper_metadata_set "type" "popup"
#   }
#
#   helper_get_actions() {
#       echo "pick - Pick a color (default)"
#       echo "list - List all colors"
#   }
#
#   _pick_color() {
#       local colors="red\ngreen\nblue\nyellow\ncyan\nmagenta"
#       local selected
#       selected=$(echo -e "$colors" | helper_filter "Pick color:")
#       [[ -n "$selected" ]] && helper_toast "Selected: $selected"
#   }
#
#   _list_colors() {
#       echo "Available colors:"
#       echo "  red, green, blue, yellow, cyan, magenta"
#   }
#
#   helper_main() {
#       local action="${1:-pick}"
#       case "$action" in
#           pick|"") _pick_color ;;
#           list)    _list_colors ;;
#           *)       echo "Unknown: $action" >&2; return 1 ;;
#       esac
#   }
#
#   helper_dispatch "$@"
#
# MENU HELPER (menu type):
# ------------------------
#
#   #!/usr/bin/env bash
#   . "$(dirname "${BASH_SOURCE[0]}")/../contract/helper_contract.sh"
#   helper_init
#
#   helper_get_metadata() {
#       helper_metadata_set "id" "quick_actions"
#       helper_metadata_set "name" "Quick Actions"
#       helper_metadata_set "description" "Common tmux actions"
#       helper_metadata_set "type" "menu"
#   }
#
#   helper_main() {
#       tmux display-menu -T "Quick Actions" -x C -y C \
#           "New Window"   w "new-window" \
#           "Split Horiz"  h "split-window -h" \
#           "Split Vert"   v "split-window -v" \
#           ""             "" "" \
#           "Cancel"       q ""
#   }
#
#   helper_dispatch "$@"
#
# =============================================================================
# END OF DOCUMENTATION
# =============================================================================

# Determine POWERKIT_ROOT from this file's location
# BASH_SOURCE[0] = helper_contract.sh
# BASH_SOURCE[1] = the helper that sourced this file
_HELPER_CONTRACT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POWERKIT_ROOT="${POWERKIT_ROOT:-$_HELPER_CONTRACT_DIR/../..}"

# Source guard
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "contract_helper" && return 0

# =============================================================================
# Helper Initialization
# =============================================================================

# Initialize helper environment
# This replaces the common boilerplate at the top of every helper:
#   set -euo pipefail
#   _SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   _ROOT_DIR="$_SCRIPT_DIR/../.."
#   . "$_ROOT_DIR/src/core/bootstrap.sh"
#   powerkit_bootstrap_minimal
#
# Usage: helper_init [OPTIONS]
#   --no-strict     Disable strict mode (set -euo pipefail)
#   --full          Use full bootstrap instead of minimal
#
helper_init() {
    local strict="1"
    local full_bootstrap=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-strict) strict=""; shift ;;
            --full)      full_bootstrap="1"; shift ;;
            *)           shift ;;
        esac
    done

    # Enable strict mode by default
    [[ -n "$strict" ]] && set -euo pipefail

    # Set helper script directory for the calling script
    # BASH_SOURCE[1] is the script that called helper_init
    # shellcheck disable=SC2034 # Exported for helpers to use
    if [[ -n "${BASH_SOURCE[1]:-}" ]]; then
        HELPER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
        HELPER_SCRIPT_NAME="$(basename "${BASH_SOURCE[1]}" .sh)"
    else
        HELPER_SCRIPT_DIR="$_HELPER_CONTRACT_DIR/../helpers"
        HELPER_SCRIPT_NAME="unknown"
    fi

    # Bootstrap PowerKit
    # Temporarily disable errexit during bootstrap as plugins may not be set -e safe
    # shellcheck source=src/core/bootstrap.sh
    . "${POWERKIT_ROOT}/src/core/bootstrap.sh"

    local _errexit_was_set=""
    [[ $- == *e* ]] && _errexit_was_set="1"
    set +e

    if [[ -n "$full_bootstrap" ]]; then
        powerkit_bootstrap
    else
        powerkit_bootstrap_minimal
    fi

    # Restore errexit if it was set before
    if [[ -n "$_errexit_was_set" ]]; then set -e; fi

    # Load UI backend
    # shellcheck source=src/utils/ui_backend.sh
    . "${POWERKIT_ROOT}/src/utils/ui_backend.sh"
}

# =============================================================================
# Helper Metadata (for introspection)
# =============================================================================

# Associative array to store helper metadata
declare -gA _HELPER_METADATA=()

# Set helper metadata
# Usage: helper_metadata_set KEY VALUE
helper_metadata_set() {
    local key="$1" value="$2"
    _HELPER_METADATA["$key"]="$value"
}

# Get helper metadata
# Usage: helper_metadata_get KEY
helper_metadata_get() {
    local key="$1"
    echo "${_HELPER_METADATA[$key]:-}"
}

# =============================================================================
# Action Dispatch
# =============================================================================

# Dispatch actions to appropriate handlers
# This provides a standard way to handle command-line arguments in helpers
#
# Usage at end of helper:
#   helper_dispatch "$@"
#
# The helper should define:
#   helper_main ACTION [ARGS...]   - Main entry point
#   helper_get_metadata            - Optional: Set metadata
#   helper_get_actions             - Optional: List available actions
#
helper_dispatch() {
    local action="${1:-}"
    shift 2>/dev/null || true

    case "$action" in
        --metadata)
            # Return metadata if helper defines helper_get_metadata
            if type helper_get_metadata &>/dev/null; then
                helper_get_metadata
                for key in "${!_HELPER_METADATA[@]}"; do
                    echo "$key=${_HELPER_METADATA[$key]}"
                done
            fi
            ;;
        --actions)
            # Return available actions if helper defines helper_get_actions
            if type helper_get_actions &>/dev/null; then
                helper_get_actions
            fi
            ;;
        --help|-h)
            _helper_show_help
            ;;
        "")
            # No action - call main with empty or default
            if type helper_main &>/dev/null; then
                helper_main "" "$@"
            fi
            ;;
        *)
            # Call main with action
            if type helper_main &>/dev/null; then
                helper_main "$action" "$@"
            else
                echo "Error: helper_main not defined" >&2
                return 1
            fi
            ;;
    esac
}

# Show help for the helper
_helper_show_help() {
    local name="${_HELPER_METADATA[name]:-$HELPER_SCRIPT_NAME}"
    local description="${_HELPER_METADATA[description]:-No description}"

    echo "Usage: $HELPER_SCRIPT_NAME [ACTION] [OPTIONS]"
    echo ""
    echo "$description"
    echo ""

    if type helper_get_actions &>/dev/null; then
        echo "Actions:"
        helper_get_actions | while read -r action; do
            echo "  $action"
        done
        echo ""
    fi

    echo "Special options:"
    echo "  --help, -h     Show this help"
    echo "  --metadata     Show helper metadata"
    echo "  --actions      List available actions"
}

# =============================================================================
# Dependency Checking
# =============================================================================

# Require a command, showing error in popup if missing
# Usage: helper_require CMD [ERROR_MESSAGE]
# Returns: 0 if available, 1 if missing (after showing error)
helper_require() {
    local cmd="$1"
    local msg="${2:-$cmd is required but not installed}"

    if ! has_cmd "$cmd"; then
        helper_show_error "$msg"
        return 1
    fi
    return 0
}

# Require fzf or gum for interactive selection
# Usage: helper_require_selector
helper_require_selector() {
    local backend
    backend=$(ui_detect_backend)

    if [[ "$backend" == "basic" ]]; then
        # Basic fallback is always available, but warn
        log_warn "helper" "No fzf or gum found, using basic selection"
    fi
    return 0
}

# =============================================================================
# Error Handling and Display
# =============================================================================

# Show an error message and wait for key press
# Usage: helper_show_error MESSAGE
helper_show_error() {
    local message="$1"
    local bold="${POWERKIT_ANSI_BOLD:-}"
    local red="${POWERKIT_ANSI_RED:-}"
    local reset="${POWERKIT_ANSI_RESET:-}"

    printf '\n%s%s%s\n\n' "$bold$red" "$message" "$reset"
    printf 'Press any key to close...'
    read -rsn1
}

# Show a warning message
# Usage: helper_show_warning MESSAGE
helper_show_warning() {
    local message="$1"
    local bold="${POWERKIT_ANSI_BOLD:-}"
    local yellow="${POWERKIT_ANSI_YELLOW:-}"
    local reset="${POWERKIT_ANSI_RESET:-}"

    printf '%s%s%s\n' "$bold$yellow" "$message" "$reset"
}

# Show success message
# Usage: helper_show_success MESSAGE
helper_show_success() {
    local message="$1"
    local bold="${POWERKIT_ANSI_BOLD:-}"
    local green="${POWERKIT_ANSI_GREEN:-}"
    local reset="${POWERKIT_ANSI_RESET:-}"

    printf '%s%s%s\n' "$bold$green" "$message" "$reset"
}

# =============================================================================
# UI Wrappers (convenience functions that delegate to ui_backend)
# =============================================================================

# Fuzzy filter items
# Usage: echo -e "item1\nitem2" | helper_filter [PROMPT]
helper_filter() {
    local prompt="${1:-Select:}"
    ui_filter -p "$prompt"
}

# Simple choice selection
# Usage: helper_choose [PROMPT] "opt1" "opt2" "opt3"
helper_choose() {
    local prompt="${1:-Select:}"
    shift
    ui_choose -p "$prompt" "$@"
}

# Table selection
# Usage: helper_table [COLUMNS] < data.csv
helper_table() {
    local columns="${1:-}"
    if [[ -n "$columns" ]]; then
        ui_table -c "$columns"
    else
        ui_table
    fi
}

# Text input
# Usage: helper_input [PROMPT] [DEFAULT]
helper_input() {
    local prompt="${1:-Input:}"
    local default="${2:-}"
    ui_input -p "$prompt" -v "$default"
}

# Confirmation prompt
# Usage: helper_confirm [PROMPT]
helper_confirm() {
    local prompt="${1:-Continue?}"
    ui_confirm "$prompt"
}

# Show spinner while running command
# Usage: helper_spin TITLE COMMAND [ARGS...]
helper_spin() {
    local title="$1"
    shift
    ui_spin -t "$title" -- "$@"
}

# Pager for long text
# Usage: helper_pager < long_text.txt
helper_pager() {
    ui_pager
}

# File picker
# Usage: helper_file [DIRECTORY]
helper_file() {
    local directory="${1:-.}"
    ui_file "$directory"
}

# =============================================================================
# Header and Formatting
# =============================================================================

# Print a standard header box
# Usage: helper_print_header TITLE [SUBTITLE]
helper_print_header() {
    local title="$1"
    local subtitle="${2:-}"
    local bold="${POWERKIT_ANSI_BOLD:-}"
    local cyan="${POWERKIT_ANSI_CYAN:-}"
    local dim="${POWERKIT_ANSI_DIM:-}"
    local reset="${POWERKIT_ANSI_RESET:-}"

    local width=40
    local border_top border_bottom
    border_top=$(printf '─%.0s' $(seq 1 $((width - 2))))
    border_bottom="$border_top"

    printf '%s%s╭%s╮%s\n' "$bold" "$cyan" "$border_top" "$reset"
    printf '%s%s│%*s%s%*s│%s\n' "$bold" "$cyan" $(( (width - 2 - ${#title}) / 2 )) "" "$title" $(( (width - 1 - ${#title}) / 2 )) "" "$reset"
    printf '%s%s╰%s╯%s\n' "$bold" "$cyan" "$border_bottom" "$reset"

    if [[ -n "$subtitle" ]]; then
        printf '\n%s%s%s\n' "$dim" "$subtitle" "$reset"
    fi
    printf '\n'
}

# Print a separator line
# Usage: helper_print_separator [WIDTH]
helper_print_separator() {
    local width="${1:-40}"
    local dim="${POWERKIT_ANSI_DIM:-}"
    local reset="${POWERKIT_ANSI_RESET:-}"

    printf '%s%s%s\n' "$dim" "$(printf '─%.0s' $(seq 1 "$width"))" "$reset"
}

# =============================================================================
# Cache Helpers
# =============================================================================

# Get helper-specific cache directory
# Usage: helper_get_cache_dir
helper_get_cache_dir() {
    local cache_base
    cache_base="$(dirname "$(get_cache_dir)")"
    local helper_cache="${cache_base}/helpers/${HELPER_SCRIPT_NAME}"

    [[ -d "$helper_cache" ]] || mkdir -p "$helper_cache"
    echo "$helper_cache"
}

# Get helper-specific cache file path
# Usage: helper_get_cache_file FILENAME
helper_get_cache_file() {
    local filename="$1"
    echo "$(helper_get_cache_dir)/$filename"
}

# =============================================================================
# END OF HELPER CONTRACT
# =============================================================================

# NOTE: Toast notifications are available via toast() from ui_backend.sh
# which is loaded by bootstrap. Use toast() directly in helpers:
#   toast "message" "warning"   # warning style (yellow)
#   toast "message" "error"     # error style (red)
#   toast "message" "success"   # success style (green)
#   toast "message"             # info style (default)
