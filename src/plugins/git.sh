#!/usr/bin/env bash
# =============================================================================
# Plugin: git
# Description: Display current git branch and status
# Type: conditional (hidden when not in a git repository)
# Dependencies: git
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "git"
    metadata_set "name" "Git"
    metadata_set "version" "2.0.0"
    metadata_set "description" "Display current git branch and status"
    metadata_set "priority" "40"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_cmd "git" || return 1
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Icons
    declare_option "icon" "icon" $'\U000F01D2' "Plugin icon"
    declare_option "icon_modified" "icon" $'\U000F0A6E' "Icon for modified state"

    # Cache
    declare_option "cache_ttl" "number" "15" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

plugin_get_state() {
    local branch=$(plugin_data_get "branch")
    [[ -n "$branch" ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() {
    local modified=$(plugin_data_get "modified")
    [[ "$modified" == "1" ]] && printf 'warning' || printf 'ok'
}

plugin_get_context() {
    local modified=$(plugin_data_get "modified")
    [[ "$modified" == "1" ]] && printf 'modified' || printf 'clean'
}

plugin_get_icon() {
    local context=$(plugin_get_context)
    [[ "$context" == "modified" ]] && get_option "icon_modified" || get_option "icon"
}

# =============================================================================
# Main Logic
# =============================================================================

plugin_collect() {
    local path=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null)
    [[ -z "$path" || ! -d "$path" ]] && return

    # Check if inside a git repository
    git -C "$path" rev-parse --is-inside-work-tree &>/dev/null || return

    # Get git status
    local status_output
    status_output=$(git -C "$path" status --porcelain=v1 --branch 2>/dev/null)

    # Parse branch and changes
    local branch="" modified=0 changed=0 untracked=0

    while IFS= read -r line; do
        if [[ "$line" == "## "* ]]; then
            # Branch line: ## branch...upstream
            branch="${line#\#\# }"
            branch="${branch%%...*}"
        elif [[ -n "$line" ]]; then
            # File change line
            local status="${line:0:2}"
            if [[ "$status" == "??" ]]; then
                ((untracked++))
            elif [[ "$status" != "  " ]]; then
                ((changed++))
            fi
            modified=1
        fi
    done <<< "$status_output"

    plugin_data_set "branch" "$branch"
    plugin_data_set "modified" "$modified"
    plugin_data_set "changed" "$changed"
    plugin_data_set "untracked" "$untracked"
}

plugin_render() {
    local branch changed untracked
    branch=$(plugin_data_get "branch")
    changed=$(plugin_data_get "changed")
    untracked=$(plugin_data_get "untracked")

    [[ -z "$branch" ]] && return 0

    local result="$branch"
    [[ "$changed" -gt 0 ]] && result+=" ~$changed"
    [[ "$untracked" -gt 0 ]] && result+=" +$untracked"

    printf '%s' "$result"
}

