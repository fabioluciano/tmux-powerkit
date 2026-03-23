#!/usr/bin/env bash
# =============================================================================
# Plugin: yadm
# Description: Display yadm dotfile status (modified, untracked, ahead/behind)
# Type: conditional (hidden when yadm is not installed/initialized)
# Dependencies: git, yadm
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "yadm"
    metadata_set "name" "yadm"
    metadata_set "description" "Display yadm dotfile status"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_cmd "git" || return 1
    require_cmd "yadm" || return 1
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Icons
    declare_option "icon" "icon" $'\U000F0493' "Plugin icon (cog-outline)"
    declare_option "icon_modified" "icon" $'\U000F0493' "Icon for modified state"

    # Display
    declare_option "show_branch" "bool" "false" "Show branch name instead of yadm label"
    declare_option "branch_max_length" "number" "15" "Maximum branch name length (0 to disable truncation)"

    # Cache
    declare_option "cache_ttl" "number" "60" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

# No plugin_should_be_active() - yadm manages $HOME dotfiles globally,
# it is always relevant regardless of current directory.

plugin_get_state() {
    local branch=$(plugin_data_get "branch")
    [[ -n "$branch" ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() {
    local ahead=$(plugin_data_get "ahead")
    local modified=$(plugin_data_get "modified")

    # Commits not pushed -> warning (needs attention)
    [[ "$ahead" -gt 0 ]] && { printf 'warning'; return; }
    # Local modifications -> info (informational)
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
    # Check if yadm is initialized
    yadm rev-parse --is-inside-work-tree &>/dev/null || return 1

    # Get yadm status
    local status_output
    status_output=$(yadm status --porcelain=v1 --branch 2>/dev/null)

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
    if [[ "$ahead" -eq 0 && -n "$branch" ]]; then
        local remote merge_branch upstream=""
        remote=$(yadm config --get "branch.${branch}.remote" 2>/dev/null)
        merge_branch=$(yadm config --get "branch.${branch}.merge" 2>/dev/null)

        if [[ -n "$remote" && -n "$merge_branch" ]]; then
            upstream="${remote}/${merge_branch#refs/heads/}"
        else
            if yadm rev-parse --verify "origin/${branch}" &>/dev/null; then
                upstream="origin/${branch}"
            fi
        fi

        if [[ -n "$upstream" ]]; then
            ahead=$(yadm rev-list --count "${upstream}..HEAD" 2>/dev/null || echo 0)
            behind=$(yadm rev-list --count "HEAD..${upstream}" 2>/dev/null || echo 0)
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
    local branch changed untracked ahead behind show_branch max_length
    branch=$(plugin_data_get "branch")
    changed=$(plugin_data_get "changed")
    untracked=$(plugin_data_get "untracked")
    ahead=$(plugin_data_get "ahead")
    behind=$(plugin_data_get "behind")
    show_branch=$(get_option "show_branch")
    max_length=$(get_option "branch_max_length")

    [[ -z "$branch" ]] && return 0

    local result="yadm"
    if [[ "$show_branch" == "true" ]]; then
        result="$branch"
        [[ "$max_length" -gt 0 ]] && result=$(truncate_text "$result" "$max_length" "...")
    fi
    [[ "$changed" -gt 0 ]] && result+=" ~$changed"
    [[ "$untracked" -gt 0 ]] && result+=" +$untracked"
    [[ "$ahead" -gt 0 ]] && result+=" ↑$ahead"
    [[ "$behind" -gt 0 ]] && result+=" ↓$behind"

    printf '%s' "$result"
}
