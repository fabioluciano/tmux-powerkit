#!/usr/bin/env bash
# =============================================================================
# Plugin: github - Monitor GitHub repositories for issues, PRs and comments
# Description: Display open issues and PRs from repositories with optional user filtering
# Dependencies: curl, jq (for JSON parsing)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "github"


GITHUB_API="https://api.github.com"

# =============================================================================
# Configuration
# =============================================================================

# Repository format: "owner/repo,owner2/repo2" or just "repo" (uses default user)
GITHUB_DEFAULT_USER=$(get_tmux_option "@powerkit_plugin_github_user" "$POWERKIT_PLUGIN_GITHUB_USER")
GITHUB_REPOS=$(get_tmux_option "@powerkit_plugin_github_repos" "$POWERKIT_PLUGIN_GITHUB_REPOS")
GITHUB_FILTER_USER=$(get_tmux_option "@powerkit_plugin_github_filter_user" "$POWERKIT_PLUGIN_GITHUB_FILTER_USER")
GITHUB_SHOW_COMMENTS=$(get_tmux_option "@powerkit_plugin_github_show_comments" "$POWERKIT_PLUGIN_GITHUB_SHOW_COMMENTS")
GITHUB_TOKEN=$(get_tmux_option "@powerkit_plugin_github_token" "$POWERKIT_PLUGIN_GITHUB_TOKEN")
GITHUB_FORMAT=$(get_tmux_option "@powerkit_plugin_github_format" "$POWERKIT_PLUGIN_GITHUB_FORMAT")
GITHUB_WARNING_THRESHOLD=$(get_tmux_option "@powerkit_plugin_github_warning_threshold" "$POWERKIT_PLUGIN_GITHUB_WARNING_THRESHOLD")



# =============================================================================
# GitHub API Helper Functions
# =============================================================================

# Make authenticated API call
make_github_api_call() {
    local url="$1"
    local auth_header=""
    
    if [[ -n "$GITHUB_TOKEN" ]]; then
        auth_header="-H \"Authorization: token $GITHUB_TOKEN\""
    fi
    
    eval curl -s $auth_header "\"$url\"" 2>/dev/null
}

# Check API rate limit
check_rate_limit() {
    local response
    response=$(make_github_api_call "$GITHUB_API/rate_limit")
    echo "$response" | jq -r '.rate.remaining // 0' 2>/dev/null || echo "0"
}

# Resolve authenticated user (from config or token)
resolve_user() {
    local configured_user="$1"
    
    # Use configured user if set
    if [[ -n "$configured_user" ]]; then
        echo "$configured_user"
        return
    fi
    
    # If no token, we can't infer
    if [[ -z "$GITHUB_TOKEN" ]]; then
        return
    fi
    
    # Check cache for authenticated user (cache for 24h)
    local user_cache_key="github_authenticated_user"
    local cached_user
    if cached_user=$(cache_get "$user_cache_key" "86400"); then
        echo "$cached_user"
        return
    fi
    
    # Fetch from API
    local response
    response=$(make_github_api_call "$GITHUB_API/user")
    local api_user
    api_user=$(echo "$response" | jq -r '.login // empty' 2>/dev/null)
    
    if [[ -n "$api_user" ]]; then
        cache_set "$user_cache_key" "$api_user"
        echo "$api_user"
    fi
}

# =============================================================================
# Data Retrieval Functions
# =============================================================================

# Count open issues for a repository (excluding PRs)
count_issues() {
    local user="$1"
    local repo="$2"
    local filter_user="$3"
    local url="$GITHUB_API/repos/$user/$repo/issues?state=open&per_page=100"
    
    local response
    response=$(make_github_api_call "$url")
    
    if [[ -z "$filter_user" ]]; then
        # Count all issues (excluding PRs)
        echo "$response" | jq '[.[] | select(.pull_request == null)] | length' 2>/dev/null || echo "0"
    else
        # Count issues by specific user (creator or assignee)
        echo "$response" | jq --arg user "$filter_user" \
            '[.[] | select(.pull_request == null) | select(.user.login == $user or (.assignees[]?.login == $user))] | length' \
            2>/dev/null || echo "0"
    fi
}

# Count open PRs for a repository
count_prs() {
    local user="$1"
    local repo="$2"
    local filter_user="$3"
    local url="$GITHUB_API/repos/$user/$repo/pulls?state=open&per_page=100"
    
    local response
    response=$(make_github_api_call "$url")
    
    if [[ -z "$filter_user" ]]; then
        # Count all PRs
        echo "$response" | jq 'length' 2>/dev/null || echo "0"
    else
        # Count PRs by specific user
        echo "$response" | jq --arg user "$filter_user" \
            '[.[] | select(.user.login == $user)] | length' \
            2>/dev/null || echo "0"
    fi
}

# Count PR comments for a repository
count_pr_comments() {
    local user="$1"
    local repo="$2"
    local filter_user="$3"
    local url="$GITHUB_API/repos/$user/$repo/pulls?state=open&per_page=100"
    
    local response
    response=$(make_github_api_call "$url")
    
    # Get all open PR numbers
    local pr_numbers
    pr_numbers=$(echo "$response" | jq -r '.[].number' 2>/dev/null)
    
    [[ -z "$pr_numbers" ]] && echo "0" && return
    
    local total_comments=0
    
    # For each PR, count comments
    while IFS= read -r pr_number; do
        [[ -z "$pr_number" ]] && continue
        
        local comments_url="$GITHUB_API/repos/$user/$repo/issues/$pr_number/comments?per_page=100"
        local comments_response
        comments_response=$(make_github_api_call "$comments_url")
        
        if [[ -z "$filter_user" ]]; then
            local count
            count=$(echo "$comments_response" | jq 'length' 2>/dev/null || echo "0")
            total_comments=$((total_comments + count))
        else
            local count
            count=$(echo "$comments_response" | jq --arg user "$filter_user" \
                '[.[] | select(.user.login == $user)] | length' 2>/dev/null || echo "0")
            total_comments=$((total_comments + count))
        fi
    done <<< "$pr_numbers"
    
    echo "$total_comments"
}

# =============================================================================
# Display Functions
# =============================================================================

# Format single repository status
format_repo_status() {
    local repo="$1"
    local issues="$2"
    local prs="$3"
    local comments="$4"
    local show_comments="$5"
    
    if [[ "$GITHUB_FORMAT" == "detailed" ]]; then
        local output="$repo: ${issues}i/${prs}p"
        [[ "$show_comments" == "on" ]] && output="${output}/${comments}c"
        echo "$output"
    else
        # Compact format
        local output="${issues}/${prs}"
        [[ "$show_comments" == "on" ]] && output="${output}/${comments}"
        echo "$repo:$output"
    fi
}

# Get GitHub info for all configured repos
get_github_info() {
    local default_user="$1"
    local repos_csv="$2"
    local filter_user="$3"
    local show_comments="$4"
    
    # Check if jq is available
    if ! command -v jq &>/dev/null; then
        echo "jq required"
        return 1
    fi
    
    # Split repos by comma
    IFS=',' read -ra repos <<< "$repos_csv"
    
    local results=()
    local total_issues=0
    local total_prs=0
    local total_comments=0
    
    for repo_spec in "${repos[@]}"; do
        # Trim whitespace
        repo_spec="$(echo "$repo_spec" | xargs)"
        [[ -z "$repo_spec" ]] && continue
        
        # Parse owner/repo format
        local owner repo
        if [[ "$repo_spec" == *"/"* ]]; then
            # Format: owner/repo
            owner="${repo_spec%%/*}"
            repo="${repo_spec#*/}"
        else
            # Format: repo (use default user)
            owner="$default_user"
            repo="$repo_spec"
        fi
        
        local issues prs comments
        issues=$(count_issues "$owner" "$repo" "$filter_user")
        prs=$(count_prs "$owner" "$repo" "$filter_user")
        
        if [[ "$show_comments" == "on" ]]; then
            comments=$(count_pr_comments "$owner" "$repo" "$filter_user")
            total_comments=$((total_comments + comments))
        else
            comments=0
        fi
        
        total_issues=$((total_issues + issues))
        total_prs=$((total_prs + prs))
        
        # Show repo name (without owner for brevity, unless specified with owner/)
        local display_name="$repo"
        [[ "$repo_spec" == *"/"* ]] && display_name="$repo_spec"
        
        # Only show repos with activity or in detailed mode
        if [[ $issues -gt 0 || $prs -gt 0 || "$GITHUB_FORMAT" == "detailed" ]]; then
            results+=("$(format_repo_status "$display_name" "$issues" "$prs" "$comments" "$show_comments")")
        fi
    done
    
    # Output results
    if [[ ${#results[@]} -eq 0 ]]; then
        echo "no activity"
    elif [[ ${#results[@]} -eq 1 ]]; then
        echo "${results[0]}"
    else
        # Multiple repos - join with separator
        local separator=" | "
        printf '%s' "${results[0]}"
        for ((i=1; i<${#results[@]}; i++)); do
            printf '%s%s' "$separator" "${results[i]}"
        done
    fi
}


# =============================================================================
# Plugin Interface
# =============================================================================

plugin_get_type() { 
    printf 'conditional'
}

plugin_get_display_info() {
    local content="$1"
    
    # Don't show plugin if no activity
    if [[ -z "$content" || "$content" == "no activity" ]]; then
        printf '0:::'
        return 0
    fi
    
    # Parse total issue count from content to determine color
    local total_count=0
    
    # Extract numbers from format like "repo:5/3" or "repo: 5i/3p"
    if [[ "$content" =~ ([0-9]+) ]]; then
        total_count="${BASH_REMATCH[1]}"
    fi
    
    # Use warning color if count exceeds threshold
    if [[ $total_count -ge $GITHUB_WARNING_THRESHOLD ]]; then
        local warning_color
        local warning_icon
        warning_color=$(get_tmux_option "@powerkit_plugin_github_warning_accent_color" "$POWERKIT_PLUGIN_GITHUB_WARNING_ACCENT_COLOR")
        warning_icon=$(get_tmux_option "@powerkit_plugin_github_warning_accent_color_icon" "$POWERKIT_PLUGIN_GITHUB_WARNING_ACCENT_COLOR_ICON")
        printf '1:%s:%s:' "$warning_color" "$warning_icon"
    else
        local accent_color
        local accent_icon
        accent_color=$(get_tmux_option "@powerkit_plugin_github_accent_color" "$POWERKIT_PLUGIN_GITHUB_ACCENT_COLOR")
        accent_icon=$(get_tmux_option "@powerkit_plugin_github_accent_color_icon" "$POWERKIT_PLUGIN_GITHUB_ACCENT_COLOR_ICON")
        printf '1:%s:%s:' "$accent_color" "$accent_icon"
    fi
}

load_plugin() {
    # Check cache first
    local cached
    if cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached"
        return 0
    fi
    
    # Resolve default user (config or inferred from token)
    local key_user
    key_user=$(resolve_user "$GITHUB_DEFAULT_USER")
    
    # Get fresh data
    local status
    status=$(get_github_info "$key_user" "$GITHUB_REPOS" "$GITHUB_FILTER_USER" "$GITHUB_SHOW_COMMENTS")
    
    # Cache result
    cache_set "$CACHE_KEY" "$status"
    
    printf '%s' "$status"
}


# Only run if executed directly (not sourced)
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
