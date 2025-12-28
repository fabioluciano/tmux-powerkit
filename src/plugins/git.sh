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
    metadata_set "description" "Display current git branch and status"
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
    declare_option "icon" "icon" $'\U000F02A2' "Plugin icon"
    declare_option "icon_modified" "icon" $'\U000F02A2' "Icon for modified state"

    # Display
    declare_option "branch_max_length" "number" "15" "Maximum branch name length (0 to disable truncation)"

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
    local ahead=$(plugin_data_get "ahead")
    local modified=$(plugin_data_get "modified")

    # Commits not pushed → warning (needs attention)
    [[ "$ahead" -gt 0 ]] && { printf 'warning'; return; }
    # Local modifications → info (informational)
    [[ "$modified" == "1" ]] && { printf 'info'; return; }
    # Clean state
    printf 'ok'
}

plugin_get_context() {
    local ahead=$(plugin_data_get "ahead")
    local modified=$(plugin_data_get "modified")

    [[ "$ahead" -gt 0 ]] && { printf 'unpushed'; return; }
    [[ "$modified" == "1" ]] && { printf 'modified'; return; }
    printf 'clean'
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

    # Parse branch, changes and ahead/behind
    local branch="" modified=0 changed=0 untracked=0 ahead=0 behind=0

    while IFS= read -r line; do
        if [[ "$line" == "## "* ]]; then
            # Branch line: ## branch...upstream [ahead N, behind M]
            branch="${line#\#\# }"
            # Extract ahead/behind counts
            if [[ "$branch" =~ \[ahead\ ([0-9]+) ]]; then
                ahead="${BASH_REMATCH[1]}"
            fi
            if [[ "$branch" =~ behind\ ([0-9]+) ]]; then
                behind="${BASH_REMATCH[1]}"
            fi
            # Clean branch name
            branch="${branch%%...*}"
            branch="${branch%% \[*}"
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

    # If no ahead count from status, check for unpushed commits manually
    # This handles branches without upstream or with different tracking
    if [[ "$ahead" -eq 0 && -n "$branch" ]]; then
        local remote merge_branch upstream=""
        remote=$(git -C "$path" config --get "branch.${branch}.remote" 2>/dev/null)
        merge_branch=$(git -C "$path" config --get "branch.${branch}.merge" 2>/dev/null)
        
        if [[ -n "$remote" && -n "$merge_branch" ]]; then
            # Use configured upstream
            upstream="${remote}/${merge_branch#refs/heads/}"
        else
            # Fallback: try origin/<branch> if it exists (no config needed)
            if git -C "$path" rev-parse --verify "origin/${branch}" &>/dev/null; then
                upstream="origin/${branch}"
            fi
        fi
        
        if [[ -n "$upstream" ]]; then
            ahead=$(git -C "$path" rev-list --count "${upstream}..HEAD" 2>/dev/null || echo 0)
            behind=$(git -C "$path" rev-list --count "HEAD..${upstream}" 2>/dev/null || echo 0)
        fi
    fi

    plugin_data_set "branch" "$branch"
    plugin_data_set "modified" "$modified"
    plugin_data_set "changed" "$changed"
    plugin_data_set "untracked" "$untracked"
    plugin_data_set "ahead" "$ahead"
    plugin_data_set "behind" "$behind"
}

plugin_render() {
    local branch changed untracked ahead behind max_length
    branch=$(plugin_data_get "branch")
    changed=$(plugin_data_get "changed")
    untracked=$(plugin_data_get "untracked")
    ahead=$(plugin_data_get "ahead")
    behind=$(plugin_data_get "behind")
    max_length=$(get_option "branch_max_length")

    [[ -z "$branch" ]] && return 0

    # Truncate branch name if exceeds max_length
    [[ "$max_length" -gt 0 ]] && branch=$(truncate_text "$branch" "$max_length" "…")

    local result="$branch"
    [[ "$changed" -gt 0 ]] && result+=" ~$changed"
    [[ "$untracked" -gt 0 ]] && result+=" +$untracked"
    [[ "$ahead" -gt 0 ]] && result+=" ↑$ahead"
    [[ "$behind" -gt 0 ]] && result+=" ↓$behind"

    printf '%s' "$result"
}

