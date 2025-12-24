#!/usr/bin/env bash
# =============================================================================
# Plugin: github
# Description: Monitor GitHub repositories for issues, PRs and comments
# Dependencies: curl, jq (optional for better parsing), gh CLI (optional)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "github"
    metadata_set "name" "GitHub"
    metadata_set "version" "2.0.0"
    metadata_set "description" "Monitor GitHub repos for issues, PRs and comments"
    metadata_set "priority" "105"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_cmd "curl" || return 1
    require_cmd "jq" 1  # Optional but recommended
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

GITHUB_API="https://api.github.com"

plugin_declare_options() {
    # Repository configuration
    declare_option "repos" "string" "" "Comma-separated list of owner/repo"
    declare_option "token" "string" "" "GitHub personal access token"
    declare_option "filter_user" "string" "" "Filter issues/PRs by username"

    # Display options
    declare_option "show_issues" "bool" "true" "Show open issues count"
    declare_option "show_prs" "bool" "true" "Show open PRs count"
    declare_option "show_comments" "bool" "false" "Show PR comments count"
    declare_option "format" "string" "simple" "Format style: simple or detailed"
    declare_option "separator" "string" " | " "Separator between metrics"

    # Icons
    declare_option "icon" "icon" $'\U000F02A4' "Plugin icon"
    declare_option "icon_issue" "icon" $'\U0000F41B' "Issues icon"
    declare_option "icon_pr" "icon" $'\U0000F407' "PR icon"

    # Thresholds
    declare_option "warning_threshold" "number" "10" "Warning when total exceeds threshold"

    # Cache
    declare_option "cache_ttl" "number" "300" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

_is_authenticated() {
    # Check gh CLI authentication
    if has_cmd "gh"; then
        gh auth status &>/dev/null && return 0
    fi
    # Check for token options or env vars
    local token=$(get_option "token")
    [[ -n "$token" ]] && return 0
    [[ -n "${GITHUB_TOKEN:-}" || -n "${GH_TOKEN:-}" ]] && return 0
    return 1
}

_get_token() {
    local token=$(get_option "token")
    [[ -n "$token" ]] && { printf '%s' "$token"; return 0; }
    [[ -n "${GITHUB_TOKEN:-}" ]] && { printf '%s' "$GITHUB_TOKEN"; return 0; }
    [[ -n "${GH_TOKEN:-}" ]] && { printf '%s' "$GH_TOKEN"; return 0; }
    return 1
}

plugin_get_state() {
    if ! _is_authenticated; then
        printf 'failed'
        return
    fi
    local total=$(plugin_data_get "total")
    local api_error=$(plugin_data_get "api_error")
    
    if [[ "$api_error" == "1" ]]; then
        printf 'degraded'
    elif [[ "${total:-0}" -gt 0 ]]; then
        printf 'active'
    else
        printf 'inactive'
    fi
}

plugin_get_health() {
    if ! _is_authenticated; then
        printf 'error'
        return
    fi
    
    local api_error=$(plugin_data_get "api_error")
    [[ "$api_error" == "1" ]] && { printf 'error'; return; }
    
    local total=$(plugin_data_get "total")
    local warning_threshold=$(get_option "warning_threshold")
    
    [[ "${total:-0}" -ge "$warning_threshold" ]] && printf 'warning' || printf 'ok'
}

plugin_get_context() {
    if ! _is_authenticated; then
        printf 'unauthenticated'
        return
    fi
    
    local api_error=$(plugin_data_get "api_error")
    [[ "$api_error" == "1" ]] && { printf 'api_error'; return; }
    
    local total=$(plugin_data_get "total")
    local issues=$(plugin_data_get "issues")
    local prs=$(plugin_data_get "prs")
    
    total="${total:-0}"
    issues="${issues:-0}"
    prs="${prs:-0}"
    
    if (( total == 0 )); then
        printf 'clear'
    elif (( issues > 0 && prs > 0 )); then
        printf 'issues_and_prs'
    elif (( issues > 0 )); then
        printf 'issues_only'
    elif (( prs > 0 )); then
        printf 'prs_only'
    else
        printf 'activity'
    fi
}

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# API Functions
# =============================================================================

_make_github_api_call() {
    local url="$1"
    local token=$(_get_token)
    
    local curl_opts=(-s -f --connect-timeout 5 --max-time 10)
    [[ -n "$token" ]] && curl_opts+=(-H "Authorization: token $token")
    curl_opts+=(-H "Accept: application/vnd.github+json")
    
    curl "${curl_opts[@]}" "$url" 2>/dev/null
}

_get_api_error_message() {
    local response="$1"
    has_cmd jq && echo "$response" | jq -r '.message // empty' 2>/dev/null
}

_is_valid_api_response() {
    local response="$1"
    [[ -z "$response" ]] && return 1
    
    local error_msg=$(_get_api_error_message "$response")
    [[ -n "$error_msg" ]] && return 1
    
    return 0
}

# Count issues using Search API
_count_issues() {
    local owner="$1"
    local repo="$2"
    local filter_user="$3"
    
    local query="repo:${owner}/${repo}+type:issue+state:open"
    [[ -n "$filter_user" ]] && query="${query}+author:${filter_user}"
    
    local url="$GITHUB_API/search/issues?q=${query}&per_page=1"
    local response=$(_make_github_api_call "$url")
    
    [[ -z "$response" ]] && { echo "0"; return 1; }
    
    if has_cmd jq; then
        local error_msg=$(echo "$response" | jq -r '.message // empty' 2>/dev/null)
        [[ -n "$error_msg" ]] && { echo "0"; return 1; }
        echo "$response" | jq -r '.total_count // 0' 2>/dev/null
    else
        # Fallback grep parsing
        echo "$response" | grep -o '"total_count":[0-9]*' | grep -o '[0-9]*' | head -1
    fi
}

# Count PRs using Search API
_count_prs() {
    local owner="$1"
    local repo="$2"
    local filter_user="$3"
    
    local query="repo:${owner}/${repo}+type:pr+state:open"
    [[ -n "$filter_user" ]] && query="${query}+author:${filter_user}"
    
    local url="$GITHUB_API/search/issues?q=${query}&per_page=1"
    local response=$(_make_github_api_call "$url")
    
    [[ -z "$response" ]] && { echo "0"; return 1; }
    
    if has_cmd jq; then
        local error_msg=$(echo "$response" | jq -r '.message // empty' 2>/dev/null)
        [[ -n "$error_msg" ]] && { echo "0"; return 1; }
        echo "$response" | jq -r '.total_count // 0' 2>/dev/null
    else
        echo "$response" | grep -o '"total_count":[0-9]*' | grep -o '[0-9]*' | head -1
    fi
}

# Count PR comments
_count_pr_comments() {
    local owner="$1"
    local repo="$2"
    local filter_user="$3"
    
    local url="$GITHUB_API/repos/$owner/$repo/pulls?state=open&per_page=100"
    local response=$(_make_github_api_call "$url")
    
    [[ -z "$response" ]] || ! _is_valid_api_response "$response" && { echo "0"; return 1; }
    
    local pr_numbers
    if has_cmd jq; then
        pr_numbers=$(echo "$response" | jq -r '.[].number' 2>/dev/null)
    else
        pr_numbers=$(echo "$response" | grep -o '"number":[0-9]*' | grep -o '[0-9]*')
    fi
    
    [[ -z "$pr_numbers" ]] && { echo "0"; return 0; }
    
    local total_comments=0
    while IFS= read -r pr_number; do
        [[ -z "$pr_number" ]] && continue
        
        local comments_url="$GITHUB_API/repos/$owner/$repo/issues/$pr_number/comments?per_page=100"
        local comments_response=$(_make_github_api_call "$comments_url")
        
        [[ -z "$comments_response" ]] && continue
        
        local count=0
        if has_cmd jq; then
            if [[ -z "$filter_user" ]]; then
                count=$(echo "$comments_response" | jq 'length' 2>/dev/null || echo "0")
            else
                count=$(echo "$comments_response" | jq --arg user "$filter_user" \
                    '[.[] | select(.user.login == $user)] | length' 2>/dev/null || echo "0")
            fi
        else
            count=$(echo "$comments_response" | grep -c '"id"')
        fi
        total_comments=$((total_comments + count))
    done <<<"$pr_numbers"
    
    echo "$total_comments"
}

# Use gh CLI if available
_fetch_via_gh_cli() {
    local show_issues=$(get_option "show_issues")
    local show_prs=$(get_option "show_prs")
    
    local issues=0 prs=0
    
    if [[ "$show_issues" == "true" ]]; then
        issues=$(gh issue list --assignee "@me" --state open --json number 2>/dev/null | grep -c '"number"' || echo "0")
    fi
    
    if [[ "$show_prs" == "true" ]]; then
        prs=$(gh pr list --author "@me" --state open --json number 2>/dev/null | grep -c '"number"' || echo "0")
    fi
    
    echo "$issues $prs 0"
}

# =============================================================================
# Main Logic
# =============================================================================

_format_repo_status() {
    local issues="$1"
    local prs="$2"
    local comments="$3"
    
    local show_issues=$(get_option "show_issues")
    local show_prs=$(get_option "show_prs")
    local show_comments=$(get_option "show_comments")
    local format=$(get_option "format")
    local separator=$(get_option "separator")
    local icon_issue=$(get_option "icon_issue")
    local icon_pr=$(get_option "icon_pr")
    
    local parts=()
    
    if [[ "$show_issues" == "true" && "$issues" -gt 0 ]]; then
        if [[ "$format" == "detailed" ]]; then
            parts+=("${icon_issue} ${issues}")
        else
            parts+=("${issues}i")
        fi
    fi
    
    if [[ "$show_prs" == "true" && "$prs" -gt 0 ]]; then
        if [[ "$format" == "detailed" ]]; then
            parts+=("${icon_pr} ${prs}")
        else
            parts+=("${prs}p")
        fi
    fi
    
    if [[ "$show_comments" == "true" && "$comments" -gt 0 ]]; then
        parts+=("${comments}c")
    fi

    [[ ${#parts[@]} -gt 0 ]] && join_with_separator "$separator" "${parts[@]}"
}

_get_github_info() {
    local repos_csv=$(get_option "repos")
    local filter_user=$(get_option "filter_user")
    local show_comments=$(get_option "show_comments")
    
    # If no repos configured, try gh CLI for user's repos
    if [[ -z "$repos_csv" ]] && has_cmd gh; then
        local result=$(_fetch_via_gh_cli)
        echo "$result"
        return 0
    fi
    
    [[ -z "$repos_csv" ]] && { echo "0 0 0"; return 1; }
    
    IFS=',' read -ra repos <<<"$repos_csv"
    
    local total_issues=0 total_prs=0 total_comments=0
    local api_error=0
    
    for repo_spec in "${repos[@]}"; do
        repo_spec=$(trim "$repo_spec")
        [[ -z "$repo_spec" || "$repo_spec" != *"/"* ]] && continue
        
        local owner="${repo_spec%%/*}"
        local repo="${repo_spec#*/}"
        
        local issues prs comments
        
        if [[ "$(get_option "show_issues")" == "true" ]]; then
            issues=$(_count_issues "$owner" "$repo" "$filter_user")
            [[ -z "$issues" ]] && api_error=1
            issues="${issues:-0}"
        else
            issues=0
        fi
        
        if [[ "$(get_option "show_prs")" == "true" ]]; then
            prs=$(_count_prs "$owner" "$repo" "$filter_user")
            [[ -z "$prs" ]] && api_error=1
            prs="${prs:-0}"
        else
            prs=0
        fi
        
        if [[ "$show_comments" == "true" ]]; then
            comments=$(_count_pr_comments "$owner" "$repo" "$filter_user")
            comments="${comments:-0}"
        else
            comments=0
        fi
        
        total_issues=$((total_issues + issues))
        total_prs=$((total_prs + prs))
        total_comments=$((total_comments + comments))
    done
    
    echo "$total_issues $total_prs $total_comments $api_error"
}

plugin_collect() {
    if ! _is_authenticated; then
        plugin_data_set "issues" "0"
        plugin_data_set "prs" "0"
        plugin_data_set "comments" "0"
        plugin_data_set "total" "0"
        plugin_data_set "api_error" "0"
        return 0
    fi
    
    local result=$(_get_github_info)
    local issues prs comments api_error
    read -r issues prs comments api_error <<<"$result"
    
    issues="${issues:-0}"
    prs="${prs:-0}"
    comments="${comments:-0}"
    api_error="${api_error:-0}"
    
    local total=$((issues + prs + comments))
    
    plugin_data_set "issues" "$issues"
    plugin_data_set "prs" "$prs"
    plugin_data_set "comments" "$comments"
    plugin_data_set "total" "$total"
    plugin_data_set "api_error" "$api_error"
}

plugin_render() {
    local issues=$(plugin_data_get "issues")
    local prs=$(plugin_data_get "prs")
    local comments=$(plugin_data_get "comments")
    local total=$(plugin_data_get "total")
    
    issues="${issues:-0}"
    prs="${prs:-0}"
    comments="${comments:-0}"
    total="${total:-0}"
    
    [[ "$total" -eq 0 ]] && return 0
    
    _format_repo_status "$issues" "$prs" "$comments"
}

