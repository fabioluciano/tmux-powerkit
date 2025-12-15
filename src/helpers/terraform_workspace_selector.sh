#!/usr/bin/env bash
# Helper: terraform_workspace_selector - Interactive Terraform/OpenTofu workspace selector

set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$CURRENT_DIR/../utils.sh" 2>/dev/null || . "${CURRENT_DIR%/*}/utils.sh" 2>/dev/null || true

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-powerkit"

# Detect terraform or tofu
detect_tool() {
    command -v terraform &>/dev/null && { echo "terraform"; return 0; }
    command -v tofu &>/dev/null && { echo "tofu"; return 0; }
    return 1
}

# Invalidate terraform cache
invalidate_cache() {
    local cache_file="${CACHE_DIR}/terraform.cache"
    [[ -f "$cache_file" ]] && rm -f "$cache_file"
}

# Get current pane path
get_pane_path() {
    local path
    path=$(tmux display-message -p -F "#{pane_current_path}" 2>/dev/null)
    [[ -z "$path" ]] && path="$PWD"
    echo "$path"
}

# Check if we're in a terraform directory
is_tf_directory() {
    local pane_path="$1"
    [[ -d "${pane_path}/.terraform" ]] && return 0
    ls "${pane_path}"/*.tf &>/dev/null 2>&1 && return 0
    return 1
}

select_workspace() {
    local pane_path tool current_ws
    pane_path=$(get_pane_path)
    
    # Check if we're in a terraform directory
    if ! is_tf_directory "$pane_path"; then
        toast "❌ Not in a Terraform directory" "simple"
        return 1
    fi
    
    # Detect tool
    tool=$(detect_tool) || { toast "❌ terraform/tofu not found" "simple"; return 1; }
    
    # Get current workspace
    current_ws=$(cd "$pane_path" && "$tool" workspace show 2>/dev/null) || current_ws="default"
    
    # Get list of workspaces
    local -a workspaces=() menu_items=()
    while IFS= read -r ws; do
        # Remove leading * and spaces
        ws="${ws#\* }"
        ws="${ws#  }"
        ws="${ws// /}"
        [[ -z "$ws" ]] && continue
        workspaces+=("$ws")
    done < <(cd "$pane_path" && "$tool" workspace list 2>/dev/null)
    
    [[ ${#workspaces[@]} -eq 0 ]] && { toast "❌ No workspaces found" "simple"; return 1; }
    
    # Build menu
    local -a menu_args=()
    for ws in "${workspaces[@]}"; do
        local marker=" "
        [[ "$ws" == "$current_ws" ]] && marker="●"
        menu_args+=("$marker $ws" "" "run-shell \"cd '$pane_path' && $tool workspace select '$ws' >/dev/null 2>&1 && rm -f '${CACHE_DIR}/terraform.cache' && tmux display-message ' Workspace: $ws' && tmux refresh-client -S\"")
    done
    
    # Add separator and new workspace option
    menu_args+=("" "" "")
    menu_args+=("+ New workspace..." "" "command-prompt -p 'New workspace name:' \"run-shell \\\"cd '$pane_path' && $tool workspace new '%1' >/dev/null 2>&1 && rm -f '${CACHE_DIR}/terraform.cache' && tmux display-message ' Created: %1' && tmux refresh-client -S\\\"\"")
    
    # Show menu
    local icon=""
    [[ "$tool" == "tofu" ]] && icon=""
    tmux display-menu -T "$icon  Select Workspace" -x C -y C "${menu_args[@]}"
}

case "${1:-select}" in
    select|switch) select_workspace ;;
    invalidate) invalidate_cache ;;
    *) echo "Usage: $0 {select|invalidate}"; exit 1 ;;
esac
