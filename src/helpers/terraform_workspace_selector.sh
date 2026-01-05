#!/usr/bin/env bash
# =============================================================================
# Helper: terraform_workspace_selector
# Description: Interactive Terraform/OpenTofu workspace selector
# Type: menu
# =============================================================================

# Source helper base (handles all initialization)
# Using minimal bootstrap for faster startup
. "$(dirname "${BASH_SOURCE[0]}")/../contract/helper_contract.sh"
helper_init

# =============================================================================
# Metadata
# =============================================================================

helper_get_metadata() {
    helper_metadata_set "id" "terraform_workspace_selector"
    helper_metadata_set "name" "Terraform Workspace Selector"
    helper_metadata_set "description" "Switch Terraform/OpenTofu workspaces"
    helper_metadata_set "type" "menu"
}

helper_get_actions() {
    echo "select - Select workspace (default)"
    echo "invalidate - Invalidate cache"
}

# =============================================================================
# Tool Detection
# =============================================================================

# Detect terraform or tofu
detect_tool() {
    has_cmd "terraform" && { echo "terraform"; return 0; }
    has_cmd "tofu" && { echo "tofu"; return 0; }
    return 1
}

# =============================================================================
# Cache Management
# =============================================================================

# Invalidate terraform cache and force status refresh
invalidate_cache() {
    # Cache key format is "plugin_<name>" as defined in cache.sh
    cache_clear "plugin_terraform" || true

    # Force tmux to refresh status by temporarily lowering interval
    # This triggers immediate re-evaluation of #() commands
    local current_interval
    current_interval=$(tmux show-option -gqv status-interval 2>/dev/null || echo 5)
    tmux set-option -g status-interval 1
    # Small delay to let tmux process the change
    sleep 0.3
    # Restore original interval
    tmux set-option -g status-interval "$current_interval"
}

# =============================================================================
# Pane & Directory Utilities
# =============================================================================

# Get current pane path
get_pane_path() {
    local path
    path=$(tmux display-message -p -F "#{pane_current_path}" 2>/dev/null)
    [[ -z "$path" ]] && path="$PWD"
    echo "$path"
}

# Check if directory is a Terraform/Terragrunt directory
is_tf_directory() {
    local path="$1"
    [[ -d "${path}/.terraform" ]] && return 0
    ls "${path}"/*.tf &>/dev/null 2>&1 && return 0
    ls "${path}"/terragrunt*.hcl &>/dev/null 2>&1 && return 0
    return 1
}

# =============================================================================
# Workspace Selection
# =============================================================================

select_workspace() {
    local pane_path tool current_ws
    pane_path=$(get_pane_path)

    # Check if we're in a terraform directory
    if ! is_tf_directory "$pane_path"; then
        toast "Not in a Terraform directory" "error"
        return 0  # Return 0 to avoid tmux showing error message
    fi

    # Detect tool
    tool=$(detect_tool) || { toast "terraform/tofu not found" "error"; return 0; }

    # Get current workspace
    current_ws=$(cd "$pane_path" && "$tool" workspace show 2>/dev/null) || current_ws="default"

    # Get list of workspaces
    local -a workspaces=()
    while IFS= read -r ws; do
        # Remove leading * and spaces
        ws="${ws#\* }"
        ws="${ws#  }"
        ws="${ws// /}"
        [[ -z "$ws" ]] && continue
        workspaces+=("$ws")
    done < <(cd "$pane_path" && "$tool" workspace list 2>/dev/null)

    [[ ${#workspaces[@]} -eq 0 ]] && { toast "No workspaces found" "error"; return 0; }

    # Build menu
    local -a menu_args=()
    for ws in "${workspaces[@]}"; do
        local marker=" "
        [[ "$ws" == "$current_ws" ]] && marker="●"
        menu_args+=("$marker $ws" "" "run-shell \"cd '$pane_path' && $tool workspace select '$ws' >/dev/null 2>&1 && bash '$HELPER_SCRIPT_DIR/terraform_workspace_selector.sh' invalidate && bash '$HELPER_SCRIPT_DIR/terraform_workspace_selector.sh' toast 'Workspace: $ws' info\"")
    done

    # Add separator and new workspace option
    menu_args+=("" "" "")
    menu_args+=("+ New workspace..." "" "command-prompt -p 'New workspace name:' \"run-shell \\\"cd '$pane_path' && $tool workspace new '%1' >/dev/null 2>&1 && bash '$HELPER_SCRIPT_DIR/terraform_workspace_selector.sh' invalidate && bash '$HELPER_SCRIPT_DIR/terraform_workspace_selector.sh' toast 'Created: %1' success\\\"\"")

    # Show menu
    local icon=""
    [[ "$tool" == "tofu" ]] && icon=""
    tmux display-menu -T "$icon  Select Workspace" -x C -y C "${menu_args[@]}"
}

# =============================================================================
# Main Entry Point
# =============================================================================

helper_main() {
    local action="${1:-select}"
    # Skip the action argument - remaining args go to toast
    [[ $# -gt 0 ]] && shift

    case "$action" in
        select|switch|"") select_workspace ;;
        invalidate)       invalidate_cache ;;
        toast)            toast "$@" ;;
        *)
            echo "Unknown action: $action" >&2
            return 1
            ;;
    esac
}

# Dispatch to handler
helper_dispatch "$@"
